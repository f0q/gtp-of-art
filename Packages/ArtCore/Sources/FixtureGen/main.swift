import ArtCore
import FixtureKit
import Foundation

// Regenerates spec/fixtures from the ArtCore implementation.
// Usage: swift run --package-path Packages/ArtCore FixtureGen [output-dir]   (default: spec/fixtures)

let arguments = CommandLine.arguments
let directory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1], isDirectory: true)
    : FixtureIO.defaultDirectory()

do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let mini = MiniDatasetSource.make()
    try FixtureIO.write(mini, named: MiniDataset.fileName, in: directory)
    // Re-read so every derived fixture is computed from exactly what is on disk.
    let frozen = try MiniDataset.load(from: directory)

    try FixtureIO.write(Generators.prng(), named: "prng.json", in: directory)
    try FixtureIO.write(Generators.shuffleFixture(), named: "shuffle.json", in: directory)
    try FixtureIO.write(Generators.fnv(), named: "fnv.json", in: directory)
    try FixtureIO.write(Generators.daykey(), named: "daykey.json", in: directory)
    try FixtureIO.write(Generators.streak(), named: "streak.json", in: directory)
    try FixtureIO.write(Generators.daily(frozen), named: "daily.json", in: directory)
    try FixtureIO.write(Generators.distractors(), named: "distractors.json", in: directory)
    try FixtureIO.write(Generators.bid(), named: "bid_score.json", in: directory)
    try FixtureIO.write(Generators.pairs(frozen), named: "pairs.json", in: directory)
    try FixtureIO.write(Generators.category(frozen), named: "category.json", in: directory)
    try FixtureIO.write(Generators.taste(frozen), named: "taste.json", in: directory)
    try FixtureIO.write(Generators.rarity(frozen), named: "rarity.json", in: directory)
    try FixtureIO.write(Generators.priceFormat(), named: "price_format.json", in: directory)
    try FixtureIO.write(Generators.weightedPick(), named: "weighted_pick.json", in: directory)
    try FixtureIO.write(Generators.prior(frozen), named: "prior.json", in: directory)
    print("Wrote fixtures to \(directory.path)")
} catch {
    FileHandle.standardError.write(Data("FixtureGen failed: \(error)\n".utf8))
    exit(1)
}
