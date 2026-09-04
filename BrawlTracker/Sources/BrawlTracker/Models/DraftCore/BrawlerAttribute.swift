import Foundation

/// A directly measurable property of a brawler at one balance state.
///
/// These are the things a patch actually edits. Open vocabulary, so a new
/// dimension (say `superChargeRate`) can be added later without a migration.
struct AttributeKind: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    static let damage           = AttributeKind(rawValue: "damage")
    static let burstDamage      = AttributeKind(rawValue: "burstDamage")
    static let effectiveHealth  = AttributeKind(rawValue: "effectiveHealth")
    static let range            = AttributeKind(rawValue: "range")
    static let reloadSpeed      = AttributeKind(rawValue: "reloadSpeed")
    static let projectileSpeed  = AttributeKind(rawValue: "projectileSpeed")
    static let movementSpeed    = AttributeKind(rawValue: "movementSpeed")
    static let healingOutput    = AttributeKind(rawValue: "healingOutput")
    static let ammoCapacity     = AttributeKind(rawValue: "ammoCapacity")
    static let areaCoverage     = AttributeKind(rawValue: "areaCoverage")
    static let superChargeRate  = AttributeKind(rawValue: "superChargeRate")

    static let known: [AttributeKind] = [
        .damage, .burstDamage, .effectiveHealth, .range, .reloadSpeed,
        .projectileSpeed, .movementSpeed, .healingOutput, .ammoCapacity,
        .areaCoverage, .superChargeRate,
    ]
}

/// Qualitative band — the primary authoring method, since neither the official
/// API nor BrawlAPI exposes raw stat numbers. Bands map to *fixed* normalized
/// values: a band means the same thing for every attribute and every brawler,
/// and one brawler's change never moves another's number.
enum AttributeBand: String, Codable, CaseIterable, Comparable {
    case veryLow, low, belowAverage, average, aboveAverage, high, veryHigh

    var normalized: Double {
        switch self {
        case .veryLow:       return 0.00
        case .low:           return 0.17
        case .belowAverage:  return 0.33
        case .average:       return 0.50
        case .aboveAverage:  return 0.67
        case .high:          return 0.83
        case .veryHigh:      return 1.00
        }
    }

    static func < (a: AttributeBand, b: AttributeBand) -> Bool { a.normalized < b.normalized }
}

/// Where a value came from, so confidence can be reported honestly.
enum AttributeProvenance: String, Codable, CaseIterable {
    case measured    // read off real values
    case estimated   // judged by hand
    case derived     // computed from other attributes
    case inherited   // carried from a previous balance state
    case unknown
}

/// One attribute's value. Band and raw may both be present; `raw` wins when an
/// anchor exists for the kind, because it is strictly more precise.
struct AttributeValue: Codable, Hashable {
    var band: AttributeBand?
    var raw: Double?
    var provenance: AttributeProvenance
    var note: String?

    init(band: AttributeBand? = nil, raw: Double? = nil,
         provenance: AttributeProvenance = .estimated, note: String? = nil) {
        self.band = band; self.raw = raw; self.provenance = provenance; self.note = note
    }

    /// How this value resolved, for explanations and confidence.
    enum Resolution: String { case raw, band, none }

    func resolve(_ kind: AttributeKind, anchors: AttributeAnchors) -> (value: Double, how: Resolution)? {
        if let raw, let anchor = anchors[kind] { return (anchor.normalize(raw), .raw) }
        if let band { return (band.normalized, .band) }
        if let raw { return (min(1, max(0, raw)), .raw) }   // already normalized, no anchor
        return nil
    }

    enum CodingKeys: String, CodingKey { case band, raw, provenance, note }
    init(from decoder: Decoder) throws {
        // A bare band string is accepted, so terse authoring stays possible.
        if let s = try? decoder.singleValueContainer().decode(String.self),
           let b = AttributeBand(rawValue: s) {
            self = AttributeValue(band: b); return
        }
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        self = AttributeValue(band: d.optional(.band),
                              raw: d.optional(.raw),
                              provenance: d.get(.provenance, .estimated),
                              note: d.optional(.note))
    }
}

/// Fixed low/high reference points that map a raw value onto 0…1.
///
/// Deliberately *not* derived from the roster: a percentile scale would mean
/// buffing one brawler silently shifts everyone else's normalized values.
struct AttributeAnchor: Codable, Hashable {
    var low: Double
    var high: Double
    var unit: String?

    func normalize(_ raw: Double) -> Double {
        guard high != low else { return 0.5 }
        return min(1, max(0, (raw - low) / (high - low)))
    }
}

struct AttributeAnchors: Codable, Hashable {
    var anchors: TermMap<AttributeKind, AttributeAnchor>

    init(_ anchors: TermMap<AttributeKind, AttributeAnchor> = TermMap()) { self.anchors = anchors }
    subscript(kind: AttributeKind) -> AttributeAnchor? { anchors[kind] }

    /// Ships empty. Anchors are only needed once raw values are authored; until
    /// then every value resolves through its band.
    static let empty = AttributeAnchors()

    enum CodingKeys: String, CodingKey { case anchors }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        anchors = d.get(.anchors, TermMap())
    }
}

/// Every attribute known for one brawler at one balance state.
struct BrawlerAttributes: Codable, Hashable {
    var key: BrawlerKey
    var values: TermMap<AttributeKind, AttributeValue>

    init(key: BrawlerKey, values: TermMap<AttributeKind, AttributeValue> = TermMap()) {
        self.key = key; self.values = values
    }

    subscript(kind: AttributeKind) -> AttributeValue? {
        get { values[kind] }
        set { values[kind] = newValue }
    }

    func normalized(_ kind: AttributeKind, anchors: AttributeAnchors) -> Double? {
        values[kind]?.resolve(kind, anchors: anchors)?.value
    }

    enum CodingKeys: String, CodingKey { case key, values }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        key = d.get(.key, BrawlerKey(normalized: ""))
        values = d.get(.values, TermMap())
    }
}
