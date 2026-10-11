import ArtCore
import FixtureKit
import Testing

@Suite("Fixtures: primitives")
struct PrimitiveFixtureTests {
    @Test(arguments: try Fixtures.cases(PRNGFixture.File.self, "prng.json"))
    func prng(_ c: FixtureCase<PRNGFixture.Input, PRNGFixture.Expected>) {
        var rng = SplitMix64(seed: u64(c.input.seed))
        let values: [String] = (0..<c.input.count).map { _ in
            if let bound = c.input.bound { String(rng.nextInt(Int(bound)!)) } else { String(rng.next()) }
        }
        #expect(values == c.expected.values)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(ShuffleFixture.File.self, "shuffle.json"))
    func shuffleCases(_ c: FixtureCase<ShuffleFixture.Input, ShuffleFixture.Expected>) {
        var rng = SplitMix64(seed: u64(c.input.seed))
        var a = Array(0..<c.input.n)
        shuffle(&a, using: &rng)
        #expect(a == c.expected.permutation)
        #expect(rng.state == u64(c.expected.stateAfter))
    }

    @Test(arguments: try Fixtures.cases(FNVFixture.File.self, "fnv.json"))
    func fnv(_ c: FixtureCase<FNVFixture.Input, FNVFixture.Expected>) {
        #expect(fnv1a64(c.input.text) == u64(c.expected.hash))
        #expect(fnv1a64(c.input.text) == u64(c.expected.hashHex))
    }

    @Test(arguments: try Fixtures.cases(DayKeyFixture.File.self, "daykey.json"))
    func dayKey(_ c: FixtureCase<DayKeyFixture.Input, DayKeyFixture.Expected>) {
        let key = DayKey(year: c.input.year, month: c.input.month, day: c.input.day)
        #expect(key.isValid == c.expected.valid)
        guard c.expected.valid else {
            #expect(DayKey(string: "\(c.input.year)-\(c.input.month)-\(c.input.day)") == nil)
            return
        }
        #expect(key.dayNumber == c.expected.dayNumber)
        #expect(key.isoString == c.expected.iso)
        #expect(DayKey(dayNumber: key.dayNumber) == key)
        #expect(DayKey(string: key.isoString) == key)
    }

    @Test(arguments: try Fixtures.cases(StreakFixture.File.self, "streak.json"))
    func streak(_ c: FixtureCase<StreakFixture.Input, StreakFixture.Expected>) {
        let u = Streak.update(
            streak: c.input.streak, lastDay: c.input.lastDay.flatMap(DayKey.init(string:)),
            today: DayKey(string: c.input.today)!)
        #expect(u.streak == c.expected.streak)
        #expect(u.lastDay?.isoString == c.expected.lastDay)
    }
}
