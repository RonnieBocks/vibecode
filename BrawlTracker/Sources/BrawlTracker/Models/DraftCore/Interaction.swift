import Foundation

/// Which way a matchup leans, always stated from the first brawler's side.
enum InteractionPolarity: String, Codable, CaseIterable {
    case advantage
    case disadvantage
    case neutral

    var inverted: InteractionPolarity {
        switch self {
        case .advantage: return .disadvantage
        case .disadvantage: return .advantage
        case .neutral: return .neutral
        }
    }

    /// +1 / −1 / 0, for arithmetic.
    var sign: Double {
        switch self {
        case .advantage: return 1
        case .disadvantage: return -1
        case .neutral: return 0
        }
    }
}

/// What produced a verdict.
enum InteractionSource: String, Codable, CaseIterable {
    case traitRules
    case explicitOverride
    case none
}

/// A general rule over the trait vocabulary — broad reasoning that generalises
/// across the roster.
struct TraitInteractionRule: Codable, Hashable, Identifiable {
    var id: String
    /// All of these must be present on the first brawler.
    var attackerTraits: Set<Trait>
    /// All of these must be present on the second.
    var defenderTraits: Set<Trait>
    var polarity: InteractionPolarity
    /// 0…1 base severity, before any capability modulation.
    var magnitude: Double
    /// Optional capability whose gap between the two scales severity. Direction
    /// never comes from a capability — only how much the matchup matters.
    var magnitudeCapability: Capability?
    var rationale: String

    init(id: String, attackerTraits: Set<Trait>, defenderTraits: Set<Trait>,
         polarity: InteractionPolarity, magnitude: Double,
         magnitudeCapability: Capability? = nil, rationale: String = "") {
        self.id = id
        self.attackerTraits = attackerTraits
        self.defenderTraits = defenderTraits
        self.polarity = polarity
        self.magnitude = magnitude
        self.magnitudeCapability = magnitudeCapability
        self.rationale = rationale
    }

    func applies(attacker: BrawlerProfile, defender: BrawlerProfile) -> Bool {
        attackerTraits.isSubset(of: attacker.traits) && defenderTraits.isSubset(of: defender.traits)
    }

    enum CodingKeys: String, CodingKey {
        case id, attackerTraits, defenderTraits, polarity, magnitude, magnitudeCapability, rationale
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        id = d.get(.id, UUID().uuidString)
        attackerTraits = d.get(.attackerTraits, [])
        defenderTraits = d.get(.defenderTraits, [])
        polarity = d.get(.polarity, .neutral)
        magnitude = d.get(.magnitude, 0)
        magnitudeCapability = d.optional(.magnitudeCapability)
        rationale = d.get(.rationale, "")
    }
}

/// An explicit statement about one specific pairing.
///
/// Exists so a real kit interaction that the trait vocabulary can't express
/// honestly is recorded as itself, rather than by bending the general model
/// until it happens to produce the right answer for one pair.
struct BrawlerMatchupOverride: Codable, Hashable, Identifiable {
    var attacker: BrawlerKey
    var defender: BrawlerKey
    var polarity: InteractionPolarity
    var magnitude: Double
    var rationale: String
    /// Optional narrowing to a mode or map. Unused in Phase 0; present so a
    /// map-specific interaction doesn't need a schema change later.
    var scope: InteractionScope?

    var id: String { "\(attacker.normalized)>\(defender.normalized)|\(scope?.id ?? "*")" }

    init(attacker: BrawlerKey, defender: BrawlerKey, polarity: InteractionPolarity,
         magnitude: Double, rationale: String = "", scope: InteractionScope? = nil) {
        self.attacker = attacker; self.defender = defender
        self.polarity = polarity; self.magnitude = magnitude
        self.rationale = rationale; self.scope = scope
    }

    enum CodingKeys: String, CodingKey {
        case attacker, defender, polarity, magnitude, rationale, scope
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        attacker = d.get(.attacker, BrawlerKey(normalized: ""))
        defender = d.get(.defender, BrawlerKey(normalized: ""))
        polarity = d.get(.polarity, .neutral)
        magnitude = d.get(.magnitude, 0)
        rationale = d.get(.rationale, "")
        scope = d.optional(.scope)
    }
}

/// Narrows an interaction to a context. `nil` fields mean "any".
struct InteractionScope: Codable, Hashable {
    var mode: String?
    var map: String?

    var id: String { "\(mode ?? "*")/\(map ?? "*")" }

    func matches(mode: String?, map: String?) -> Bool {
        if let m = self.mode, DraftPlaybook.normalizeMode(m) != DraftPlaybook.normalizeMode(mode ?? "") { return false }
        if let mp = self.map, BrawlerArt.normalize(mp) != BrawlerArt.normalize(map ?? "") { return false }
        return true
    }

    enum CodingKeys: String, CodingKey { case mode, map }
    init(mode: String? = nil, map: String? = nil) { self.mode = mode; self.map = map }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        mode = d.optional(.mode); map = d.optional(.map)
    }
}

/// One line of reasoning behind a verdict. Superseded evidence is retained so
/// the UI can say what the general model expected before an override replaced it.
struct InteractionEvidence: Codable, Hashable {
    var source: InteractionSource
    var polarity: InteractionPolarity
    var magnitude: Double
    var rationale: String
    /// True when a later step replaced this as the final answer.
    var superseded: Bool
}

/// The resolved matchup.
struct InteractionVerdict: Codable, Hashable {
    var polarity: InteractionPolarity
    /// 0…1 after capability modulation.
    var magnitude: Double
    var decidedBy: InteractionSource
    var evidence: [InteractionEvidence]

    /// Signed severity, −1…1 — convenient for scoring.
    var signed: Double { polarity.sign * magnitude }

    static let neutral = InteractionVerdict(polarity: .neutral, magnitude: 0,
                                            decidedBy: .none, evidence: [])
}

/// Everything known about one side of a matchup.
///
/// Mirrors the conceptual inputs: identity plus derived capabilities, for each
/// brawler. Capabilities are optional so the model stays usable before any
/// balance data exists.
struct InteractionParticipant {
    var profile: BrawlerProfile
    var capabilities: CapabilitySet?

    init(profile: BrawlerProfile, capabilities: CapabilitySet? = nil) {
        self.profile = profile; self.capabilities = capabilities
    }
}
