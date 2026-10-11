/// A player's answer. JSON: `{"kind": "<round kind>", <field>: value}`.
public enum Answer: Codable, Sendable, Equatable {
    /// Index into `PickPriceRound.options`.
    case pickPrice(index: Int)
    /// The frame tapped as pricier.
    case higherLower(side: PricierSide)
    /// Index into `CategoryRound.options`.
    case category(index: Int)
    /// Bid slider position 0…700.
    case bid(position: Int)
    /// Like (true) or pass (false).
    case swipe(liked: Bool)

    public var kind: RoundKind {
        switch self {
        case .pickPrice: .pickPrice
        case .higherLower: .higherLower
        case .category: .category
        case .bid: .bid
        case .swipe: .swipe
        }
    }

    enum CodingKeys: String, CodingKey { case kind, index, side, position, liked }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(RoundKind.self, forKey: .kind) {
        case .pickPrice: self = .pickPrice(index: try c.decode(Int.self, forKey: .index))
        case .higherLower: self = .higherLower(side: try c.decode(PricierSide.self, forKey: .side))
        case .category: self = .category(index: try c.decode(Int.self, forKey: .index))
        case .bid: self = .bid(position: try c.decode(Int.self, forKey: .position))
        case .swipe: self = .swipe(liked: try c.decode(Bool.self, forKey: .liked))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind)
        switch self {
        case .pickPrice(let i): try c.encode(i, forKey: .index)
        case .higherLower(let s): try c.encode(s, forKey: .side)
        case .category(let i): try c.encode(i, forKey: .index)
        case .bid(let p): try c.encode(p, forKey: .position)
        case .swipe(let l): try c.encode(l, forKey: .liked)
        }
    }
}
