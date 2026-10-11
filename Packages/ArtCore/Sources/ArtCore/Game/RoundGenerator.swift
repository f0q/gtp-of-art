/// Generates a single round of any kind from a pool.
public enum RoundGenerator {
    /// Era window applied to "which is pricier" rounds by difficulty (nil = none).
    public static func pairYearWindow(_ difficulty: Difficulty) -> Int? {
        difficulty == .easy ? nil : PairSelector.defaultYearWindow
    }

    /// Makes a round for `spec`, never using an artwork in `used`.
    ///
    /// Single-artwork kinds: `E` = eligible works not in `used` (pool order, i.e. sorted by id).
    /// Repeat: `k = nextInt(|E|)`; try to build the round for `E[k]`; on failure remove `E[k]`
    /// and repeat; throw `poolExhausted` when `E` is empty. With a `prior`, `k` is instead
    /// `WeightedPicker.pick(weights: E.map { prior.weight(for: $0) })` (single-artwork kinds) and
    /// pairs get a soft same-department preference (`PairSelector.passes(…preferredDepartments:)`). Eligibility: pick-the-price and bid
    /// need a game price (pick-the-price also within $500…$2B); category needs a quiz-eligible
    /// category; swipe takes any work. Higher-lower delegates to `PairSelector`.
    public static func makeRound(
        spec: RoundSpec, pool: GamePool, used: Set<ArtworkID>, anchor: ArtworkID? = nil,
        prior: TastePrior? = nil, rng: inout SplitMix64
    ) throws -> Round {
        func pick(_ eligible: [Artwork], _ kind: RoundKind, _ build: (Artwork, inout SplitMix64) throws -> Round)
            throws -> Round
        {
            try pickFirstBuildable(eligible, kind: kind, pool: pool, prior: prior, rng: &rng, build: build)
        }
        switch spec.kind {
        case .higherLower:
            return .higherLower(
                try PairSelector.select(
                    pool: pool, difficulty: spec.difficulty, yearWindow: pairYearWindow(spec.difficulty),
                    used: used, anchor: anchor, prior: prior, rng: &rng))

        case .pickPrice:
            let eligible = pool.artworks.filter { a in
                guard !used.contains(a.id), let p = a.gamePrice else { return false }
                return p.usdNominal >= PriceOptionGenerator.minUSD && p.usdNominal <= PriceOptionGenerator.maxUSD
            }
            return try pick(eligible, .pickPrice) { artwork, rng in
                let price = artwork.gamePrice!
                let options = try PriceOptionGenerator.make(
                    truthUSD: price.usdNominal, difficulty: spec.difficulty, rng: &rng)
                return .pickPrice(
                    PickPriceRound(
                        artwork: artwork.id, priceID: price.id, options: options.options,
                        correctIndex: options.correctIndex, difficulty: spec.difficulty))
            }

        case .bid:
            let eligible = pool.artworks.filter { !used.contains($0.id) && $0.gamePrice != nil }
            return try pick(eligible, .bid) { artwork, _ in
                let price = artwork.gamePrice!
                return .bid(
                    BidRound(
                        artwork: artwork.id, priceID: price.id, actualMilli: price.log10UsdNominalMilli,
                        actualUSD: price.usdNominal))
            }

        case .category:
            let eligible = pool.artworks.filter {
                !used.contains($0.id) && CategoryQuestionGenerator.truthCategory(for: $0, pool: pool) != nil
            }
            return try pick(eligible, .category) { artwork, rng in
                .category(
                    try CategoryQuestionGenerator.make(
                        artwork: artwork, pool: pool, difficulty: spec.difficulty, rng: &rng))
            }

        case .swipe:
            let eligible = pool.artworks.filter { !used.contains($0.id) }
            return try pick(eligible, .swipe) { artwork, _ in
                .swipe(SwipeRound(artwork: artwork.id))
            }
        }
    }

    static func pickFirstBuildable(
        _ eligible: [Artwork], kind: RoundKind, pool: GamePool, prior: TastePrior?, rng: inout SplitMix64,
        build: (Artwork, inout SplitMix64) throws -> Round
    ) throws -> Round {
        var remaining = eligible
        while !remaining.isEmpty {
            let k: Int
            if let prior {
                k = WeightedPicker.pick(weights: remaining.map { prior.weight(for: $0, in: pool) }, rng: &rng)!
            } else {
                k = rng.nextInt(remaining.count)
            }
            do {
                return try build(remaining[k], &rng)
            } catch {
                remaining.remove(at: k)
            }
        }
        throw GenerationError.poolExhausted(kind)
    }
}
