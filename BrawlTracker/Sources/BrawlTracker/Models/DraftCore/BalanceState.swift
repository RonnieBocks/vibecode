import Foundation

/// The game's numbers at one point in time — one patch, one document.
///
/// Holds **attributes only**. It deliberately contains no drafting concepts:
/// capabilities like "tank countering" are resolved from this plus the identity
/// layer, never authored here. A patch should be recordable by editing a
/// handful of attribute bands, not by re-scoring every drafting concept.
///
/// Versioned independently of `RankedSeason`, because patches land more often
/// than seasons do; a season points at whichever balance state is current.
struct BalanceState: Codable, Hashable, Identifiable {
    /// Stable identifier for this patch, e.g. "2026.09" — referenced by
    /// `RankedSeason.balanceVersion` and stamped onto resolved capabilities.
    var version: String
    var label: String
    var effectiveFrom: Date?
    var attributes: [BrawlerAttributes]
    var anchors: AttributeAnchors
    var notes: String?

    var id: String { version }

    init(version: String, label: String = "", effectiveFrom: Date? = nil,
         attributes: [BrawlerAttributes] = [], anchors: AttributeAnchors = .empty,
         notes: String? = nil) {
        self.version = version
        self.label = label.isEmpty ? version : label
        self.effectiveFrom = effectiveFrom
        self.attributes = attributes
        self.anchors = anchors
        self.notes = notes
    }

    private var index: [String: BrawlerAttributes] {
        Dictionary(attributes.map { ($0.key.normalized, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func attributes(for key: BrawlerKey) -> BrawlerAttributes? { index[key.normalized] }
    func attributes(for name: String) -> BrawlerAttributes? { index[BrawlerArt.normalize(name)] }

    /// Brawlers with a profile but no attributes recorded here. Capability
    /// resolution still works for these — every term simply resolves neutral.
    func missingAttributes(in profiles: BrawlerProfileSet) -> [String] {
        profiles.profiles.filter { index[$0.key.normalized] == nil }
            .map(\.key.normalized).sorted()
    }

    /// An empty state, so the whole stack is exercisable before any patch data
    /// is authored.
    static let unknown = BalanceState(version: "unknown", label: "No balance data")

    enum CodingKeys: String, CodingKey {
        case version, label, effectiveFrom, attributes, anchors, notes
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        version = d.get(.version, "unknown")
        label = d.get(.label, version)
        effectiveFrom = d.optional(.effectiveFrom)
        attributes = d.get(.attributes, [])
        anchors = d.get(.anchors, .empty)
        notes = d.optional(.notes)
    }
}
