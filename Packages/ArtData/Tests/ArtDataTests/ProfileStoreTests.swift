import ArtCore
import Foundation
import Testing

@testable import ArtData

@Suite("FileProfileStore")
struct ProfileStoreTests {
    let data = TestSupport.dataset(minQuizItems: 6)

    func makeStore(_ dir: URL, debounce: Duration = .milliseconds(500), migrator: ProfileMigrator = .standard)
        -> FileProfileStore
    {
        FileProfileStore(
            directory: dir, debounce: debounce, migrator: migrator, tasteBuckets: data.tasteBucketResolver,
            makePlayerID: { "fresh-player" })
    }

    /// Plays one session of each standalone mode, an unfinished bid session and two daily days.
    func scriptedHistory() throws -> ScriptedPlayer {
        var player = ScriptedPlayer(dataset: data)
        for (i, mode) in [GameMode.pickPrice, .higherLower, .category, .bid, .swipe].enumerated() {
            player.play(try SessionFactory.make(mode: mode, dataset: data, seed: UInt64(100 + i)))
        }
        player.play(try SessionFactory.make(mode: .bid, dataset: data, seed: 999), limit: 4)
        let day1 = DayKey(year: 2026, month: 10, day: 11)
        player.play(try DailyService.challenge(for: day1, dataset: data).session, day: day1)
        player.play(try DailyService.challenge(for: day1.adding(days: 1), dataset: data).session, day: day1.adding(days: 1))
        return player
    }

    @Test func freshDirectoryCreatesProfile() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let report = await makeStore(dir).load()
        #expect(report.source == .created)
        #expect(report.profile == PlayerProfile(localPlayerID: "fresh-player"))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.json").path))
    }

    @Test func roundTripsProfileAndRecords() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        await store.save(player.profile)
        for r in player.records { try await store.append(r) }
        try await store.flush()

        let reopened = makeStore(dir)
        let report = await reopened.load()
        #expect(report.source == .file)
        #expect(report.profile == player.profile)
        let log = await reopened.roundLog()
        #expect(log.records == player.records)
        #expect(log.skipped.isEmpty)
    }

    @Test func largeSeedsSurviveJSONLines() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let round = Round.swipe(SwipeRound(artwork: "x"))
        let record = RoundRecord(
            mode: .swipe, sessionSeed: UInt64.max - 12345, roundIndex: 0, round: round, answer: .swipe(liked: true),
            outcome: Scorer.score(round, .swipe(liked: true), streak: 0), day: nil, playedAt: 1)
        let store = makeStore(dir)
        try await store.append(record)
        #expect(await store.roundLog().records == [record])
    }

    @Test func truncatedProfileIsRebuiltFromHistory() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        await store.save(player.profile)
        for r in player.records { try await store.append(r) }
        try await store.flush()

        // Simulate a torn write: keep only the first half of profile.json.
        let url = dir.appendingPathComponent("profile.json")
        let bytes = try Data(contentsOf: url)
        try bytes.prefix(bytes.count / 2).write(to: url)

        let report = await makeStore(dir).load()
        guard case .rebuilt = report.source else {
            Issue.record("expected a rebuild, got \(report.source)")
            return
        }
        #expect(report.profile.stats == player.profile.stats)
        #expect(report.profile.daily == player.profile.daily)
        #expect(report.profile.daily.streak == 2)
        #expect(report.profile.taste == player.profile.taste)
        #expect(report.profile.hasOnboarded)
        #expect(report.profile.localPlayerID == "fresh-player")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.corrupt.json").path))
        // The rebuilt profile was written back and decodes on the next launch.
        #expect(await makeStore(dir).load().source == .file)
    }

    @Test func missingProfileWithHistoryRebuilds() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        for r in player.records { try await store.append(r) }
        let report = await makeStore(dir).load()
        #expect(report.source == .rebuilt(reason: "profile.json missing"))
        #expect(report.profile.stats == player.profile.stats)
    }

    @Test func corruptHistoryLinesAreSkippedAndReported() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        for r in player.records.prefix(3) { try await store.append(r) }
        // A crash mid-append leaves a partial line without a newline…
        let url = dir.appendingPathComponent("rounds.jsonl")
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"mode\":\"pick_pr".utf8))
        try handle.close()
        // …and the next append starts on a fresh line.
        try await store.append(player.records[3])
        let log = await store.roundLog()
        #expect(log.records == Array(player.records.prefix(4)))
        #expect(log.skipped == [SkippedLine(line: 4, reason: "not valid JSON")])
    }

    @Test func tasteUndoRedoPersists() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = makeStore(dir)
        let original = await store.profile()
        let work = try #require(data.pool.artworks.first)
        let swipe = TasteSwipe(artwork: work, liked: true)

        var liked = original
        liked.taste = original.taste.applying(swipe)
        await store.save(liked)
        try await store.flush()
        #expect(await makeStore(dir).profile().taste == liked.taste)

        var undone = liked
        undone.taste = liked.taste.undoing(swipe)
        await store.save(undone)
        try await store.flush()
        #expect(await makeStore(dir).profile().taste == original.taste)

        var redone = undone
        redone.taste = undone.taste.applying(swipe)
        await store.save(redone)
        try await store.flush()
        let reloaded = await makeStore(dir).profile()
        #expect(reloaded.taste == liked.taste)
        #expect(reloaded.taste.swipeCount == 1)
    }

    @Test func saveIsDebouncedAndCoalesced() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = makeStore(dir)
        _ = await store.load()
        var p = await store.profile()
        for i in 1...5 {
            p.seenTips = ["tip\(i)"]
            await store.save(p)
        }
        #expect(await store.profile().seenTips == ["tip5"])  // in-memory state is immediate
        #expect(await makeStore(dir).profile().seenTips == [])  // disk not yet written
        try await Task.sleep(for: .milliseconds(900))
        #expect(await makeStore(dir).profile().seenTips == ["tip5"])
    }

    @Test func flushWritesImmediately() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = makeStore(dir, debounce: .seconds(60))
        var p = await store.profile()
        p.hasOnboarded = true
        await store.save(p)
        #expect(await makeStore(dir).profile().hasOnboarded == false)
        try await store.flush()
        #expect(await makeStore(dir).profile().hasOnboarded == true)
    }

    @Test func migratesOlderSchemaThroughHook() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        // A hypothetical schema-0 file: no schema_version, no seen_tips, player id under another key.
        let legacy = #"{"has_onboarded": true, "stats": {}, "taste": {"swipe_count": 0, "like_count": 0, "exposures": {}, "likes": {}}, "daily": {"streak": 3, "best_streak": 4, "last_completed_day": "2026-10-10", "scores": {"2026-10-10": 300}}, "player": "legacy-id"}"#
        try Data(legacy.utf8).write(to: dir.appendingPathComponent("profile.json"))
        let migrator = ProfileMigrator(currentVersion: 1, steps: [
            0: { object in
                object["seen_tips"] = [String]()
                object["local_player_id"] = object.removeValue(forKey: "player")
            },
        ])
        let report = await makeStore(dir, migrator: migrator).load()
        #expect(report.source == .migrated(fromSchema: 0))
        #expect(report.profile.localPlayerID == "legacy-id")
        #expect(report.profile.daily.streak == 3)
        #expect(report.profile.schemaVersion == 1)
        #expect(await makeStore(dir).load().source == .file)  // written back at schema 1
    }

    @Test func missingMigrationStepRebuilds() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(#"{"has_onboarded": true}"#.utf8).write(to: dir.appendingPathComponent("profile.json"))
        let report = await makeStore(dir).load()
        #expect(report.source == .created)  // no history to rebuild from
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.corrupt.json").path))
    }

    @Test func newerSchemaIsSetAsideNotOverwritten() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        var future = PlayerProfile(localPlayerID: "future")
        future.schemaVersion = 99
        try JSONEncoder().encode(future).write(to: dir.appendingPathComponent("profile.json"))
        try await makeStore(dir).append(try scriptedHistory().records[0])
        let report = await makeStore(dir).load()
        #expect(report.source == .rebuilt(reason: "profile.json has newer schema 99"))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profile.v99.json").path))
    }

    @Test func rebuildStatsMatchesLiveAndKeepsOtherFields() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        var drifted = player.profile
        drifted.stats = [:]
        drifted.daily = DailyState()
        drifted.seenTips = ["keep-me"]
        await store.save(drifted)
        for r in player.records { try await store.append(r) }
        let rebuilt = try await store.rebuildStats()
        #expect(rebuilt.stats == player.profile.stats)
        #expect(rebuilt.daily == player.profile.daily)
        #expect(rebuilt.seenTips == ["keep-me"])
        #expect(await makeStore(dir).profile() == rebuilt)
    }

    @Test func resetDeletesEverything() async throws {
        let dir = try TestSupport.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let player = try scriptedHistory()
        let store = makeStore(dir)
        await store.save(player.profile)
        for r in player.records { try await store.append(r) }
        let fresh = try await store.reset()
        #expect(fresh == PlayerProfile(localPlayerID: "fresh-player"))
        #expect(await store.roundLog().records.isEmpty)
        #expect(await makeStore(dir).profile() == fresh)
    }

    @Test func inMemoryStoreRebuilds() async throws {
        let player = try scriptedHistory()
        let store = InMemoryProfileStore(
            profile: PlayerProfile(localPlayerID: "mem"), tasteBuckets: data.tasteBucketResolver)
        for r in player.records { try await store.append(r) }
        let rebuilt = try await store.rebuildStats()
        #expect(rebuilt.stats == player.profile.stats)
        #expect(rebuilt.taste == player.profile.taste)
        #expect(rebuilt.localPlayerID == "mem")
    }
}
