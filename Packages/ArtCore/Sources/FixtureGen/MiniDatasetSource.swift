import ArtCore
import FixtureKit
import Foundation

/// Source table for `spec/fixtures/mini_dataset.json`: 30 synthetic-but-realistic works.
/// Titles and artists are real public-domain works; prices approximate published figures and
/// are for tests only. Log milli values are derived here so they are consistent with the USD values.
enum MiniDatasetSource {
    static let datasetID = "mini-2026.10"

    struct Work {
        var id: String, title: String, artist: String, born: Int, died: Int, nationality: String
        var dateDisplay: String, start: Int, end: Int, circa: Bool
        var category: String, also: [String], medium: String, mediumClass: String
        var amountMinor: Int64, currency: String, type: PriceType, premium: Bool?, approximate: Bool, lowerBound: Bool
        var saleDate: String, venue: String?, usd: Int64, scope: PriceScope
        var subject: String, mood: String, abstraction: Int, warmth: Int, saturation: Int, brightness: Int
        var complexity: Int, hex: String
    }

    // swiftlint:disable line_length
    static let works: [Work] = [
        Work(id: "leonardo-salvator-mundi", title: "Salvator Mundi", artist: "Leonardo da Vinci", born: 1452, died: 1519, nationality: "Italian", dateDisplay: "c. 1499–1510", start: 1499, end: 1510, circa: true, category: "renaissance_it", also: [], medium: "Oil on walnut", mediumClass: "painting", amountMinor: 45_031_250_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2017-11-15", venue: "Christie's New York", usd: 450_312_500, scope: .thisObject, subject: "religious_myth", mood: "serene", abstraction: 10, warmth: 55, saturation: 25, brightness: 25, complexity: 35, hex: "#3A3027"),
        Work(id: "botticelli-young-man-roundel", title: "Young Man Holding a Roundel", artist: "Sandro Botticelli", born: 1445, died: 1510, nationality: "Italian", dateDisplay: "c. 1480", start: 1480, end: 1480, circa: true, category: "renaissance_it", also: [], medium: "Tempera on panel", mediumClass: "painting", amountMinor: 9_218_450_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2021-01-28", venue: "Sotheby's New York", usd: 92_184_500, scope: .thisObject, subject: "portrait", mood: "serene", abstraction: 8, warmth: 60, saturation: 45, brightness: 55, complexity: 40, hex: "#5B6E7A"),
        Work(id: "durer-melencolia-i", title: "Melencolia I", artist: "Albrecht Dürer", born: 1471, died: 1528, nationality: "German", dateDisplay: "1514", start: 1514, end: 1514, circa: false, category: "renaissance_north", also: ["print"], medium: "Engraving", mediumClass: "print", amountMinor: 48_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2019-06-12", venue: "Christie's New York", usd: 480_000, scope: .sameEditionOtherImpression, subject: "figure", mood: "melancholic", abstraction: 20, warmth: 50, saturation: 5, brightness: 50, complexity: 85, hex: "#8C8577"),
        Work(id: "cranach-nymph-of-the-spring", title: "The Nymph of the Spring", artist: "Lucas Cranach the Elder", born: 1472, died: 1553, nationality: "German", dateDisplay: "c. 1530–1534", start: 1530, end: 1534, circa: true, category: "renaissance_north", also: [], medium: "Oil on panel", mediumClass: "painting", amountMinor: 945_000_000, currency: "GBP", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2015-07-08", venue: "Sotheby's London", usd: 14_650_000, scope: .thisObject, subject: "figure", mood: "serene", abstraction: 10, warmth: 60, saturation: 40, brightness: 45, complexity: 30, hex: "#2E3B2A"),
        Work(id: "durer-rhinoceros", title: "The Rhinoceros", artist: "Albrecht Dürer", born: 1471, died: 1528, nationality: "German", dateDisplay: "1515", start: 1515, end: 1515, circa: false, category: "print", also: ["renaissance_north"], medium: "Woodcut", mediumClass: "print", amountMinor: 25_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2019-01-29", venue: "Sotheby's New York", usd: 250_000, scope: .sameEditionOtherImpression, subject: "genre", mood: "serene", abstraction: 15, warmth: 50, saturation: 5, brightness: 80, complexity: 75, hex: "#9A9283"),
        Work(id: "rembrandt-hundred-guilder-print", title: "The Hundred Guilder Print", artist: "Rembrandt van Rijn", born: 1606, died: 1669, nationality: "Dutch", dateDisplay: "c. 1648", start: 1647, end: 1649, circa: true, category: "print", also: ["dutch_golden_age"], medium: "Etching, drypoint and engraving", mediumClass: "print", amountMinor: 23_750_000, currency: "GBP", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2014-12-04", venue: "Sotheby's London", usd: 372_000, scope: .sameEditionOtherImpression, subject: "religious_myth", mood: "dramatic", abstraction: 10, warmth: 55, saturation: 5, brightness: 45, complexity: 90, hex: "#6B6458"),
        Work(id: "rembrandt-aristotle", title: "Aristotle with a Bust of Homer", artist: "Rembrandt van Rijn", born: 1606, died: 1669, nationality: "Dutch", dateDisplay: "1653", start: 1653, end: 1653, circa: false, category: "dutch_golden_age", also: ["baroque"], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 230_000_000, currency: "USD", type: .auctionHammer, premium: false, approximate: false, lowerBound: false, saleDate: "1961-11-15", venue: "Parke-Bernet New York", usd: 2_300_000, scope: .thisObject, subject: "portrait", mood: "melancholic", abstraction: 8, warmth: 80, saturation: 35, brightness: 20, complexity: 40, hex: "#2B2016"),
        Work(id: "rembrandt-standard-bearer", title: "The Standard Bearer", artist: "Rembrandt van Rijn", born: 1606, died: 1669, nationality: "Dutch", dateDisplay: "1636", start: 1636, end: 1636, circa: false, category: "dutch_golden_age", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 17_500_000_000, currency: "EUR", type: .privateSale, premium: nil, approximate: true, lowerBound: false, saleDate: "2022", venue: nil, usd: 184_000_000, scope: .thisObject, subject: "portrait", mood: "dramatic", abstraction: 8, warmth: 75, saturation: 45, brightness: 25, complexity: 40, hex: "#3B2A1A"),
        Work(id: "vermeer-study-young-woman", title: "Study of a Young Woman", artist: "Johannes Vermeer", born: 1632, died: 1675, nationality: "Dutch", dateDisplay: "c. 1665–1667", start: 1665, end: 1667, circa: true, category: "dutch_golden_age", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 200_000_000, currency: "USD", type: .privateSale, premium: nil, approximate: true, lowerBound: false, saleDate: "1959", venue: nil, usd: 2_000_000, scope: .thisObject, subject: "portrait", mood: "serene", abstraction: 10, warmth: 55, saturation: 35, brightness: 30, complexity: 20, hex: "#2A2A26"),
        Work(id: "rubens-massacre-innocents", title: "Massacre of the Innocents", artist: "Peter Paul Rubens", born: 1577, died: 1640, nationality: "Flemish", dateDisplay: "c. 1611–1612", start: 1611, end: 1612, circa: true, category: "baroque", also: [], medium: "Oil on panel", mediumClass: "painting", amountMinor: 4_950_000_000, currency: "GBP", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2002-07-10", venue: "Sotheby's London", usd: 76_700_000, scope: .thisObject, subject: "religious_myth", mood: "dramatic", abstraction: 15, warmth: 75, saturation: 60, brightness: 45, complexity: 95, hex: "#6A3B24"),
        Work(id: "velazquez-juan-de-pareja", title: "Juan de Pareja", artist: "Diego Velázquez", born: 1599, died: 1660, nationality: "Spanish", dateDisplay: "1650", start: 1650, end: 1650, circa: false, category: "baroque", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 231_000_000, currency: "GBP", type: .auctionHammer, premium: false, approximate: true, lowerBound: false, saleDate: "1970-11-27", venue: "Christie's London", usd: 5_544_000, scope: .thisObject, subject: "portrait", mood: "serene", abstraction: 8, warmth: 65, saturation: 30, brightness: 30, complexity: 25, hex: "#4A4238"),
        Work(id: "chardin-basket-wild-strawberries", title: "Basket of Wild Strawberries", artist: "Jean-Siméon Chardin", born: 1699, died: 1779, nationality: "French", dateDisplay: "c. 1761", start: 1761, end: 1761, circa: true, category: "rococo", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 2_436_800_000, currency: "EUR", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2022-03-23", venue: "Artcurial Paris", usd: 26_800_000, scope: .thisObject, subject: "still_life", mood: "serene", abstraction: 5, warmth: 80, saturation: 50, brightness: 50, complexity: 20, hex: "#8B4A2E"),
        Work(id: "liotard-dutch-girl-breakfast", title: "Dutch Girl at Breakfast", artist: "Jean-Étienne Liotard", born: 1702, died: 1789, nationality: "Swiss", dateDisplay: "c. 1756", start: 1756, end: 1757, circa: true, category: "rococo", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 441_000_000, currency: "GBP", type: .privateSale, premium: nil, approximate: true, lowerBound: false, saleDate: "2016", venue: nil, usd: 6_400_000, scope: .thisObject, subject: "genre", mood: "serene", abstraction: 5, warmth: 55, saturation: 40, brightness: 70, complexity: 35, hex: "#B8A88A"),
        Work(id: "turner-seascape-folkestone", title: "Seascape: Folkestone", artist: "J. M. W. Turner", born: 1775, died: 1851, nationality: "British", dateDisplay: "c. 1845", start: 1845, end: 1845, circa: true, category: "romanticism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 737_000_000, currency: "GBP", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "1984-07-05", venue: "Sotheby's London", usd: 10_000_000, scope: .thisObject, subject: "landscape", mood: "dramatic", abstraction: 70, warmth: 55, saturation: 35, brightness: 70, complexity: 30, hex: "#A7A28C"),
        Work(id: "friedrich-moonrise-study", title: "Moonrise over the Sea (study)", artist: "Caspar David Friedrich", born: 1774, died: 1840, nationality: "German", dateDisplay: "c. 1821", start: 1821, end: 1821, circa: true, category: "romanticism", also: [], medium: "Pencil and sepia on paper", mediumClass: "drawing", amountMinor: 34_000_000, currency: "EUR", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2018-11-16", venue: "Lempertz Cologne", usd: 401_000, scope: .thisObject, subject: "landscape", mood: "melancholic", abstraction: 40, warmth: 40, saturation: 15, brightness: 35, complexity: 15, hex: "#5E5546"),
        Work(id: "monet-meules", title: "Meules", artist: "Claude Monet", born: 1840, died: 1926, nationality: "French", dateDisplay: "1890", start: 1890, end: 1890, circa: false, category: "impressionism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 11_074_700_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2019-05-14", venue: "Sotheby's New York", usd: 110_747_000, scope: .thisObject, subject: "landscape", mood: "serene", abstraction: 45, warmth: 75, saturation: 70, brightness: 70, complexity: 55, hex: "#C79A5A"),
        Work(id: "renoir-bal-du-moulin-small", title: "Bal du moulin de la Galette (small version)", artist: "Pierre-Auguste Renoir", born: 1841, died: 1919, nationality: "French", dateDisplay: "1876", start: 1876, end: 1876, circa: false, category: "impressionism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 7_810_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "1990-05-17", venue: "Sotheby's New York", usd: 78_100_000, scope: .thisObject, subject: "genre", mood: "joyful", abstraction: 30, warmth: 55, saturation: 60, brightness: 65, complexity: 90, hex: "#6E7B6A"),
        Work(id: "morisot-garden-study", title: "Garden Study at Bougival", artist: "Berthe Morisot", born: 1841, died: 1895, nationality: "French", dateDisplay: "c. 1883", start: 1883, end: 1883, circa: true, category: "impressionism", also: [], medium: "Watercolour on paper", mediumClass: "drawing", amountMinor: 4_500_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2015-05-06", venue: "Christie's New York", usd: 45_000, scope: .thisObject, subject: "landscape", mood: "joyful", abstraction: 55, warmth: 60, saturation: 45, brightness: 80, complexity: 35, hex: "#A9B79A"),
        Work(id: "vangogh-portrait-dr-gachet", title: "Portrait of Dr. Gachet", artist: "Vincent van Gogh", born: 1853, died: 1890, nationality: "Dutch", dateDisplay: "1890", start: 1890, end: 1890, circa: false, category: "post_impressionism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 8_250_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "1990-05-15", venue: "Christie's New York", usd: 82_500_000, scope: .thisObject, subject: "portrait", mood: "melancholic", abstraction: 35, warmth: 30, saturation: 75, brightness: 45, complexity: 60, hex: "#3E5A8C"),
        Work(id: "cezanne-card-players", title: "The Card Players", artist: "Paul Cézanne", born: 1839, died: 1906, nationality: "French", dateDisplay: "c. 1892–1893", start: 1892, end: 1893, circa: true, category: "post_impressionism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 25_000_000_000, currency: "USD", type: .privateSale, premium: nil, approximate: true, lowerBound: true, saleDate: "2011", venue: nil, usd: 250_000_000, scope: .thisObject, subject: "genre", mood: "serene", abstraction: 30, warmth: 65, saturation: 45, brightness: 40, complexity: 40, hex: "#7A5A3A"),
        Work(id: "gauguin-nafea-faa-ipoipo", title: "Nafea Faa Ipoipo", artist: "Paul Gauguin", born: 1848, died: 1903, nationality: "French", dateDisplay: "1892", start: 1892, end: 1892, circa: false, category: "post_impressionism", also: ["symbolism"], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 21_000_000_000, currency: "USD", type: .privateSale, premium: nil, approximate: true, lowerBound: false, saleDate: "2014", venue: nil, usd: 210_000_000, scope: .thisObject, subject: "figure", mood: "serene", abstraction: 45, warmth: 85, saturation: 80, brightness: 65, complexity: 50, hex: "#C98A3A"),
        Work(id: "seurat-les-poseuses-small", title: "Les Poseuses (small version)", artist: "Georges Seurat", born: 1859, died: 1891, nationality: "French", dateDisplay: "1888", start: 1888, end: 1888, circa: false, category: "pointillism", also: ["post_impressionism"], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 14_924_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2022-11-09", venue: "Christie's New York", usd: 149_240_000, scope: .thisObject, subject: "figure", mood: "serene", abstraction: 40, warmth: 55, saturation: 50, brightness: 75, complexity: 80, hex: "#B8A27E"),
        Work(id: "signac-harbour-sketch", title: "Harbour at Saint-Tropez (sketch)", artist: "Paul Signac", born: 1863, died: 1935, nationality: "French", dateDisplay: "c. 1905", start: 1905, end: 1905, circa: true, category: "pointillism", also: [], medium: "Watercolour and pencil on paper", mediumClass: "drawing", amountMinor: 2_800_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2017-03-02", venue: "Christie's New York", usd: 28_000, scope: .thisObject, subject: "landscape", mood: "joyful", abstraction: 55, warmth: 55, saturation: 75, brightness: 80, complexity: 55, hex: "#7FB0C8"),
        Work(id: "klimt-elisabeth-lederer", title: "Portrait of Elisabeth Lederer", artist: "Gustav Klimt", born: 1862, died: 1918, nationality: "Austrian", dateDisplay: "1914–1916", start: 1914, end: 1916, circa: false, category: "symbolism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 23_636_500_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2025-11-18", venue: "Sotheby's New York", usd: 236_365_000, scope: .thisObject, subject: "portrait", mood: "joyful", abstraction: 40, warmth: 65, saturation: 70, brightness: 70, complexity: 85, hex: "#C9A55C"),
        Work(id: "redon-vase-of-flowers", title: "Vase of Flowers (pastel)", artist: "Odilon Redon", born: 1840, died: 1916, nationality: "French", dateDisplay: "c. 1905", start: 1905, end: 1905, circa: true, category: "symbolism", also: [], medium: "Pastel on paper", mediumClass: "drawing", amountMinor: 145_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2016-11-14", venue: "Christie's New York", usd: 1_450_000, scope: .thisObject, subject: "still_life", mood: "serene", abstraction: 50, warmth: 55, saturation: 80, brightness: 55, complexity: 50, hex: "#4A6A8A"),
        Work(id: "munch-scream-pastel", title: "The Scream (pastel)", artist: "Edvard Munch", born: 1863, died: 1944, nationality: "Norwegian", dateDisplay: "1895", start: 1895, end: 1895, circa: false, category: "expressionism", also: ["symbolism"], medium: "Pastel on board", mediumClass: "drawing", amountMinor: 11_992_250_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2012-05-02", venue: "Sotheby's New York", usd: 119_922_500, scope: .thisObject, subject: "figure", mood: "dramatic", abstraction: 55, warmth: 85, saturation: 85, brightness: 55, complexity: 55, hex: "#D9772E"),
        Work(id: "kirchner-berlin-street-scene", title: "Berlin Street Scene", artist: "Ernst Ludwig Kirchner", born: 1880, died: 1938, nationality: "German", dateDisplay: "1913–1914", start: 1913, end: 1914, circa: false, category: "expressionism", also: [], medium: "Oil on canvas", mediumClass: "painting", amountMinor: 3_810_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2006-11-08", venue: "Christie's New York", usd: 38_100_000, scope: .thisObject, subject: "genre", mood: "dramatic", abstraction: 60, warmth: 55, saturation: 85, brightness: 45, complexity: 75, hex: "#3F6E4A"),
        Work(id: "schiele-seated-woman", title: "Seated Woman with Bent Knee", artist: "Egon Schiele", born: 1890, died: 1918, nationality: "Austrian", dateDisplay: "1917", start: 1917, end: 1917, circa: false, category: "expressionism", also: [], medium: "Gouache, watercolour and black crayon", mediumClass: "drawing", amountMinor: 170_000_000, currency: "GBP", type: .auctionPremium, premium: true, approximate: true, lowerBound: false, saleDate: "2019-06-19", venue: "Sotheby's London", usd: 2_200_000, scope: .thisObject, subject: "figure", mood: "melancholic", abstraction: 35, warmth: 70, saturation: 55, brightness: 80, complexity: 30, hex: "#C78E5A"),
        Work(id: "hokusai-under-the-wave", title: "Under the Wave off Kanagawa", artist: "Katsushika Hokusai", born: 1760, died: 1849, nationality: "Japanese", dateDisplay: "c. 1830–1832", start: 1830, end: 1832, circa: true, category: "ukiyo_e", also: ["print"], medium: "Woodblock print", mediumClass: "print", amountMinor: 276_000_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2023-03-21", venue: "Christie's New York", usd: 2_760_000, scope: .sameEditionOtherImpression, subject: "landscape", mood: "dramatic", abstraction: 45, warmth: 30, saturation: 55, brightness: 70, complexity: 70, hex: "#2F4A6B"),
        Work(id: "hiroshige-sudden-shower", title: "Sudden Shower over Shin-Ōhashi Bridge and Atake", artist: "Utagawa Hiroshige", born: 1797, died: 1858, nationality: "Japanese", dateDisplay: "1857", start: 1857, end: 1857, circa: false, category: "ukiyo_e", also: ["print"], medium: "Woodblock print", mediumClass: "print", amountMinor: 520_000, currency: "USD", type: .auctionPremium, premium: true, approximate: false, lowerBound: false, saleDate: "2018-09-12", venue: "Bonhams New York", usd: 5_200, scope: .sameEditionOtherImpression, subject: "landscape", mood: "melancholic", abstraction: 40, warmth: 35, saturation: 45, brightness: 55, complexity: 60, hex: "#4E5E6A"),
    ]
    // swiftlint:enable line_length

    /// Approximate CPI-U multipliers to 2025 dollars, ×1000, by sale year.
    static let cpiTo2025Milli: [Int: Int64] = [
        1959: 11_090, 1961: 10_770, 1970: 8_290, 1984: 3_100, 1990: 2_470, 2002: 1_790, 2006: 1_600,
        2011: 1_430, 2012: 1_400, 2014: 1_360, 2015: 1_360, 2016: 1_340, 2017: 1_310, 2018: 1_280,
        2019: 1_260, 2021: 1_190, 2022: 1_100, 2023: 1_060, 2025: 1_000,
    ]

    /// Synthetic 5-colour palette: the dominant colour followed by four deterministic shades of it.
    static func palette(_ hex: String) -> [String] {
        let v = Int(hex.dropFirst(), radix: 16)!
        let rgb = [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]
        return [hex] + [40, 80, -30, -60].map { delta in
            "#" + rgb.map { c -> String in
                let s = String(min(255, max(0, c + delta)), radix: 16, uppercase: true)
                return s.count == 1 ? "0" + s : s
            }.joined()
        }
    }

    static func logMilli(_ usd: Int64) -> Int {
        Int((1000 * log10(Double(usd))).rounded(.toNearestOrAwayFromZero))
    }

    static func artwork(_ w: Work) -> Artwork {
        let year = Int(w.saleDate.prefix(4))!
        let adjusted = w.usd * cpiTo2025Milli[year]! / 1000
        let priceID = w.id + "-p1"
        let price = PriceRecord(
            id: priceID, amountMinor: w.amountMinor, currency: w.currency, type: w.type, premiumIncluded: w.premium,
            approximate: w.approximate, lowerBound: w.lowerBound, date: w.saleDate, venue: w.venue,
            usdNominal: w.usd, usdAdjusted: adjusted, adjustRefYear: 2025, log10UsdNominalMilli: logMilli(w.usd),
            log10UsdAdjustedMilli: logMilli(adjusted), sourceURLs: ["https://example.org/fixture/\(w.id)"],
            confidence: .high, gameEligible: true, priceScope: w.scope)
        let image = ImageRef(
            sm: ImageFile(file: "\(w.id)_sm.jpg", w: 600, h: 750, bytes: nil),
            lg: ImageFile(file: "\(w.id)_lg.jpg", w: 1280, h: 1600, bytes: nil), sourceURL: nil, landingURL: nil,
            licence: "CC0", attribution: "Fixture image (synthetic)", depictsScope: w.scope.rawValue,
            altText: "\(w.title) by \(w.artist)", focus: FocusPoint(x: 500, y: 400), dominantHex: w.hex,
            palette: palette(w.hex))
        let slug = w.artist.lowercased().split(separator: " ").joined(separator: "-")
        return Artwork(
            id: ArtworkID(w.id), kind: "pd_masterpiece", title: w.title,
            artist: ArtistRef(id: slug, displayName: w.artist, birthYear: w.born, deathYear: w.died, nationality: w.nationality),
            date: ArtworkDate(display: w.dateDisplay, start: w.start, end: w.end, circa: w.circa),
            category: CategoryID(w.category), acceptedAlso: w.also.map(CategoryID.init(_:)),
            medium: Medium(display: w.medium, mediumClass: w.mediumClass), images: ArtworkImages(primary: image),
            prices: [price], gamePriceID: priceID,
            taste: TasteFeatures(
                eraBucket: TasteFeatures.eraBucket(forYear: w.start), subject: w.subject, mood: w.mood,
                abstraction: w.abstraction, warmth: w.warmth, saturation: w.saturation, brightness: w.brightness,
                complexity: w.complexity))
    }

    static func category(
        _ id: String, _ label: String, _ axis: CategoryAxis, _ start: Int, _ end: Int, parent: String? = nil,
        neighbours: [String], confusers: [String], active: Bool = true, minQuizItems: Int = 2, teach: String
    ) -> ArtCore.Category {
        ArtCore.Category(
            id: CategoryID(id), label: label, axis: axis, era: EraRange(start: start, end: end),
            parent: parent.map(CategoryID.init(_:)), teach: teach,
            tells: ["Fixture tell 1", "Fixture tell 2", "Fixture tell 3"],
            neighbours: neighbours.map(CategoryID.init(_:)), confusers: confusers.map(CategoryID.init(_:)),
            minQuizItems: minQuizItems, active: active, departmentID: departmentOf[id].map(DepartmentID.init(_:)))
    }

    /// Departments (plan Part I1) restricted to the categories in this taxonomy. Sculpture has none.
    static let departmentRows: [(String, String, [String])] = [
        ("old_masters", "Old Masters", ["renaissance_it", "renaissance_north", "baroque", "dutch_golden_age", "rococo"]),
        ("nineteenth_century", "19th Century", ["romanticism"]),
        ("impressionist_modern", "Impressionist & Modern", ["impressionism", "post_impressionism", "pointillism", "symbolism", "expressionism"]),
        ("asian_art", "Asian Art", ["ukiyo_e"]),
        ("prints_multiples", "Prints & Multiples", ["print"]),
    ]

    static let departments: [Department] = departmentRows.map {
        Department(id: DepartmentID($0.0), label: $0.1, categories: $0.2.map(CategoryID.init(_:)))
    }

    static let departmentOf: [String: String] = {
        var map: [String: String] = [:]
        for (d, _, cats) in departmentRows { for c in cats { map[c] = d } }
        return map
    }()

    static let taxonomy: [ArtCore.Category] = [
        category("renaissance_it", "Italian Renaissance", .movement, 1400, 1550, neighbours: ["renaissance_north"], confusers: ["baroque"], teach: "Balanced, idealised figures and linear perspective."),
        category("renaissance_north", "Northern Renaissance", .movement, 1430, 1580, neighbours: ["renaissance_it"], confusers: ["dutch_golden_age"], teach: "Minute detail and oil glazes north of the Alps."),
        category("dutch_golden_age", "Dutch Golden Age", .movement, 1600, 1700, neighbours: ["baroque"], confusers: ["renaissance_north"], teach: "Everyday Dutch life, portraits and light."),
        category("baroque", "Baroque", .movement, 1590, 1720, neighbours: ["dutch_golden_age", "rococo"], confusers: ["renaissance_it"], teach: "Drama, movement and strong light and shade."),
        category("rococo", "Rococo", .movement, 1720, 1780, neighbours: ["baroque"], confusers: ["romanticism"], minQuizItems: 3, teach: "Light, playful elegance in pastel tones."),
        category("romanticism", "Romanticism", .movement, 1790, 1850, neighbours: ["impressionism"], confusers: ["baroque"], teach: "Emotion and the sublime power of nature."),
        category("impressionism", "Impressionism", .movement, 1865, 1895, neighbours: ["post_impressionism", "pointillism"], confusers: ["romanticism"], teach: "Fleeting light in quick, visible brushstrokes."),
        category("post_impressionism", "Post-Impressionism", .movement, 1885, 1910, neighbours: ["impressionism", "symbolism"], confusers: ["expressionism"], teach: "Bold colour and structure beyond Impressionism."),
        category("pointillism", "Pointillism", .movement, 1884, 1905, parent: "post_impressionism", neighbours: ["impressionism", "symbolism"], confusers: ["post_impressionism"], teach: "Pure colour applied in small dots."),
        category("symbolism", "Symbolism", .movement, 1870, 1915, neighbours: ["post_impressionism", "expressionism"], confusers: ["romanticism"], teach: "Dreams, myth and mood over description."),
        category("expressionism", "Expressionism", .movement, 1905, 1930, neighbours: ["symbolism", "post_impressionism"], confusers: ["pointillism"], teach: "Distorted form and colour to convey feeling."),
        category("ukiyo_e", "Ukiyo-e", .movement, 1660, 1900, neighbours: ["post_impressionism", "impressionism"], confusers: ["symbolism"], teach: "Japanese woodblock pictures of the floating world."),
        category("print", "Print", .medium, 1450, 1930, neighbours: ["ukiyo_e"], confusers: ["renaissance_north"], teach: "An image made to be printed in multiple impressions."),
        category("sculpture", "Sculpture", .medium, 1400, 1930, neighbours: [], confusers: [], active: false, teach: "Reserved; inactive until pricing is resolved."),
    ]

    /// Synthetic baseline: p_like in 0.30…0.70 derived from the bucket name's FNV hash.
    static func tasteBaseline(artworks: [Artwork]) -> TasteBaseline {
        var buckets = Set<String>()
        for a in artworks { buckets.formUnion(TasteBuckets.buckets(for: a)) }
        for era in ["pre1500", "1500_1600", "1600_1700", "1700_1800", "1800_1850", "1850_1900", "1900_1930"] {
            buckets.insert("era:" + era)
        }
        for (family, names) in TasteBuckets.levelNames { for n in names { buckets.insert(family + ":" + n) } }
        var features: [String: BucketBaseline] = [:]
        for b in buckets {
            features[b] = BucketBaseline(pLike: 0.30 + Double(fnv1a64(b) % 41) / 100, n: 5000)
        }
        var shares: [String: Double] = [:]
        var weights: [String: Int] = [:]
        var total = 0
        for era in ["O", "M"] { for form in ["F", "A"] { for pal in ["E", "V"] { for mood in ["S", "D"] {
            let id = era + form + pal + mood
            let w = 1 + Int(fnv1a64("archetype|" + id) % 9)
            weights[id] = w
            total += w
        } } } }
        for (id, w) in weights { shares[id] = (Double(w * 10_000 / total)) / 10_000 }
        return TasteBaseline(
            schemaVersion: 1, baselineID: "mini-synthetic-1", features: features, alpha: 4,
            distinctivenessPercentiles: [
                "swipes_10": PercentileKnots(p50: 0.18, p75: 0.24, p90: 0.30, p95: 0.34, p99: 0.42),
                "swipes_20": PercentileKnots(p50: 0.16, p75: 0.22, p90: 0.28, p95: 0.32, p99: 0.40),
                "swipes_40": PercentileKnots(p50: 0.15, p75: 0.21, p90: 0.27, p95: 0.31, p99: 0.38),
                "swipes_80": PercentileKnots(p50: 0.14, p75: 0.20, p90: 0.26, p95: 0.30, p99: 0.37),
            ],
            archetypeShares: shares)
    }

    static func make() -> MiniDataset {
        let artworks = works.map(artwork)
        return MiniDataset(
            schemaVersion: 1, datasetID: datasetID,
            description: "Frozen 30-work synthetic dataset for ArtCore fixtures. Real public-domain titles with approximate, unverified prices; not for shipping.",
            artworks: artworks, taxonomy: taxonomy, departments: departments, tasteBaseline: tasteBaseline(artworks: artworks),
            disclaimer: "Fixture prices are approximate and for tests only; nothing here is an appraisal.", refYear: 2025)
    }
}
