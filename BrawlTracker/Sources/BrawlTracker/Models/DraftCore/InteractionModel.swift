import Foundation

/// Resolves how one brawler fares against another.
///
/// Two channels, deliberately not merged:
///
/// - **Trait rules** give broad coverage over the whole roster.
/// - **Explicit overrides** record specific kit interactions the trait
///   vocabulary can't express honestly.
///
/// Resolution order:
///
/// 1. Evaluate the trait rules.
/// 2. Look for an explicit override for this exact pairing.
/// 3. If one exists it **replaces** the verdict outright.
/// 4. The trait-derived result is retained as evidence, marked `superseded`,
///    so an explanation can still say what the general model expected.
///
/// Direction is decided by traits and overrides alone. Capabilities only scale
/// how much the matchup matters.
struct InteractionModel: Codable, Hashable {
    var version: Int
    var traitRules: [TraitInteractionRule]
    var overrides: [BrawlerMatchupOverride]

    init(version: Int = DraftCoreSchema.version,
         traitRules: [TraitInteractionRule] = [],
         overrides: [BrawlerMatchupOverride] = []) {
        self.version = version
        self.traitRules = traitRules
        self.overrides = overrides
    }

    // MARK: - Resolution

    func verdict(for attacker: InteractionParticipant,
                 against defender: InteractionParticipant,
                 model: CapabilityModel,
                 mode: String? = nil, map: String? = nil) -> InteractionVerdict {
        var evidence: [InteractionEvidence] = []

        // 1 — general trait reasoning.
        let trait = traitVerdict(attacker: attacker, defender: defender,
                                 model: model, evidence: &evidence)

        // 2 — explicit pairing.
        guard let override = override(attacker: attacker.profile.key,
                                      defender: defender.profile.key,
                                      mode: mode, map: map) else {
            return trait
        }

        // 3 — the override replaces the verdict; 4 — trait evidence is kept.
        evidence = evidence.map {
            var e = $0; e.superseded = true; return e
        }
        let magnitude = modulate(override.magnitude, rule: nil,
                                 attacker: attacker, defender: defender, model: model)
        evidence.append(InteractionEvidence(
            source: .explicitOverride, polarity: override.polarity, magnitude: magnitude,
            rationale: override.rationale.isEmpty
                ? "Explicit matchup entry for \(attacker.profile.key) vs \(defender.profile.key)"
                : override.rationale,
            superseded: false))
        return InteractionVerdict(polarity: override.polarity, magnitude: magnitude,
                                  decidedBy: .explicitOverride, evidence: evidence)
    }

    /// The general model's answer on its own — useful for showing what an
    /// override departed from.
    func traitVerdict(attacker: InteractionParticipant, defender: InteractionParticipant,
                      model: CapabilityModel) -> InteractionVerdict {
        var evidence: [InteractionEvidence] = []
        return traitVerdict(attacker: attacker, defender: defender, model: model, evidence: &evidence)
    }

    func override(attacker: BrawlerKey, defender: BrawlerKey,
                  mode: String? = nil, map: String? = nil) -> BrawlerMatchupOverride? {
        let matching = overrides.filter {
            $0.attacker == attacker && $0.defender == defender
                && ($0.scope?.matches(mode: mode, map: map) ?? true)
        }
        // A scoped entry is more specific than an unscoped one, so it wins.
        return matching.first { $0.scope != nil } ?? matching.first
    }

    // MARK: - Internals

    private func traitVerdict(attacker: InteractionParticipant, defender: InteractionParticipant,
                              model: CapabilityModel,
                              evidence: inout [InteractionEvidence]) -> InteractionVerdict {
        let matches = traitRules.filter { $0.applies(attacker: attacker.profile, defender: defender.profile) }
        guard !matches.isEmpty else { return .neutral }

        // Sum severity per direction, then let the stronger side decide. Summing
        // within a direction lets several small reasons add up; taking the net
        // keeps opposing reasons from silently cancelling into a false neutral.
        var advantage = 0.0, disadvantage = 0.0
        for rule in matches {
            let m = modulate(rule.magnitude, rule: rule, attacker: attacker,
                             defender: defender, model: model)
            switch rule.polarity {
            case .advantage: advantage += m
            case .disadvantage: disadvantage += m
            case .neutral: break
            }
            evidence.append(InteractionEvidence(source: .traitRules, polarity: rule.polarity,
                                                magnitude: m, rationale: rule.rationale,
                                                superseded: false))
        }

        let net = advantage - disadvantage
        let polarity: InteractionPolarity = net > 0 ? .advantage : net < 0 ? .disadvantage : .neutral
        return InteractionVerdict(polarity: polarity, magnitude: min(1, abs(net)),
                                  decidedBy: .traitRules, evidence: evidence)
    }

    /// Capabilities scale severity, never direction. A rule naming a
    /// `magnitudeCapability` is amplified when the attacker leads on it and
    /// damped when the defender does.
    private func modulate(_ magnitude: Double, rule: TraitInteractionRule?,
                          attacker: InteractionParticipant, defender: InteractionParticipant,
                          model: CapabilityModel) -> Double {
        guard let capability = rule?.magnitudeCapability,
              let a = attacker.capabilities, let d = defender.capabilities else {
            return min(1, max(0, magnitude))
        }
        let delta = a.value(capability) - d.value(capability)     // −1…1
        return min(1, max(0, magnitude * (1 + delta * model.interactionModulation)))
    }

    enum CodingKeys: String, CodingKey { case version, traitRules, overrides }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        version = d.get(.version, DraftCoreSchema.version)
        traitRules = d.get(.traitRules, [])
        overrides = d.get(.overrides, [])
    }
}
