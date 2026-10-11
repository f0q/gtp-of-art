/// Daily challenge seed derivation.
public enum DailySeed {
    /// `"artprice|daily|r{rulesVersion}|d{datasetVersion}|yyyy-MM-dd"`.
    public static func string(day: DayKey, datasetVersion: String, dailyRulesVersion: Int) -> String {
        "artprice|daily|r\(dailyRulesVersion)|d\(datasetVersion)|\(day.isoString)"
    }

    /// FNV-1a 64 of `string(day:datasetVersion:dailyRulesVersion:)`.
    public static func seed(day: DayKey, datasetVersion: String, dailyRulesVersion: Int) -> UInt64 {
        fnv1a64(string(day: day, datasetVersion: datasetVersion, dailyRulesVersion: dailyRulesVersion))
    }
}
