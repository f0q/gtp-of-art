/// Aggregate statistics for one mode (rebuildable from round records).
public struct ModeStats: Codable, Sendable, Equatable {
    public var roundsPlayed: Int
    public var roundsCorrect: Int
    public var totalPoints: Int
    public var sessionsCompleted: Int
    public var bestSessionPoints: Int
    /// Longest run of consecutive correct answers within a session.
    public var bestStreak: Int

    public init(
        roundsPlayed: Int = 0, roundsCorrect: Int = 0, totalPoints: Int = 0, sessionsCompleted: Int = 0,
        bestSessionPoints: Int = 0, bestStreak: Int = 0
    ) {
        self.roundsPlayed = roundsPlayed
        self.roundsCorrect = roundsCorrect
        self.totalPoints = totalPoints
        self.sessionsCompleted = sessionsCompleted
        self.bestSessionPoints = bestSessionPoints
        self.bestStreak = bestStreak
    }

    enum CodingKeys: String, CodingKey {
        case roundsPlayed = "rounds_played"
        case roundsCorrect = "rounds_correct"
        case totalPoints = "total_points"
        case sessionsCompleted = "sessions_completed"
        case bestSessionPoints = "best_session_points"
        case bestStreak = "best_streak"
    }

    /// Adds one answered round.
    public func recording(_ outcome: RoundOutcome) -> ModeStats {
        var s = self
        s.roundsPlayed += 1
        if outcome.isCorrect == true { s.roundsCorrect += 1 }
        s.totalPoints += outcome.points
        return s
    }

    /// Adds a finished session's totals.
    public func recordingSession(points: Int, longestStreak: Int) -> ModeStats {
        var s = self
        s.sessionsCompleted += 1
        s.bestSessionPoints = max(s.bestSessionPoints, points)
        s.bestStreak = max(s.bestStreak, longestStreak)
        return s
    }
}
