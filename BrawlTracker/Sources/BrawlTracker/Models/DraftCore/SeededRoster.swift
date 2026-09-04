import Foundation

/// The full Phase 1 roster: the ten pilot profiles plus the remaining 99,
/// authored in validated batches.
///
/// Objective game knowledge only. Nothing here records anything about a
/// particular player — see `ArchitectureBoundary`.
enum SeededRoster {
    static var all: [BrawlerProfile] {
        PilotRoster.profiles + batch1 + batch2 + batch3 + batch4 + batch5
    }

    static var set: BrawlerProfileSet { BrawlerProfileSet(profiles: all) }

    /// Compact constructor. Skill is positional in the authored order:
    /// mechanical, aim, positioning, knowledge, variance, mistake punishment.
    static func p(_ name: String, _ id: Int,
                  _ roles: [BrawlerRole],
                  _ pos: Positioning?,
                  _ engage: [EngagePattern],
                  _ fn: Set<DraftFunction>,
                  _ traits: Set<Trait>,
                  _ m: Int, _ a: Int, _ ps: Int, _ k: Int, _ v: Int, _ mp: Int,
                  _ conf: AuthoringMetadata.Confidence = .high,
                  seed: String? = nil,
                  q: [String] = [],
                  forms: [FormOverride] = [],
                  unresolved: AuthoringMetadata.UnresolvedReason? = nil,
                  notes: String? = nil) -> BrawlerProfile {
        var sources = ["brawlapi-tip", "model-knowledge"]
        if let seed { sources.insert("playbook:\(seed)", at: 0) }
        return BrawlerProfile(
            key: BrawlerKey(name, id: id),
            roles: roles, positioning: pos, engagePatterns: engage,
            draftFunctions: fn, traits: traits,
            skill: SkillProfile(mechanicalDifficulty: m, aimDifficulty: a,
                                positioningDifficulty: ps, gameKnowledge: k,
                                variance: v, mistakePunishment: mp),
            forms: forms,
            authoring: AuthoringMetadata(confidence: conf, unresolvedReason: unresolved,
                                         sources: sources, openQuestions: q),
            notes: notes)
    }
}
