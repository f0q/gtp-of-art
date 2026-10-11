import ArtCore
import Foundation

/// A named taste archetype (plan C5). Ids are ArtCore's 4-letter axis codes:
/// Era `O`ld Masters / `M`odern, Form `F`igurative / `A`bstract, Palette `E`arthy / `V`ivid,
/// Mood `S`erene / `D`ramatic.
nonisolated struct Archetype: Equatable, Sendable {
    let id: String
    let name: String
    /// One-line character copy (witty, short, never judgemental).
    let line: String
}

/// The 16 archetypes. Names and copy belong to design (spec §16.4).
nonisolated enum Archetypes {
    static let all: [Archetype] = [
        Archetype(id: "OFES", name: "The Candlelight Baroque",
                  line: "Quiet faces, warm shadows, one candle doing all the work."),
        Archetype(id: "OFED", name: "The Chiaroscuro Devotee",
                  line: "You like your drama lit from one side."),
        Archetype(id: "OFVS", name: "The Golden-Hour Pastoralist",
                  line: "Sunlit fields, glowing silks and nobody in a hurry."),
        Archetype(id: "OFVD", name: "The Grand Manner Romantic",
                  line: "Saints, storms and swirling capes, in full colour."),
        Archetype(id: "OAES", name: "The Ink-Wash Contemplative",
                  line: "Mist, mountains and a few perfect brushstrokes."),
        Archetype(id: "OAED", name: "The Gothic Visionary",
                  line: "Strange, stylised and a little apocalyptic. You read the margins."),
        Archetype(id: "OAVS", name: "The Gilded Illuminator",
                  line: "Gold leaf, lapis blue and patterns to get lost in."),
        Archetype(id: "OAVD", name: "The Mannerist Maverick",
                  line: "Long necks, acid colours, impossible poses. Rules were made to bend."),
        Archetype(id: "MFES", name: "The Quiet Interior",
                  line: "Lamplight, a chair by the window, someone reading. Bliss."),
        Archetype(id: "MFED", name: "The Realist Brooder",
                  line: "Honest faces and heavy skies. You like art that tells the truth."),
        Archetype(id: "MFVS", name: "The Luminist",
                  line: "Light on water, light on linen, light on everything."),
        Archetype(id: "MFVD", name: "The Café-Society Regular",
                  line: "Dance halls, gaslight and a crowd with stories."),
        Archetype(id: "MAES", name: "The Colour Field Dreamer",
                  line: "Soft fields of colour and nothing that shouts."),
        Archetype(id: "MAED", name: "The Raw Nerve",
                  line: "Bold strokes, dark edges. You want art to feel something, loudly."),
        Archetype(id: "MAVS", name: "The Floating World Wanderer",
                  line: "Flat colour, bold outlines and a wave about to break."),
        Archetype(id: "MAVD", name: "The Fauve at Heart",
                  line: "Wild colour, fast brushwork, no apologies."),
    ]

    private static let byID: [String: Archetype] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Every id ArtCore can produce (2⁴ sign combinations).
    static let allIDs: [String] = ["O", "M"].flatMap { e in
        ["F", "A"].flatMap { f in ["E", "V"].flatMap { p in ["S", "D"].map { m in e + f + p + m } } }
    }

    /// The archetype for an id; an unknown id falls back to a neutral name.
    static func archetype(_ id: String) -> Archetype {
        byID[id] ?? Archetype(id: id, name: "The Open Eye", line: "Your taste is still taking shape.")
    }
}

/// Session-level edge cases (plan C4): very few or very many likes in one 20-card session.
nonisolated enum TasteEdge: Equatable, Sendable {
    case purist
    case omnivore

    /// Fewer than 3 likes → purist; more than 18 → omnivore.
    static func of(likes: Int, swipes: Int) -> TasteEdge? {
        guard swipes > 0 else { return nil }
        if likes < 3 { return .purist }
        if likes > 18 { return .omnivore }
        return nil
    }

    var title: String {
        switch self {
        case .purist: "The Purist"
        case .omnivore: "The Omnivore"
        }
    }

    func line(likes: Int, swipes: Int) -> String {
        switch self {
        case .purist:
            likes == 0
                ? "Nothing made the wall this time. A hard room to please."
                : "Only \(likes) of \(swipes) made your wall. A discerning eye."
        case .omnivore:
            "You kept \(likes) of \(swipes). The whole museum is your wall."
        }
    }
}
