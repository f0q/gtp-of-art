import ArtCore
import Foundation

/// Why `profile.json` could not be brought to the current schema.
public enum ProfileMigrationError: Error, Sendable, Equatable {
    /// Written by a newer app version; this build cannot read it safely.
    case newerSchema(found: Int, supported: Int)
    /// No migration step registered from this version.
    case missingStep(from: Int)
    /// The file is not a JSON object.
    case notAnObject
}

/// Forward migrations for `profile.json`.
///
/// Each step upgrades the raw JSON object from schema `n` to `n + 1` and is registered under `n`.
/// A file without `schema_version` counts as schema 0. After the last step the object is decoded
/// as `PlayerProfile` with `schema_version` set to `currentVersion`. Version 1 is the first shipped
/// schema, so `standard` has no steps yet.
public struct ProfileMigrator: Sendable {
    /// Upgrades a JSON object in place from one schema to the next.
    public typealias Step = @Sendable (inout [String: Any]) throws -> Void

    public var currentVersion: Int
    public var steps: [Int: Step]

    public init(currentVersion: Int = PlayerProfile.currentSchemaVersion, steps: [Int: Step] = [:]) {
        self.currentVersion = currentVersion
        self.steps = steps
    }

    /// The migrator for this app build.
    public static let standard = ProfileMigrator()

    /// Decodes `data`, migrating it first if its schema is older. Returns the profile and the
    /// schema the file was written with.
    public func decode(_ data: Data) throws -> (profile: PlayerProfile, fromVersion: Int) {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProfileMigrationError.notAnObject
        }
        let found = (object["schema_version"] as? Int) ?? 0
        if found > currentVersion { throw ProfileMigrationError.newerSchema(found: found, supported: currentVersion) }
        if found < currentVersion {
            for version in found..<currentVersion {
                guard let step = steps[version] else { throw ProfileMigrationError.missingStep(from: version) }
                try step(&object)
            }
            object["schema_version"] = currentVersion
            let migrated = try JSONSerialization.data(withJSONObject: object)
            return (try JSONDecoder().decode(PlayerProfile.self, from: migrated), found)
        }
        return (try JSONDecoder().decode(PlayerProfile.self, from: data), found)
    }
}
