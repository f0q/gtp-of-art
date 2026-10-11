import ArtCore
import Foundation

/// A `rounds.jsonl` line that was skipped.
public struct SkippedLine: Sendable, Equatable {
    /// 1-based line number.
    public var line: Int
    public var reason: String
}

/// Decoded round history.
public struct RoundLogContents: Sendable, Equatable {
    /// Round lines, in file order.
    public var records: [RoundRecord]
    /// Undecodable or unknown-kind lines.
    public var skipped: [SkippedLine]
    /// Onboarding lines, in file order.
    public var onboarding: [OnboardingLogEntry]

    public init(records: [RoundRecord] = [], skipped: [SkippedLine] = [], onboarding: [OnboardingLogEntry] = []) {
        self.records = records
        self.skipped = skipped
        self.onboarding = onboarding
    }
}

/// Encoding and file access for the append-only `rounds.jsonl` (one compact JSON `RoundRecord`
/// per line, plus `kind`-tagged entries such as `OnboardingLogEntry`). Not thread-safe on its
/// own; `FileProfileStore` serialises access.
enum RoundLog {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }

    /// One encoded line including the trailing newline.
    static func line(for value: some Encodable) throws -> Data {
        var data = try encoder().encode(value)
        data.append(0x0A)
        return data
    }

    /// Appends a record. If the file does not end in a newline (a crash cut the last line short),
    /// a newline is written first so the new record starts on its own line; the damaged line is
    /// then skipped by `read`.
    static func append(_ record: some Encodable, to url: URL) throws {
        let line = try line(for: record)
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try line.write(to: url, options: .atomic)
            return
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        if end > 0 {
            try handle.seek(toOffset: end - 1)
            let last = try handle.read(upToCount: 1)
            try handle.seekToEnd()
            if last != Data([0x0A]) { try handle.write(contentsOf: Data([0x0A])) }
        }
        try handle.write(contentsOf: line)
    }

    /// Reads every line; blank lines are ignored, undecodable lines reported in `skipped`.
    static func read(from url: URL) -> RoundLogContents {
        guard let data = try? Data(contentsOf: url) else { return RoundLogContents() }
        return decode(data)
    }

    static func decode(_ data: Data) -> RoundLogContents {
        var contents = RoundLogContents()
        let decoder = JSONDecoder()
        for (index, slice) in data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated() {
            if slice.allSatisfy({ $0 == 0x20 || $0 == 0x0D || $0 == 0x09 }) { continue }
            do {
                let data = Data(slice)
                switch try decoder.decode(LogLineKind.self, from: data).kind {
                case nil: contents.records.append(try decoder.decode(RoundRecord.self, from: data))
                case OnboardingLogEntry.kind?:
                    contents.onboarding.append(try decoder.decode(OnboardingLogEntry.self, from: data))
                case let other?:
                    contents.skipped.append(SkippedLine(line: index + 1, reason: "unknown kind \(other)"))
                }
            } catch {
                contents.skipped.append(SkippedLine(line: index + 1, reason: Self.reason(error)))
            }
        }
        return contents
    }

    static func reason(_ error: any Error) -> String {
        switch error {
        case DecodingError.dataCorrupted: "not valid JSON"
        case DecodingError.keyNotFound(let key, _): "missing key \(key.stringValue)"
        case DecodingError.typeMismatch(_, let ctx), DecodingError.valueNotFound(_, let ctx):
            "bad value at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        default: String(describing: error)
        }
    }
}
