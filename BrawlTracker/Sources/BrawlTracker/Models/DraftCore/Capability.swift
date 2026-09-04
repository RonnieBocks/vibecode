import Foundation

/// A higher-level drafting concept the engine reasons with.
///
/// Capabilities are **always derived**, never authored: they are a function of
/// (identity + current attributes + kit traits), so recording a patch means
/// editing attributes and letting these recompute. Open vocabulary.
struct Capability: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    static let burstPotential      = Capability(rawValue: "burstPotential")
    static let sustainedDamage     = Capability(rawValue: "sustainedDamage")
    static let tankCountering      = Capability(rawValue: "tankCountering")
    static let assassinResistance  = Capability(rawValue: "assassinResistance")
    static let survivability       = Capability(rawValue: "survivability")
    static let areaControl         = Capability(rawValue: "areaControl")
    static let laneControl         = Capability(rawValue: "laneControl")
    static let objectivePressure   = Capability(rawValue: "objectivePressure")

    static let known: [Capability] = [
        .burstPotential, .sustainedDamage, .tankCountering, .assassinResistance,
        .survivability, .areaControl, .laneControl, .objectivePressure,
    ]
}

/// One capability's resolved value, with the arithmetic that produced it.
///
/// `contributions` mirrors the labelled-parts shape `DraftEngine` already uses
/// for its explanations, so the existing transparency UI pattern carries over
/// unchanged.
struct CapabilityScore: Codable, Hashable {
    struct Contribution: Codable, Hashable {
        var label: String
        var amount: Double
    }

    /// 0…1.
    var value: Double
    /// 0…1 — share of the rule's attribute weight that had real data behind it.
    var confidence: Double
    var contributions: [Contribution]

    init(value: Double, confidence: Double, contributions: [Contribution] = []) {
        self.value = value; self.confidence = confidence; self.contributions = contributions
    }

    /// A capability with no evidence: neutral, and honest about it.
    static let unresolved = CapabilityScore(value: 0.5, confidence: 0)
}

/// Every capability resolved for one brawler at one balance state.
struct CapabilitySet: Codable, Hashable {
    var key: BrawlerKey
    /// Which `BalanceState` produced these — resolved values are only
    /// meaningful next to the numbers they came from.
    var balanceVersion: String
    var modelVersion: Int
    var scores: TermMap<Capability, CapabilityScore>

    init(key: BrawlerKey, balanceVersion: String, modelVersion: Int,
         scores: TermMap<Capability, CapabilityScore> = TermMap()) {
        self.key = key; self.balanceVersion = balanceVersion
        self.modelVersion = modelVersion; self.scores = scores
    }

    subscript(capability: Capability) -> CapabilityScore {
        scores[capability] ?? .unresolved
    }

    func value(_ capability: Capability) -> Double { self[capability].value }

    enum CodingKeys: String, CodingKey { case key, balanceVersion, modelVersion, scores }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        key = d.get(.key, BrawlerKey(normalized: ""))
        balanceVersion = d.get(.balanceVersion, "unknown")
        modelVersion = d.get(.modelVersion, DraftCoreSchema.version)
        scores = d.get(.scores, TermMap())
    }
}
