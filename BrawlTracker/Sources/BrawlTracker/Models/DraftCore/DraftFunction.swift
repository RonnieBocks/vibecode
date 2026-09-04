import Foundation

/// Why selecting a brawler is strategically useful — the job a team is buying.
///
/// Deliberately a *set*: the flaw in `DraftClass` was that one enum stood for
/// identity, function, matchup and strength at once.
///
/// **Draft functions are not capability gates.** They express what the brawler
/// is *expected* to do, which weights and explains a capability result — they
/// never prohibit one. A brawler with no `tankAnswer` function whose attributes
/// justify high tank-countering will still resolve it. See
/// `CapabilityRule.functionAffinity`.
///
/// Terminology is kept deliberately non-overlapping with `BrawlerRole` (role
/// `antiTank` versus function `tankAnswer`) so a mis-authored profile is
/// visible on sight.
struct DraftFunction: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    /// Reliably removes high-health frontliners.
    static let tankAnswer   = DraftFunction(rawValue: "tankAnswer")
    /// Protects *teammates* from a diving attacker.
    ///
    /// Requires a stable, active kit mechanism that directly interrupts,
    /// punishes, displaces, disables, denies, or protects against the diver —
    /// crowd control, displacement, peel, protective support, or close-range
    /// area denial. **High personal survivability alone does not qualify.**
    /// Surviving a dive yourself is the `assassinResistance` capability, and
    /// letting it qualify here would leak a dynamic capability into stable
    /// identity. See `diveAnswerMechanisms`.
    static let diveAnswer   = DraftFunction(rawValue: "diveAnswer")
    /// Denies or claims area the enemy needs.
    static let spaceControl = DraftFunction(rawValue: "spaceControl")
    /// Can personally decide a fight or a game given room.
    static let carryThreat  = DraftFunction(rawValue: "carryThreat")

    static let known: [DraftFunction] = [.tankAnswer, .diveAnswer, .spaceControl, .carryThreat]

    /// Traits that constitute an *active* mechanism against a diver.
    ///
    /// Deliberately excludes `shielded`, `selfHealing` and anything else that
    /// only keeps the brawler itself alive — that is personal durability, which
    /// the tightened definition rules out.
    ///
    /// Burst punishment is the one qualifying route with no trait behind it: it
    /// lives in the `burstPotential` capability and can only be checked once
    /// balance data exists, so a profile qualifying that way must say so in
    /// `notes` until Phase 4.
    static let diveAnswerMechanisms: Set<Trait> = [
        .crowdControl,   // interrupt or disable the diver
        .displacement,   // push or pull it off the target
        .teamHealing,    // peel — keep the dived teammate alive
        .summon,         // a body between the diver and its target
        .allyProtection, // mitigate the damage the diver is trying to land
    ]

    /// Whether a profile has an active mechanism justifying `diveAnswer`.
    /// Durability is deliberately not consulted.
    static func qualifiesForDiveAnswer(_ profile: BrawlerProfile) -> Bool {
        !profile.traits.isDisjoint(with: diveAnswerMechanisms)
    }
}
