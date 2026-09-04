import Foundation

/// Turns (identity + current attributes) into derived capabilities.
///
/// Pure and deterministic: same inputs, same output, no stored state. That is
/// the same discipline `DraftLearning` follows — nothing is persisted, so there
/// is no trained artefact to go stale when a patch lands.
///
/// Resolution for one capability:
///
///     value = baseline
///           + Σ (normalizedAttribute − 0.5) × attributeWeight
///           + Σ traitAdjustment      for each trait the brawler has
///           + Σ functionAffinity     for each expected draft function
///     value = clamp(value, minimum, maximum)
///
/// Attributes are centred on 0.5, so an average brawler with no traits lands on
/// the baseline. Draft functions add; they never gate.
enum CapabilityResolver {

    static func resolve(profile: BrawlerProfile,
                        attributes: BrawlerAttributes?,
                        model: CapabilityModel,
                        anchors: AttributeAnchors,
                        balanceVersion: String) -> CapabilitySet {
        var scores = TermMap<Capability, CapabilityScore>()
        for (capability, rule) in model.rules.sortedPairs {
            scores[capability] = score(capability: capability, rule: rule,
                                       profile: profile, attributes: attributes,
                                       anchors: anchors)
        }
        return CapabilitySet(key: profile.key, balanceVersion: balanceVersion,
                             modelVersion: model.version, scores: scores)
    }

    /// Resolves the whole roster. Brawlers with no attributes still resolve —
    /// every attribute term simply contributes nothing and confidence is 0.
    static func resolveAll(profiles: BrawlerProfileSet,
                           balance: BalanceState,
                           model: CapabilityModel) -> [BrawlerKey: CapabilitySet] {
        var out: [BrawlerKey: CapabilitySet] = [:]
        for profile in profiles.profiles {
            out[profile.key] = resolve(profile: profile,
                                       attributes: balance.attributes(for: profile.key),
                                       model: model, anchors: balance.anchors,
                                       balanceVersion: balance.version)
        }
        return out
    }

    // MARK: - One capability

    private static func score(capability: Capability, rule: CapabilityRule,
                              profile: BrawlerProfile, attributes: BrawlerAttributes?,
                              anchors: AttributeAnchors) -> CapabilityScore {
        var value = rule.baseline
        var parts: [CapabilityScore.Contribution] = []
        if rule.baseline != 0 {
            parts.append(.init(label: "Baseline", amount: rule.baseline))
        }

        // Attributes — the dynamic half. Centred so average moves nothing.
        var weightTotal = 0.0, weightWithData = 0.0
        for (kind, weight) in rule.attributeWeights.sortedPairs where weight != 0 {
            weightTotal += abs(weight)
            guard let resolved = attributes?[kind]?.resolve(kind, anchors: anchors) else { continue }
            weightWithData += abs(weight)
            let amount = (resolved.value - 0.5) * weight
            value += amount
            if amount != 0 {
                parts.append(.init(label: "\(kind.displayName) \(bandLabel(resolved.value))",
                                   amount: amount))
            }
        }

        // Traits — the stable half.
        for (trait, adjustment) in rule.traitAdjustments.sortedPairs
        where adjustment != 0 && profile.has(trait) {
            value += adjustment
            parts.append(.init(label: trait.displayName, amount: adjustment))
        }

        // Draft functions — an affinity bonus only. Absence contributes 0, so a
        // brawler without the expected function can still reach a high score
        // on its attributes alone.
        for (function, affinity) in rule.functionAffinity.sortedPairs
        where affinity != 0 && profile.performs(function) {
            value += affinity
            parts.append(.init(label: "Expected to \(function.displayName.lowercased())",
                               amount: affinity))
        }

        let clamped = min(rule.maximum, max(rule.minimum, value))
        let confidence = weightTotal > 0 ? weightWithData / weightTotal : 0
        return CapabilityScore(value: clamped, confidence: confidence, contributions: parts)
    }

    /// Coarse label for a normalized value, so explanations read in words
    /// rather than decimals.
    private static func bandLabel(_ v: Double) -> String {
        switch v {
        case ..<0.09:  return "very low"
        case ..<0.25:  return "low"
        case ..<0.42:  return "below average"
        case ..<0.59:  return "average"
        case ..<0.75:  return "above average"
        case ..<0.92:  return "high"
        default:       return "very high"
        }
    }
}
