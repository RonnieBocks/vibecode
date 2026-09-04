import Foundation

/// Batch 3 — Grom through Meeple.
extension SeededRoster {
    static let batch3: [BrawlerProfile] = [

        p("Grom", 16000048, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile, .slowProjectile],
          2, 4, 4, 3, 3, 5, .high, seed: "thrower"),

        p("Gus", 16000061, [.support, .sniper], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.allyProtection, .immobile],
          3, 3, 3, 3, 3, 3, .high, seed: "sniper",
          notes: "Gap closed: the shield he grants an ally is absorption applied to someone else — allyProtection — and it earns diveAnswer honestly."),

        p("Hank", 16000069, [.tank], .frontline, [.pressure, .dive],
          [.spaceControl, .carryThreat], [.windUp, .areaOnly, .immobile],
          3, 3, 3, 3, 4, 4, .high, seed: "tank",
          notes: "The bubble inflates within one attack and can be released early — a textbook windUp."),

        p("Jacky", 16000034, [.tank], .frontline, [.pressure],
          [.spaceControl, .diveAnswer], [.areaOnly, .displacement, .wallBreak, .immobile],
          2, 1, 3, 2, 3, 3, .high, seed: "tank"),

        p("Jae-Yong", 16000093, [.spaceMaker], .frontline, [.pressure, .dive],
          [.carryThreat], [.selfHealing, .immobile],
          3, 3, 3, 3, 4, 4, .low, seed: "support",
          q: ["Seeded Support, but the tip reads as self-sustain rather than ally healing. If the healing targets teammates, Support belongs first.",
              "\"Speed for aggression\" is a movementSpeed attribute, not gapClose — so no committing tool is recorded and the role may be wrong."]),

        p("Janet", 16000057, [.control], .backline, [.poke, .hold],
          [.spaceControl], [.indirectFire, .escapeMobility],
          3, 4, 4, 3, 3, 4, .medium, seed: "control",
          q: ["Recent enough that indirectFire is read from the Super's described behaviour rather than confirmed on the base attack."],
          notes: "Her Super both bypasses line of sight and removes her from danger — one of the few non-throwers with indirectFire."),

        p("Jessie", 16000007, [.control], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.summon, .piercing, .immobile],
          2, 3, 3, 3, 3, 3, .high, seed: "control",
          q: ["piercing applied to a shot that chains between nearby enemies — same boundary as Belle."]),

        p("Juju", 16000087, [.thrower], .midline, [.poke, .hold],
          [.spaceControl], [.summon, .immobile],
          4, 3, 3, 4, 4, 4, .medium, seed: "thrower",
          q: ["Her attack changes with the terrain she is standing on. Terrain-dependent attacks have no representation — reported as a vocabulary gap.",
              "indirectFire withheld: cannot confirm the base attack ignores line of sight."]),

        p("Kaze", 16000094, [.control], .midline, [.hold],
          [.spaceControl, .carryThreat], [.formShift, .gapClose],
          4, 3, 4, 4, 4, 4, .high, seed: "spaceMaker",
          forms: [FormOverride(name: "Ninja", availability: .superGated, positioning: .frontline,
                               addedRoles: [.assassin], addedEngagePatterns: [.dive],
                               removedEngagePatterns: [.hold],
                               addedFunctions: [.carryThreat],
                               notes: "Strikes rather than zones.")],
          notes: "Base is the geisha: control, midline, hold. The two jobs are now separate states rather than an averaged compromise."),

        p("Kenji", 16000085, [.spaceMaker], .frontline, [.pressure, .dive],
          [.carryThreat], [.selfHealing, .gapClose],
          4, 3, 4, 3, 4, 4, .medium, seed: "spaceMaker",
          q: ["Assassin considered: he commits well but sustains through fights rather than leaving them."]),

        p("Kit", 16000076, [.support], .frontline, [.flank, .dive],
          [.carryThreat, .diveAnswer], [.teamHealing, .gapClose],
          4, 2, 4, 4, 4, 3, .medium, seed: "support",
          q: ["The tip says \"Or Assassinate Enemies\", but the pounce commits without an exit, so Assassin is not independently satisfied. Held to Support for the same reason Fang is held to spaceMaker."]),

        p("Larry & Lawrie", 16000077, [.thrower], .midline, [.poke, .hold],
          [.spaceControl], [.indirectFire, .summon, .areaOnly, .immobile],
          3, 3, 3, 3, 3, 4, .medium, seed: "thrower",
          q: ["Two bodies acting together is close to summon but not the same thing — Lawrie is a duplicate rather than a placed entity. Recorded as summon and flagged."]),

        p("Leon", 16000023, [.assassin], .frontline, [.flank, .dive],
          [.carryThreat], [.invisibility, .escapeMobility],
          3, 3, 4, 4, 5, 5, .high, seed: "control",
          q: ["Seeded Control and overridden without hesitation — the tip is \"Sneak In And Assassinate\" and every criterion is met."]),

        p("Lily", 16000081, [.assassin], .frontline, [.flank, .dive],
          [.carryThreat], [.invisibility, .gapClose, .escapeMobility],
          3, 3, 4, 4, 5, 5, .medium, seed: "spaceMaker",
          q: ["Assassin is confident; the uncertainty is whether her approach is bush-dependent enough that invisibility overstates it."]),

        p("Lola", 16000053, [.control], .midline, [.poke, .hold],
          [.spaceControl], [.summon, .immobile],
          4, 3, 4, 4, 3, 3, .medium, seed: "control",
          q: ["Ego is a persistent placed entity that acts independently, so summon fits — but it mirrors her rather than fighting alone."]),

        p("Lumi", 16000091, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .spaceControl], [.piercing, .reloadDependent, .immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Recall-and-return weapons read like Carl's boomerang; the commitment window is inferred rather than confirmed."]),

        p("Maisie", 16000068, [.antiTank], .midline, [.poke, .hold],
          [.tankAnswer, .diveAnswer], [.displacement, .immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["displacement is inferred from \"punish advancing enemies\" rather than confirmed; if the Super only damages, diveAnswer must come off with it."]),

        p("Mandy", 16000065, [.sniper], .backline, [.hold, .poke],
          [.tankAnswer, .spaceControl], [.windUp, .piercing, .immobile],
          3, 4, 5, 3, 4, 4, .high, seed: "sniper",
          notes: "Standing still to unlock her full range is a commitment window inside the attack — windUp."),

        p("Max", 16000032, [.support], .midline, [.poke, .flank],
          [.spaceControl], [.escapeMobility],
          3, 3, 3, 4, 3, 3, .high, seed: "support",
          q: ["A team-wide speed buff has no trait — the same family of gap as Gray's portals and Gus's shield."]),

        p("Meeple", 16000089, [.control], .backline, [.poke, .hold],
          [.spaceControl], [.indirectFire, .immobile],
          3, 4, 4, 3, 3, 4, .medium, seed: "control",
          q: ["Recent brawler; role and skill ratings rest largely on the tip string."],
          notes: "A non-thrower with indirectFire, and part of the evidence that the trait is independent of the role."),
    ]
}
