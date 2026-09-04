import Foundation

/// Schema plumbing shared by every DraftCore type.
///
/// Two rules hold this layer together:
///
/// 1. **Vocabularies are open.** Attributes, traits, draft functions and
///    capabilities are string-backed terms rather than closed enums, so a new
///    dimension can be added — in code or in an authored JSON file — without a
///    schema migration and without older builds failing to decode it.
/// 2. **Structs decode tolerantly.** Every aggregate uses `decodeIfPresent`
///    with a default, mirroring `DraftWeights`, so adding a field never
///    discards a saved document.
enum DraftCoreSchema {
    /// Bumped only when a change cannot be absorbed by tolerant decoding.
    static let version = 1
}

// MARK: - Open vocabularies

/// A term in an open vocabulary: `RawRepresentable` by `String`, so unknown
/// values round-trip instead of throwing. `known` lists the terms this build
/// ships with — it is for UI and tests, never for validation.
protocol VocabularyTerm: RawRepresentable, Codable, Hashable, CustomStringConvertible,
                         Comparable where RawValue == String {
    init(rawValue: String)
    static var known: [Self] { get }
}

extension VocabularyTerm {
    var description: String { rawValue }
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// True when this build recognises the term. A `false` here is information,
    /// not an error — an unrecognised term is carried through untouched.
    var isKnown: Bool { Self.known.contains(self) }

    /// "escapeMobility" -> "Escape Mobility", for display without a lookup table.
    var displayName: String {
        var out = ""
        for (i, ch) in rawValue.enumerated() {
            if i > 0, ch.isUppercase { out.append(" ") }
            out.append(i == 0 ? Character(ch.uppercased()) : ch)
        }
        return out
    }
}

// MARK: - Term-keyed storage

/// A dictionary keyed by a vocabulary term.
///
/// Backed by `[String: Value]` so `Codable` synthesis produces a clean JSON
/// object (`{"damage": …}`) rather than the alternating key/value array Swift
/// emits for dictionaries with non-`String` keys. That matters because these
/// documents are meant to be hand-authored and diffed.
struct TermMap<Term: VocabularyTerm, Value: Codable & Hashable>: Codable, Hashable,
                                                                 ExpressibleByDictionaryLiteral {
    private(set) var storage: [String: Value]

    init() { storage = [:] }
    init(_ pairs: [Term: Value]) {
        storage = Dictionary(pairs.map { ($0.key.rawValue, $0.value) }, uniquingKeysWith: { a, _ in a })
    }
    init(dictionaryLiteral elements: (Term, Value)...) {
        storage = Dictionary(elements.map { ($0.0.rawValue, $0.1) }, uniquingKeysWith: { a, _ in a })
    }
    init(from decoder: Decoder) throws {
        storage = (try? decoder.singleValueContainer().decode([String: Value].self)) ?? [:]
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(storage)
    }

    subscript(term: Term) -> Value? {
        get { storage[term.rawValue] }
        set { storage[term.rawValue] = newValue }
    }

    var terms: [Term] { storage.keys.map { Term(rawValue: $0) }.sorted() }
    var values: [Value] { Array(storage.values) }
    var isEmpty: Bool { storage.isEmpty }
    var count: Int { storage.count }

    /// Pairs in a stable order, so explanations and tests don't depend on
    /// dictionary iteration order.
    var sortedPairs: [(term: Term, value: Value)] {
        terms.map { ($0, storage[$0.rawValue]!) }
    }
}

// MARK: - Tolerant decoding

/// Wraps a keyed container so a missing or malformed field falls back to a
/// default instead of failing the whole document.
struct TolerantDecoder<K: CodingKey> {
    let container: KeyedDecodingContainer<K>

    init(_ decoder: Decoder, keyedBy: K.Type) throws {
        container = try decoder.container(keyedBy: K.self)
    }

    func get<T: Decodable>(_ key: K, _ fallback: T) -> T {
        ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }

    func optional<T: Decodable>(_ key: K, _ type: T.Type = T.self) -> T? {
        ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil)
    }
}
