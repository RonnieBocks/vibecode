import Foundation

/// Stable identity for a brawler across every DraftCore document.
///
/// Identity is the *normalized name*, because that is what the existing history
/// is keyed on: `MatchRecord` stores team and ban lists as display names, and
/// `DraftLearning` tallies on `BrawlerArt.normalize`. Keying on the numeric id
/// instead would orphan every match already logged.
///
/// `aliases` exists so a future rename can be absorbed without rewriting stored
/// history — the alias resolves to the same key. Nothing consumes it yet.
struct BrawlerKey: Codable, Hashable, Comparable, CustomStringConvertible {
    /// The canonical, comparison-safe form. Sole basis of equality.
    let normalized: String
    /// Human-facing spelling, when known. Never affects identity.
    var displayName: String?
    /// Numeric id from the official API / BrawlAPI, when known.
    var brawlerID: Int?
    /// Former or alternate spellings that resolve to this same brawler.
    var aliases: [String]

    init(_ name: String, id: Int? = nil, aliases: [String] = []) {
        normalized = BrawlerArt.normalize(name)
        displayName = name
        brawlerID = id
        self.aliases = aliases
    }

    /// Rebuilds from an already-normalized string (decoding, dictionary keys).
    init(normalized: String) {
        self.normalized = normalized
        displayName = nil
        brawlerID = nil
        aliases = []
    }

    var description: String { displayName ?? normalized }

    /// Does this key answer to `name`, directly or by alias?
    func matches(_ name: String) -> Bool {
        let n = BrawlerArt.normalize(name)
        return n == normalized || aliases.contains { BrawlerArt.normalize($0) == n }
    }

    // Identity is the normalized name alone: two keys for the same brawler must
    // stay equal even when one carries a display name or id and the other doesn't.
    static func == (a: BrawlerKey, b: BrawlerKey) -> Bool { a.normalized == b.normalized }
    func hash(into hasher: inout Hasher) { hasher.combine(normalized) }
    static func < (a: BrawlerKey, b: BrawlerKey) -> Bool { a.normalized < b.normalized }

    enum CodingKeys: String, CodingKey { case normalized, displayName, brawlerID, aliases }

    init(from decoder: Decoder) throws {
        // Accept either a bare string ("lou") or a full object, so authored
        // files can stay terse where there is nothing extra to say.
        if let s = try? decoder.singleValueContainer().decode(String.self) {
            self = BrawlerKey(normalized: BrawlerArt.normalize(s))
            return
        }
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        var key = BrawlerKey(normalized: d.get(.normalized, ""))
        key.displayName = d.optional(.displayName)
        key.brawlerID = d.optional(.brawlerID)
        key.aliases = d.get(.aliases, [])
        self = key
    }
}
