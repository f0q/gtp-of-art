import ArtCore
import Foundation

/// Every taste/rarity string (pure, unit-tested). All rarity copy says "estimated".
nonisolated enum TasteCopy {
    // MARK: Rarity

    /// Headline rarity line, respecting the visibility rule (hidden < 12 swipes, band < 40, exact).
    static func rarity(_ rarity: Rarity, swipeCount: Int) -> String {
        switch rarity.visibility {
        case .hidden:
            let more = max(1, RarityCalculator.hiddenBelowSwipes - swipeCount)
            return "Swipe \(more) more to see how rare your taste is (estimated)."
        case .band:
            let b = rarity.band
            if b.lower == 0 { return "A well-loved taste, shared by many players (estimated)." }
            if b.upper >= 100 { return "Rarer than ~\(b.lower)% of players (estimated)." }
            return "Rarer than ~\(b.lower)–\(b.upper)% of players (estimated)."
        case .exact:
            let pct = Int(rarity.percentile.rounded(.down))
            if pct < 50 { return "A well-loved taste, shared by many players (estimated)." }
            return "Rarer than \(pct)% of players (estimated)."
        }
    }

    /// "Edition 7 / 100".
    static func edition(_ number: Int) -> String { "Edition \(number) / 100" }

    /// "About 7% of players share your archetype (estimated)."
    static func share(_ number: Int) -> String {
        "About \(number)% of players share your archetype (estimated)."
    }

    // MARK: Bucket explanations

    /// A bucket as an adjective ("dark", "17th-century") or a head noun ("portraits").
    enum Phrase: Equatable {
        case adjective(String)
        case noun(String)
    }

    static func phrase(_ bucket: String, categoryLabel: (CategoryID) -> String?) -> Phrase? {
        let parts = bucket.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let (family, value) = (parts[0], parts[1])
        switch family {
        case "era": return eraAdjectives[value].map(Phrase.adjective)
        case "subject": return subjectNouns[value].map(Phrase.noun)
        case "category": return categoryLabel(CategoryID(value)).map { .noun("\($0) works") }
        default: return scalarAdjectives[bucket].map(Phrase.adjective)
        }
    }

    static let eraAdjectives: [String: String] = [
        "pre1500": "pre-1500", "1500_1600": "16th-century", "1600_1700": "17th-century",
        "1700_1800": "18th-century", "1800_1850": "early 19th-century", "1850_1900": "late 19th-century",
        "1900_1930": "early 20th-century",
    ]

    static let subjectNouns: [String: String] = [
        "portrait": "portraits", "figure": "figure studies", "landscape": "landscapes",
        "still_life": "still lifes", "religious_myth": "myths and saints", "genre": "everyday scenes",
        "abstract": "abstractions",
    ]

    static let scalarAdjectives: [String: String] = [
        "abstraction:low": "lifelike", "abstraction:mid": "stylised", "abstraction:high": "abstract",
        "warmth:cool": "cool-toned", "warmth:neutral": "neutral-toned", "warmth:warm": "warm-toned",
        "saturation:muted": "muted", "saturation:mid": "softly coloured", "saturation:vivid": "vivid",
        "brightness:dark": "dark", "brightness:mid": "evenly lit", "brightness:light": "light-filled",
        "complexity:sparse": "spare", "complexity:mid": "balanced", "complexity:busy": "busy",
        "mood:serene": "serene", "mood:dramatic": "dramatic", "mood:melancholic": "melancholy",
        "mood:joyful": "joyful",
    ]

    /// Joins phrases into one noun phrase: adjectives first, then the head noun(s) or "pictures".
    /// `[dark, 17th-century]` → "dark, 17th-century pictures"; `[portraits, dark]` → "dark portraits".
    static func nounPhrase(_ phrases: [Phrase]) -> String {
        var adjectives: [String] = []
        var nouns: [String] = []
        for p in phrases {
            switch p {
            case .adjective(let a): adjectives.append(a)
            case .noun(let n): nouns.append(n)
            }
        }
        let head = nouns.isEmpty ? "pictures" : nouns.joined(separator: " and ")
        return adjectives.isEmpty ? head : adjectives.joined(separator: ", ") + " " + head
    }

    /// "You lean toward dark, 17th-century pictures." from the top-2 positive contributions.
    static func leaning(_ contributions: [BucketContribution], categoryLabel: (CategoryID) -> String?) -> String? {
        let phrases = contributions.filter { $0.contribution > 0 }
            .compactMap { phrase($0.bucket, categoryLabel: categoryLabel) }.prefix(2)
        guard !phrases.isEmpty else { return nil }
        return "You lean toward \(nounPhrase(Array(phrases)))."
    }

    /// "You tend to pass on portraits." from the strongest negative contribution.
    static func avoiding(_ contributions: [BucketContribution], categoryLabel: (CategoryID) -> String?) -> String? {
        var found: Phrase?
        for c in contributions where c.contribution < 0 {
            if let p = phrase(c.bucket, categoryLabel: categoryLabel) {
                found = p
                break
            }
        }
        guard let p = found else { return nil }
        return "You tend to pass on \(nounPhrase([p]))."
    }

    // MARK: Swipe progress

    /// "12 more to reveal your taste", shown from card 8 (1-based `card`) of `total`.
    static func progress(card: Int, total: Int) -> String? {
        guard card >= 8, card <= total else { return nil }
        let more = total - card
        return more == 0 ? "Last one, then your taste" : "\(more) more to reveal your taste"
    }
}
