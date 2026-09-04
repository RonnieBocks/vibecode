import Foundation

/// The Phase 1 pilot: ten hand-authored profiles chosen from a coverage matrix
/// to stress the controlled vocabulary before the remaining 99 are seeded.
///
/// Not wired into any production flow — nothing outside DraftCore reads this.
/// It exists so the vocabulary can be corrected against hard cases first.
///
/// Authored from base kit and Super only (authoring law 3). Where a mechanic
/// comes from a gadget or star power it is left out and recorded as an open
/// question instead (law 4: omission beats invention).
///
/// Law 5, learned the hard way here: **a short descriptive source such as a
/// BrawlAPI tip string is corroborating evidence, not an exhaustive mechanical
/// specification.** Berry's tip omits that his attack arcs, and deleting
/// `indirectFire` on that basis treated absence of evidence as evidence of
/// absence. Role and trait decisions about fundamental kit mechanics need
/// complete ability evidence wherever the tip is incomplete or ambiguous.
enum PilotRoster {

    static let profiles: [BrawlerProfile] = [
        lou, crow, edgar, bibi, frank, bea, tick, berry, surge, bolt,
    ]

    static var set: BrawlerProfileSet { BrawlerProfileSet(profiles: profiles) }

    // MARK: - 01 · Lou — multi-role ordering

    static let lou = BrawlerProfile(
        key: BrawlerKey("Lou", id: 16000045),
        roles: [.control, .antiTank],
        positioning: .midline,
        engagePatterns: [.poke, .hold],
        draftFunctions: [.tankAnswer, .spaceControl, .diveAnswer],
        traits: [.areaOnly, .crowdControl, .immobile],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 2,
                            positioningDifficulty: 3, gameKnowledge: 3,
                            variance: 2, mistakePunishment: 3,
                            note: "Freeze meter rewards sustained fire but forgives individual misses."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:antiTank", "brawlapi-tip:Control The Map With A Huge Freeze.",
                      "brawlapi-items:Supercool/Hypothermia/Ice Block/Cryo Syrup", "match-log"]),
        notes: """
            Order resolved to control › antiTank. Every piece of kit evidence is \
            freeze or slow, and he meets the Control criteria squarely (wide \
            attack, crowd control, forces routes) while failing Anti-Tank's \
            "no narrower home" clause. The seed's Anti-Tank label survives \
            intact as the tankAnswer *function* — which is what the playbook \
            always meant by it.
            """)

    // MARK: - 02 · Crow — ambiguous classification across the new split

    static let crow = BrawlerProfile(
        key: BrawlerKey("Crow", id: 16000024),
        roles: [.assassin],
        positioning: .midline,
        engagePatterns: [.poke, .flank, .dive],
        draftFunctions: [.tankAnswer, .carryThreat],
        traits: [.escapeMobility, .gapClose, .antiHeal],
        skill: SkillProfile(mechanicalDifficulty: 3, aimDifficulty: 3,
                            positioningDifficulty: 4, gameKnowledge: 3,
                            variance: 3, mistakePunishment: 4),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:antiTank (seed, superseded)", "brawlapi-tip:Poison Enemies From A Distance.",
                      "kit-evidence:bidirectional Super, healing denial", "match-log"],
            openQuestions: [
                "Control was tested as a secondary and did not independently qualify — see notes. Left as a single role rather than assigned on preference.",
            ]),
        notes: """
            Assassin primary under the widened definition. The full pattern is \
            present: poke with daggers, deny sustain with poison to create a \
            kill threshold, commit with the Super, secure, then leave. My \
            earlier rejection tested for burst-on-entry, which was the \
            definition being too narrow rather than Crow failing it.

            Anti-Tank dropped as a role: the seed's meaning was always "he is \
            who you pick to answer tanks", which is the tankAnswer *function* \
            he still carries. Control tested and failed — poison is a \
            damage-over-time debuff, not area denial; it neither forces routes \
            nor restricts where enemies may stand.
            """)

    // MARK: - 03 · Edgar — interaction direction

    static let edgar = BrawlerProfile(
        key: BrawlerKey("Edgar", id: 16000060),
        roles: [.assassin],
        positioning: .frontline,
        engagePatterns: [.dive],
        draftFunctions: [.carryThreat],
        traits: [.escapeMobility, .gapClose, .selfHealing],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 2,
                            positioningDifficulty: 4, gameKnowledge: 3,
                            variance: 5, mistakePunishment: 5,
                            note: "Trivial to execute, brutal to judge — the whole difficulty is choosing when to jump."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:spaceMaker", "brawlapi-tip:Jump To Take Out Isolated Enemies.", "match-log"]),
        notes: "Moved from the seeded Space Maker bucket to Assassin: he chooses when contact happens and can leave, which is exactly the dividing line.")

    // MARK: - 04 · Bibi — the assassin boundary, from the other side

    static let bibi = BrawlerProfile(
        key: BrawlerKey("Bibi", id: 16000038),
        roles: [.spaceMaker],
        positioning: .frontline,
        engagePatterns: [.pressure],
        draftFunctions: [.spaceControl, .diveAnswer],
        traits: [.displacement, .resourceMeter, .immobile],
        skill: SkillProfile(mechanicalDifficulty: 3, aimDifficulty: 3,
                            positioningDifficulty: 3, gameKnowledge: 2,
                            variance: 3, mistakePunishment: 3),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:spaceMaker", "model-knowledge"]),
        notes: "Stays Space Maker: the home-run bar is a charge-up, and the Super knocks back rather than closing distance. She can walk into a fight but has no tool to leave one — the criterion that separates Space Maker from Assassin.")

    // MARK: - 05 · Frank — low-aim / high-punishment extreme

    static let frank = BrawlerProfile(
        key: BrawlerKey("Frank", id: 16000029),
        roles: [.tank],
        positioning: .frontline,
        engagePatterns: [.pressure, .hold],
        draftFunctions: [.diveAnswer, .spaceControl],
        traits: [.windUp, .crowdControl, .immobile, .wallBreak],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 1,
                            positioningDifficulty: 3, gameKnowledge: 2,
                            variance: 2, mistakePunishment: 4,
                            note: "Almost no aim demand; the cost sits entirely in mistiming the wind-up."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:tank", "brawlapi-tip:Control Space With Stuns And High Health."]),
        notes: "Anchors the low end of the aim scale, opposite Bea.")

    // MARK: - 06 · Bea — high-aim extreme and a within-match state change

    static let bea = BrawlerProfile(
        key: BrawlerKey("Bea", id: 16000047),
        roles: [.sniper],
        positioning: .backline,
        engagePatterns: [.poke],
        draftFunctions: [.tankAnswer],
        traits: [.conditionalEmpowerment, .reloadDependent, .immobile],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 5,
                            positioningDifficulty: 4, gameKnowledge: 3,
                            variance: 4, mistakePunishment: 4,
                            note: "A miss forfeits the engagement and the charged shot with it."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:sniper", "model-knowledge"]),
        notes: "Her supercharged shot is a within-match state change, milder than Surge's and useful as a comparison case.")

    // MARK: - 07 · Tick — trait absence

    static let tick = BrawlerProfile(
        key: BrawlerKey("Tick", id: 16000035),
        roles: [.thrower],
        positioning: .backline,
        engagePatterns: [.hold, .poke],
        draftFunctions: [.spaceControl],
        traits: [.indirectFire, .areaOnly, .immobile, .summon, .slowProjectile],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 2,
                            positioningDifficulty: 4, gameKnowledge: 3,
                            variance: 3, mistakePunishment: 5,
                            note: "Being reached at all is usually fatal."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:thrower", "brawlapi-tip:Deny Space By Throwing Fiery Bottles."]),
        notes: "The clearest immobile case: with no way to express absence in a rule, this has to be stated explicitly or Tick becomes invisible to every dive matchup. Super is a seeking head, which is a persistent entity — summon, not a temporary hazard.")

    // MARK: - 08 · Berry — distant multi-role

    static let berry = BrawlerProfile(
        key: BrawlerKey("Berry", id: 16000083),
        roles: [.support, .thrower, .control],
        positioning: .midline,
        engagePatterns: [.poke, .hold],
        draftFunctions: [.spaceControl, .diveAnswer],
        traits: [.teamHealing, .selfHealing, .indirectFire, .areaOnly, .immobile],
        skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 3,
                            positioningDifficulty: 3, gameKnowledge: 3,
                            variance: 3, mistakePunishment: 3),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:thrower", "brawlapi-tip:Control Space And Heal Teammates.",
                      "brawlapi-items:Floor Is Fine/Making A Mess", "kit-evidence:arcing attack confirmed"]),
        notes: """
            indirectFire restored, and the withdrawal was my error: the tip \
            omits the arc, and I read that omission as evidence of absence \
            (law 5). Three roles, the pilot's first — each independently \
            satisfied: Support (healing targets allies, much weaker alone), \
            Thrower (attack arcs over terrain), Control (puddles are persistent \
            hazards that deny ground; the tip says "Control Space" outright).
            """)

    // MARK: - 09 · Surge — identity under kit transformation

    static let surge = BrawlerProfile(
        key: BrawlerKey("Surge", id: 16000043),
        roles: [.antiTank],
        positioning: .midline,
        engagePatterns: [.pressure, .poke],
        draftFunctions: [.tankAnswer, .carryThreat],
        traits: [.immobile, .inMatchProgression],
        skill: SkillProfile(mechanicalDifficulty: 3, aimDifficulty: 3,
                            positioningDifficulty: 3, gameKnowledge: 4,
                            variance: 5, mistakePunishment: 4,
                            note: "Dying resets the upgrades, so one mistake costs the whole investment."),
        authoring: AuthoringMetadata(
            confidence: .high,
            sources: ["playbook:antiTank", "brawlapi-tip:Use Supers To Level Up Or Dive In"],
            ),
        notes: "Identity held stable as required: he is an Anti-Tank at every stage. The level-up changes his numbers, so it belongs in BalanceState — but no current trait marks that the numbers change *within* a match. Immobile is correct for the base kit; his jump is a gadget and is excluded by law 3.")

    // MARK: - 10 · Bolt — the low-confidence path

    static let bolt = BrawlerProfile(
        key: BrawlerKey("Bolt", id: 16000104),
        roles: [],
        positioning: nil,
        engagePatterns: [],
        draftFunctions: [],
        traits: [.gapClose],
        skill: SkillProfile(),
        authoring: AuthoringMetadata(
            confidence: .low,
            unresolvedReason: .classificationBoundary,
            sources: ["match-log:10 appearances", "brawlapi-tip:Avoid Walls And Sharp Turns For Speed",
                      "brawlapi-description:rolls into things at speed"],
            openQuestions: [
                "Role still unset: spaceMaker and assassin both fit a fast close-range roller, and the deciding question — can he reliably disengage? — is not answerable from the available evidence.",
                "Positioning, engage patterns and functions remain unset.",
                "Skill profile is at the neutral default and is not an authored judgement.",
            ]),
        notes: """
            Still deliberately minimal, but no longer blank: the description \
            ("designed to deal damage by rolling into things", "reaches \
            dangerous speeds") is direct evidence for gapClose, so that one \
            trait is now authored. Everything else stays unset and neutral.
            """)
}
