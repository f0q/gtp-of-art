/// Pure, total scoring of a round. Every (round, answer) pair yields an outcome; an answer of
/// the wrong kind or an out-of-range index scores as incorrect with 0 points.
public enum Scorer {
    /// Points for a correct non-bid answer.
    public static let basePoints = 100
    /// Extra points for pick-the-price answers that complete a streak of `streakBonusFrom`.
    public static let streakBonus = 25
    public static let streakBonusFrom = 3

    /// Scores `answer` for `round`.
    /// - Parameter streak: consecutive correct answers *before* this one in the session. A correct
    ///   pick-the-price answer earns `basePoints + streakBonus` when `streak + 1 ≥ 3`.
    public static func score(_ round: Round, _ answer: Answer, streak: Int = 0) -> RoundOutcome {
        switch (round, answer) {
        case (.pickPrice(let r), .pickPrice(let index)):
            guard r.options.indices.contains(index) else { return .invalid }
            guard index == r.correctIndex else { return RoundOutcome(isCorrect: false, points: 0) }
            let bonus = streak + 1 >= streakBonusFrom ? streakBonus : 0
            return RoundOutcome(isCorrect: true, points: basePoints + bonus)

        case (.higherLower(let r), .higherLower(let side)):
            let correct = side == r.pricierSide
            return RoundOutcome(isCorrect: correct, points: correct ? basePoints : 0)

        case (.category(let r), .category(let index)):
            guard r.options.indices.contains(index) else { return .invalid }
            let chosen = r.options[index]
            if index == r.correctIndex {
                return RoundOutcome(isCorrect: true, points: basePoints, categoryMatch: .correct)
            } else if r.accepted.contains(chosen) {
                return RoundOutcome(isCorrect: true, points: basePoints, categoryMatch: .alternate)
            } else {
                return RoundOutcome(isCorrect: false, points: 0, categoryMatch: .incorrect)
            }

        case (.bid(let r), .bid(let position)):
            let result = BidScorer.score(position: position, actualMilli: r.actualMilli)
            return RoundOutcome(
                isCorrect: result.tier != .offTheWall, points: result.points, bidTier: result.tier,
                errorMilli: result.errorMilli)

        case (.swipe, .swipe(let liked)):
            return RoundOutcome(isCorrect: nil, points: 0, liked: liked)

        default:
            return .invalid
        }
    }
}
