import ArtCore
import FixtureKit
import Foundation
import Testing

extension FixtureCase: CustomTestStringConvertible {
    public var testDescription: String { name }
}

/// Loads fixture files from `spec/fixtures` (resolved relative to this file via `#filePath`).
enum Fixtures {
    static let directory: URL = {
        // Packages/ArtCore/Tests/ArtCoreTests/FixtureSupport.swift → repo root is 5 levels up.
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("spec/fixtures", isDirectory: true)
    }()

    static func cases<I, E>(_ file: FixtureFile<I, E>.Type, _ name: String) throws -> [FixtureCase<I, E>] {
        try FixtureIO.read(file, named: name, in: directory).cases
    }

    static let mini: MiniDataset = try! MiniDataset.load(from: directory)
    static let pool: GamePool = mini.pool
    static let datasetVersion = mini.datasetID
}

func u64(_ s: String) -> UInt64 { FixtureIO.u64(s) }

func errorCode(_ body: () throws -> Void) -> String? {
    do {
        try body()
        return nil
    } catch let e as GenerationError {
        return e.code
    } catch {
        return "unexpected: \(error)"
    }
}
