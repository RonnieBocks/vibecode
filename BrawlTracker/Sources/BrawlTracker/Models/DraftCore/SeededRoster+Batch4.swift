import Foundation

/// Batch 4 — Meg through R-T.
extension SeededRoster {
    static let batch4: [BrawlerProfile] = [

        p("Meg", 16000052, [.spaceMaker], .backline, [.poke],
          [.spaceControl, .carryThreat], [.formShift, .immobile],
          3, 3, 3, 4, 5, 5, .medium, seed: "antiTank",
          q: ["Seeded Anti-Tank, overridden: the mecha takes ground, and outside it she is a fragile poker rather than a duellist.",
              "The spaceMaker role describes the mecha state. Her role *outside* the mecha is unresolved, and the model has no way to vary roles downward by form — only to add them."],
          forms: [FormOverride(name: "Mecha", availability: .superGated, positioning: .frontline,
                               addedEngagePatterns: [.pressure],
                               notes: "Rebuilt via Super; this is the state she takes ground in.")],
          notes: "Base/form inverted in the Phase 1.6 audit: she *starts* outside the mecha, and the base must be the state she begins each life in."),

        p("Melodie", 16000078, [.assassin], .frontline, [.dive, .flank],
          [.carryThreat], [.resourceMeter, .gapClose, .escapeMobility],
          4, 3, 4, 4, 4, 4, .medium, seed: "spaceMaker",
          q: ["Assassin rests on the note-powered dashes serving as a genuine exit and not only as approach; the distinction is inferred from the tip."],
          notes: "Notes accumulate across attacks and power her dashes — resourceMeter feeding both mobility traits."),

        p("Mico", 16000075, [.assassin], .frontline, [.dive],
          [.carryThreat], [.gapClose, .escapeMobility],
          3, 2, 4, 3, 5, 5, .high, seed: "spaceMaker",
          notes: "Leaping over walls is both the commitment and the exit, so both mobility traits apply."),

        p("Mina", 16000097, [.spaceMaker], .frontline, [.pressure, .dive],
          [.carryThreat], [.conditionalEmpowerment, .gapClose],
          4, 3, 4, 4, 4, 4, .medium, seed: "spaceMaker",
          q: ["\"Combo Your Super With Main Attacks\" is read as a discrete empowerment trigger rather than an accumulating meter; the distinction is inferred.",
              "Whether her Super is a committing dash or a stationary effect is unconfirmed, and gapClose depends on it."]),

        p("Moe", 16000084, [.antiTank], .midline, [.pressure, .dive],
          [.tankAnswer, .carryThreat], [.gapClose],
          3, 3, 3, 3, 4, 4, .medium, seed: "antiTank",
          q: ["The drill is clearly a committing tool; whether it also serves as a reliable exit is unconfirmed, which is what keeps him out of Assassin."]),

        p("Mortis", 16000011, [.assassin], .frontline, [.dive, .flank],
          [.carryThreat], [.gapClose, .escapeMobility],
          4, 2, 5, 5, 5, 5, .high, seed: "spaceMaker",
          notes: "The dash is simultaneously his only movement, his commitment and his exit — the purest assassin in the roster, and the highest positioning demand."),

        p("Mr. P", 16000031, [.control], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.summon, .displacement, .immobile],
          3, 3, 3, 3, 3, 3, .high, seed: "control"),

        p("Najia", 16000103, [.control], .backline, [.poke, .hold],
          [.spaceControl, .tankAnswer], [.areaOnly, .immobile],
          3, 4, 4, 3, 3, 4, .medium, seed: "control",
          q: ["Whether her poison denies healing is unknown, so antiHeal is withheld."],
          notes: "Conflict resolved toward the seed. Her kit — Poison Puddles, Poisonous Protector, Venomous — is persistent area denial, and Sniper requires high single-target damage that poison attrition does not provide. \"Massive Range\" describes reach, not role."),

        p("Nani", 16000036, [.sniper], .backline, [.poke],
          [.tankAnswer, .carryThreat], [.immobile],
          3, 5, 4, 3, 4, 4, .high, seed: "sniper"),

        p("Nita", 16000008, [.antiTank], .midline, [.pressure, .poke],
          [.tankAnswer, .spaceControl], [.summon, .areaOnly, .immobile],
          2, 2, 3, 2, 3, 3, .high, seed: "antiTank"),

        p("Nori", 16000107, [.spaceMaker], .frontline, [.dive, .flank],
          [.carryThreat], [.gapClose],
          3, 3, 4, 3, 4, 4, .medium,
          q: ["No playbook seed; role taken from your own class override plus the tip (\"Jump Around The Map\").",
              "Whether the jump also disengages is unknown — that decides spaceMaker versus assassin."]),

        p("Ollie", 16000090, [.tank], .frontline, [.pressure],
          [.spaceControl, .diveAnswer], [.crowdControl, .resourceMeter, .immobile],
          3, 3, 3, 3, 3, 4, .medium, seed: "spaceMaker",
          q: ["Seeded Space Maker, overridden to Tank: \"soak up damage\" is absorbing for the team rather than pushing enemies off ground."],
          notes: "Hypnotise qualifies as crowdControl under the broadened definition."),

        p("Otis", 16000059, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .diveAnswer], [.crowdControl, .areaOnly, .immobile],
          3, 3, 3, 3, 3, 3, .high, seed: "antiTank",
          notes: "Silence is an unambiguous agency removal — no dependency on the slow ruling."),

        p("Pam", 16000016, [.support, .control], .midline, [.hold, .pressure],
          [.spaceControl, .diveAnswer], [.teamHealing, .summon, .areaOnly, .immobile],
          2, 2, 3, 3, 3, 3, .high, seed: "control",
          notes: "Both roles independently satisfied: the turret heals allies, and the scattershot holds ground."),

        p("Pearl", 16000072, [.antiTank], .midline, [.pressure, .poke],
          [.tankAnswer, .carryThreat], [.resourceMeter, .areaOnly, .immobile],
          3, 3, 3, 3, 4, 3, .medium, seed: "control",
          q: ["Seeded Control, overridden: heat exists to convert into burst damage, which is a duellist's job rather than a denial one."]),

        p("Penny", 16000019, [.control], .midline, [.poke, .hold],
          [.spaceControl], [.summon, .indirectFire, .immobile],
          3, 3, 3, 3, 3, 3, .high, seed: "control",
          notes: "Her mortar fires over cover — another non-thrower carrying indirectFire."),

        p("Pierce", 16000099, [.sniper], .backline, [.poke],
          [.tankAnswer, .carryThreat], [.conditionalEmpowerment, .reloadDependent, .immobile],
          3, 4, 4, 3, 4, 4, .medium, seed: "sniper",
          q: ["\"The Last Shot Is Key\" is read as a discrete empowerment on the final round of a magazine; the exact trigger is inferred."]),

        p("Piper", 16000015, [.sniper], .backline, [.poke],
          [.tankAnswer, .carryThreat], [.escapeMobility],
          3, 5, 5, 3, 4, 5, .high, seed: "sniper",
          notes: "Damage scaling with distance is a numeric property and stays in BalanceState, not in a trait."),

        p("Poco", 16000013, [.support], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.teamHealing, .areaOnly, .piercing, .immobile],
          2, 2, 3, 3, 2, 2, .high, seed: "support"),

        p("R-T", 16000066, [.sniper], .backline, [.poke, .hold],
          [.tankAnswer, .spaceControl], [.formShift, .immobile],
          3, 4, 4, 4, 4, 4, .medium, seed: "sniper",
          q: ["Marking an enemy so it takes extra damage is a debuff applied to the *target*. No trait represents enemy-applied debuffs — still an open gap, shared with Belle."],
          forms: [FormOverride(name: "Split", availability: .superGated, addedEngagePatterns: [.hold],
                               addedFunctions: [.spaceControl],
                               notes: "Head detached, he covers two lanes at once.")],
          notes: "The split is a genuine state change and now uses the form model rather than stretching formShift alone."),
    ]
}
