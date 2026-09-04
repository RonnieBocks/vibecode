import Foundation

/// A persistent mechanical property of a brawler's kit.
///
/// Traits must be **categorical** (present or absent), **mechanical** (not a
/// number), and **non-overlapping**. They are never strength, tier placement,
/// numerical properties, or meta labels — a magnitude belongs in
/// `BalanceState` as an `AttributeKind`.
///
/// Traits are the vocabulary the general interaction model reasons over. Where
/// a specific kit interaction cannot be stated honestly here, it belongs in a
/// `BrawlerMatchupOverride` rather than being forced into a trait.
struct Trait: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    // MARK: Mobility
    /// Can leave a losing fight on demand, repeatably.
    static let escapeMobility  = Trait(rawValue: "escapeMobility")
    /// Can force distance closed on demand.
    static let gapClose        = Trait(rawValue: "gapClose")
    /// Neither a reliable escape nor a gap-closer. Authored explicitly until
    /// interaction rules can express absence.
    static let immobile        = Trait(rawValue: "immobile")

    // MARK: Delivery
    /// The main attack reaches targets without line of sight — arcing over
    /// terrain, or passing through it. The mechanic that matters for matchups
    /// is "can hit me while I am behind cover".
    ///
    /// Not redundant with the `thrower` role, on two grounds:
    /// `TraitInteractionRule` matches on traits only and cannot see a role at
    /// all, so without this the mechanic is inexpressible to the interaction
    /// model; and non-throwers demonstrably have it — Meeple and Squeak shoot
    /// through walls, Janet drops bombs from above.
    static let indirectFire    = Trait(rawValue: "indirectFire")
    /// Slow enough that a mobile target reliably dodges it at range.
    static let slowProjectile  = Trait(rawValue: "slowProjectile")
    /// Passes through *targets* to hit several in a line. Terrain is not this
    /// term's business — bypassing walls is `indirectFire`.
    static let piercing        = Trait(rawValue: "piercing")
    /// Area damage with no reliable single-target finish.
    static let areaOnly        = Trait(rawValue: "areaOnly")
    /// Creates exploitable windows between reloads or shots.
    static let reloadDependent = Trait(rawValue: "reloadDependent")
    /// A commit window *within a single attack*: the attack must be charged or
    /// wound up before it lands, and the brawler is exposed until it does.
    /// Not for anything that persists between attacks.
    /// Roster: Frank, Hank, Angelo, Mandy.
    static let windUp          = Trait(rawValue: "windUp")

    // MARK: State
    /// A persistent, accumulating quantity carried *across* attacks that gates
    /// a significant ability. The brawler is not stronger yet — it will be when
    /// the meter fills, and the opponent can track that.
    /// Roster: Bibi, Melodie, Pearl, Trunk, Vince.
    static let resourceMeter   = Trait(rawValue: "resourceMeter")
    /// Temporarily stronger *right now*, having met a discrete in-combat
    /// trigger such as landing a hit. Lost when the condition lapses.
    /// Assign when the empowerment comes from an event, not from an
    /// accumulating quantity — otherwise it is `resourceMeter`.
    /// Roster: Bea, Pierce, Sam, Mina.
    static let conditionalEmpowerment = Trait(rawValue: "conditionalEmpowerment")
    /// Grows monotonically stronger over the match, usually resetting on death.
    /// Counterplay is tempo — punish it before it scales.
    /// Roster: Surge, Clancy, Vince.
    static let inMatchProgression = Trait(rawValue: "inMatchProgression")
    /// Switches between discrete forms with materially different capabilities,
    /// so the matchup itself changes with the form. Counterplay is
    /// form-dependent rather than time-dependent — which is why this is not the
    /// same concept as `inMatchProgression`.
    /// Roster: Draco, Kaze, Starr Nova, Meg, Bonnie.
    static let formShift       = Trait(rawValue: "formShift")

    // MARK: Resilience
    static let selfHealing     = Trait(rawValue: "selfHealing")
    /// Reduces or absorbs incoming damage — not merely high health.
    static let shielded        = Trait(rawValue: "shielded")
    /// Continues fighting after an apparent death.
    static let secondLife      = Trait(rawValue: "secondLife")
    /// Reduces or prevents enemy healing.
    static let antiHeal        = Trait(rawValue: "antiHeal")

    // MARK: Utility & control
    static let invisibility    = Trait(rawValue: "invisibility")
    /// Destroys terrain as a normal consequence of attacking.
    static let wallBreak       = Trait(rawValue: "wallBreak")
    /// Places a persistent independent entity.
    static let summon          = Trait(rawValue: "summon")
    /// Directly **restricts or impairs an opponent's available agency or
    /// movement** — slows, stuns, roots, freezes, silences, confinement.
    ///
    /// Presence answers only *whether the mechanic exists*. Severity belongs in
    /// `BalanceState` attributes and the capability layer, so a slow and a stun
    /// both carry this trait without being treated as equal.
    ///
    /// **Independent of `displacement`.** Neither trait implies the other:
    /// - a slow restricts without moving anyone → `crowdControl` only
    /// - a knockback moves without restricting → `displacement` only
    /// - a kit doing both, each independently justified, carries both
    static let crowdControl    = Trait(rawValue: "crowdControl")
    /// **Forcibly changes an opponent's position** — knockback, pull, throw.
    ///
    /// **Independent of `crowdControl`.** Being moved is not the same as being
    /// restricted: a knocked-back opponent keeps full control of what it does
    /// next. Assign both only when the kit separately restricts agency as well.
    static let displacement    = Trait(rawValue: "displacement")
    static let teamHealing     = Trait(rawValue: "teamHealing")
    /// Directly protects *another player* from incoming damage — mitigation,
    /// prevention, interception, absorption or redirection applied to an ally.
    ///
    /// Does not qualify: personal durability (`shielded`), standing between an
    /// ally and danger, threatening the attacker, or ordinary healing
    /// (`teamHealing`, which restores after damage rather than preventing it).
    static let allyProtection  = Trait(rawValue: "allyProtection")

    static let known: [Trait] = [
        .escapeMobility, .gapClose, .immobile,
        .indirectFire, .slowProjectile, .piercing, .areaOnly, .reloadDependent, .windUp,
        .resourceMeter, .conditionalEmpowerment, .inMatchProgression, .formShift,
        .selfHealing, .shielded, .secondLife, .antiHeal,
        .invisibility, .wallBreak, .summon, .crowdControl, .displacement, .teamHealing,
        .allyProtection,
    ]
}
