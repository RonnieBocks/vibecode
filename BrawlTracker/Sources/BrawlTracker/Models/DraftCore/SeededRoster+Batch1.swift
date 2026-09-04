import Foundation

/// Batch 1 — 8-Bit through Clancy.
extension SeededRoster {
    static let batch1: [BrawlerProfile] = [

        p("8-Bit", 16000027, [.antiTank, .support], .backline, [.hold, .poke],
          [.tankAnswer], [.immobile],
          2, 3, 4, 2, 3, 4, .high, seed: "antiTank",
          notes: "Support is independently satisfied: the damage booster is a core mechanic that targets allies."),

        p("Alli", 16000095, [.spaceMaker], .frontline, [.flank],
          [.carryThreat], [.gapClose],
          3, 3, 4, 3, 4, 4, .low, seed: "spaceMaker",
          q: ["Cannot confirm whether she reliably disengages after committing — that decides spaceMaker versus assassin.",
              "Water traversal has no representation; left unrecorded rather than forced."]),

        p("Amber", 16000040, [.control], .midline, [.pressure, .hold],
          [.spaceControl], [.areaOnly, .wallBreak, .immobile, .resourceMeter],
          3, 2, 3, 3, 3, 3, .high, seed: "control",
          notes: "Fuel is a persistent accumulating quantity gating her output — resourceMeter, not windUp."),

        p("Angelo", 16000079, [.sniper], .backline, [.poke],
          [.tankAnswer], [.windUp, .immobile],
          3, 4, 4, 3, 3, 4, .high, seed: "sniper"),

        p("Ash", 16000051, [.tank], .frontline, [.pressure],
          [.spaceControl], [.summon, .immobile, .resourceMeter],
          2, 2, 3, 2, 3, 3, .high, seed: "tank",
          notes: "Rage builds from damage taken and dealt — an accumulating meter, not a per-attack wind-up."),

        p("Barley", 16000006, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile, .slowProjectile],
          2, 3, 4, 3, 3, 5, .high, seed: "thrower"),

        p("Belle", 16000046, [.sniper], .backline, [.poke],
          [.tankAnswer, .carryThreat], [.piercing, .immobile],
          3, 4, 4, 3, 3, 4, .high, seed: "sniper",
          q: ["piercing applied to chaining shots that bounce between adjacent enemies rather than passing through a line — a definition-boundary case.",
              "WATCHLIST — enemy-applied debuff: her Super marks a target so it takes extra damage. Deliberately not a controlled trait; revisit only if a rule needs it (shared with R-T)."]),

        p("Bo", 16000014, [.control], .midline, [.hold, .poke],
          [.spaceControl, .diveAnswer], [.crowdControl, .immobile],
          3, 3, 3, 3, 2, 3, .high, seed: "control",
          q: ["Mines are placed persistent hazards but do not act, so summon was withheld — boundary between summon and a placed hazard."]),

        p("Bonnie", 16000058, [.sniper], .backline, [.poke, .dive],
          [.carryThreat, .tankAnswer], [.formShift, .gapClose],
          4, 4, 4, 4, 4, 4, .high, seed: "control",
          forms: [FormOverride(name: "Out of cannon", availability: .superGated, positioning: .frontline,
                               addedRoles: [.spaceMaker], addedEngagePatterns: [.pressure],
                               removedEngagePatterns: [.poke],
                               notes: "Launched out, she brawls at close range.")],
          notes: "Base is the cannon: sniper, backline, poke. The compromise positioning is gone — each state is now stated rather than averaged."),

        p("Brock", 16000003, [.sniper], .backline, [.poke],
          [.tankAnswer, .spaceControl], [.immobile, .wallBreak],
          2, 4, 4, 2, 3, 4, .high, seed: "sniper"),

        p("Bull", 16000002, [.spaceMaker, .tank], .frontline, [.dive, .pressure],
          [.carryThreat, .spaceControl], [.gapClose, .wallBreak],
          2, 2, 3, 2, 4, 4, .medium, seed: "spaceMaker",
          q: ["spaceMaker versus tank ordering is close: he has the health to anchor but wins by charging in. Ordered on how he is played rather than on health alone."]),

        p("Buster", 16000062, [.tank, .support], .frontline, [.pressure, .hold],
          [.spaceControl, .diveAnswer], [.shielded, .allyProtection, .immobile],
          3, 2, 4, 3, 3, 4, .high, seed: "tank",
          notes: "Gap closed: the projectile-reflecting barrier is interception applied to allies, which is exactly allyProtection — and it qualifies him for diveAnswer. shielded stays for his own durability; the two are distinct."),

        p("Buzz", 16000049, [.assassin, .spaceMaker], .frontline, [.dive],
          [.carryThreat, .diveAnswer], [.gapClose, .crowdControl],
          3, 3, 4, 3, 4, 4, .medium, seed: "spaceMaker",
          q: ["Assassin primary rests on the grapple as a committing tool; his exit is unreliable, which is the one criterion he only partly meets."]),

        p("Buzz Lightyear", 16000088, [], nil, [], [], [],
          3, 3, 3, 3, 3, 3, .low,
          q: ["No evidence of any kind: BrawlAPI carries no tip, and there is no playbook seed."],
          unresolved: .gameContextExclusion,
          notes: "Promo brawler, hidden from ranked by default. Excluded by context rather than unresolved by evidence."),

        p("Byron", 16000042, [.support, .sniper], .backline, [.poke],
          [.carryThreat, .tankAnswer], [.teamHealing, .antiHeal, .immobile],
          3, 4, 4, 4, 3, 4, .high, seed: "sniper",
          notes: "Both roles independently satisfied — healing targets allies, and the range and single-target damage are a sniper's."),

        p("Carl", 16000025, [.spaceMaker], .midline, [.pressure, .poke],
          [.spaceControl, .tankAnswer], [.piercing, .gapClose, .reloadDependent],
          3, 3, 3, 3, 3, 3, .high, seed: "spaceMaker",
          notes: "Waiting for the pickaxe to return is a genuine window between attacks — reloadDependent, not windUp."),

        p("Charlie", 16000074, [.control], .midline, [.poke, .pressure],
          [.spaceControl, .diveAnswer], [.crowdControl, .immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Seeded Anti-Tank and overridden: the cocoon removes a target from play, which is crowd control, and her damage does not scale into bulk."]),

        p("Chester", 16000063, [.antiTank], .midline, [.pressure, .poke],
          [.tankAnswer, .carryThreat], [.crowdControl, .immobile],
          3, 3, 3, 4, 4, 3, .medium, seed: "antiTank",
          q: ["The cycling Super is now represented structurally as alternating states rather than needing a new trait, but the model cannot express that the rotation is *forced* rather than chosen."],
          forms: [FormOverride(name: "Stun Super", availability: .conditional, addedTraits: [.crowdControl],
                               notes: "One entry in his Super rotation stuns."),
                  FormOverride(name: "Damage Super", availability: .conditional, addedFunctions: [.carryThreat],
                               notes: "Another entry is pure burst.")],
          notes: "crowdControl applies under the broadened definition — a stun is in his base Super rotation."),

        p("Chuck", 16000073, [.spaceMaker], .frontline, [.pressure, .flank],
          [.spaceControl, .carryThreat], [.gapClose, .escapeMobility, .summon],
          4, 2, 4, 4, 4, 4, .medium, seed: "spaceMaker",
          q: ["Posts are placed persistent entities that he travels between; summon is the closest fit but they do not fight."]),

        p("Clancy", 16000083, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .carryThreat], [.inMatchProgression, .resourceMeter, .immobile],
          3, 3, 3, 4, 5, 4, .high, seed: "antiTank",
          notes: "Tokens accumulate (resourceMeter) and convert into permanent tiers (inMatchProgression) — both apply legitimately."),
    ]
}
