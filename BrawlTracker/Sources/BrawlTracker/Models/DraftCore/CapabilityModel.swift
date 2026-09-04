import Foundation

/// How each capability is derived from attributes, traits and draft functions.
///
/// Global and versioned, not season-specific: *what makes something a tank
/// counter* is a conceptual rule, while the numbers it reads are dynamic.
///
/// Data, not code, so the rules stay inspectable and — from a later phase —
/// editable, in keeping with the existing Draft Model screen.
struct CapabilityModel: Codable, Hashable {
    var version: Int
    var rules: TermMap<Capability, CapabilityRule>
    /// How strongly a capability gap between two brawlers scales a matchup's
    /// severity. Direction never comes from here — only magnitude.
    var interactionModulation: Double

    init(version: Int = DraftCoreSchema.version,
         rules: TermMap<Capability, CapabilityRule> = TermMap(),
         interactionModulation: Double = 0.5) {
        self.version = version; self.rules = rules
        self.interactionModulation = interactionModulation
    }

    enum CodingKeys: String, CodingKey { case version, rules, interactionModulation }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        version = d.get(.version, DraftCoreSchema.version)
        rules = d.get(.rules, TermMap())
        interactionModulation = d.get(.interactionModulation, 0.5)
    }
}

/// The recipe for one capability.
///
/// Every input is additive around `baseline`. Nothing here can veto a result:
/// `functionAffinity` shifts a score, it never gates one. A brawler whose
/// attributes justify high tank-countering reaches it whether or not anyone
/// tagged it with the `antiTank` draft function.
struct CapabilityRule: Codable, Hashable {
    /// Value when nothing is known. 0.5 keeps an unresolved capability neutral.
    var baseline: Double
    /// Signed weight per attribute, applied to `(normalized − 0.5)` so an
    /// average attribute moves nothing.
    var attributeWeights: TermMap<AttributeKind, Double>
    /// Flat adjustment when the brawler has the trait.
    var traitAdjustments: TermMap<Trait, Double>
    /// Flat *bonus* when the brawler is expected to do this job. Expresses
    /// intent and improves explanations; it is not a precondition.
    var functionAffinity: TermMap<DraftFunction, Double>
    /// Optional floor/ceiling, defaulting to the full range.
    var minimum: Double
    var maximum: Double
    var rationale: String?

    init(baseline: Double = 0.5,
         attributeWeights: TermMap<AttributeKind, Double> = TermMap(),
         traitAdjustments: TermMap<Trait, Double> = TermMap(),
         functionAffinity: TermMap<DraftFunction, Double> = TermMap(),
         minimum: Double = 0, maximum: Double = 1, rationale: String? = nil) {
        self.baseline = baseline
        self.attributeWeights = attributeWeights
        self.traitAdjustments = traitAdjustments
        self.functionAffinity = functionAffinity
        self.minimum = minimum; self.maximum = maximum
        self.rationale = rationale
    }

    enum CodingKeys: String, CodingKey {
        case baseline, attributeWeights, traitAdjustments, functionAffinity,
             minimum, maximum, rationale
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        baseline = d.get(.baseline, 0.5)
        attributeWeights = d.get(.attributeWeights, TermMap())
        traitAdjustments = d.get(.traitAdjustments, TermMap())
        functionAffinity = d.get(.functionAffinity, TermMap())
        minimum = d.get(.minimum, 0)
        maximum = d.get(.maximum, 1)
        rationale = d.optional(.rationale)
    }
}
