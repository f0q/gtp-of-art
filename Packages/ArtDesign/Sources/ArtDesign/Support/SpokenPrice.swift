/// VoiceOver wording for compact prices. VoiceOver reads "$2.8M" as letters ("two point eight M
/// dollars"), so every price inside an accessibility label or announcement goes through
/// `SpokenPrice.text(_:)`: "$2.8M" → "2.8 million dollars", "≈$5.5M" → "about 5.5 million
/// dollars", "~$250M+" → "about 250 million dollars or more". Pure; unit-tested.
nonisolated public enum SpokenPrice {
    /// Rewrites every compact price (`[~≈][ ]$<digits>[.<digits>][K|M|B][+]`) in `text`; other text
    /// is kept as is.
    public static func text(_ text: String) -> String {
        let chars = Array(text)
        var out = ""
        var i = 0
        while i < chars.count {
            if chars[i] == "$", let parsed = parse(chars, dollarAt: i) {
                var head = out
                var approximate = false
                // A marker directly before "$" (optionally separated by one space) means "about".
                if head.hasSuffix("≈ ") || head.hasSuffix("~ ") {
                    head.removeLast(2)
                    approximate = true
                } else if head.hasSuffix("≈") || head.hasSuffix("~") {
                    head.removeLast()
                    approximate = true
                }
                out = head + (approximate ? "about " : "") + parsed.words
                i = parsed.end
            } else {
                out.append(chars[i])
                i += 1
            }
        }
        return out
    }

    /// Words for one price starting at the "$" at `start`, and the index after it.
    private static func parse(_ chars: [Character], dollarAt start: Int) -> (words: String, end: Int)? {
        var i = start + 1
        var number = ""
        while i < chars.count, chars[i].isASCII, chars[i].isNumber || chars[i] == "," {
            if chars[i] != "," { number.append(chars[i]) }
            i += 1
        }
        guard !number.isEmpty else { return nil }
        if i + 1 < chars.count, chars[i] == ".", chars[i + 1].isASCII, chars[i + 1].isNumber {
            number.append(".")
            i += 1
            while i < chars.count, chars[i].isASCII, chars[i].isNumber {
                number.append(chars[i])
                i += 1
            }
        }
        var unit = ""
        if i < chars.count, let word = units[chars[i]] {
            // Only a suffix when not the start of a following word ("$5 Monet" stays as is).
            let next = i + 1 < chars.count ? chars[i + 1] : " "
            if !next.isLetter {
                unit = " " + word
                i += 1
            }
        }
        var orMore = ""
        if i < chars.count, chars[i] == "+" {
            orMore = " or more"
            i += 1
        }
        if number.hasSuffix(".0") { number.removeLast(2) }
        let dollars = unit.isEmpty && number == "1" ? " dollar" : " dollars"
        return (number + unit + dollars + orMore, i)
    }

    private static let units: [Character: String] = ["K": "thousand", "M": "million", "B": "billion"]
}
