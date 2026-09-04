import Foundation

/// Batch 2 — Colette through Griff.
extension SeededRoster {
    static let batch2: [BrawlerProfile] = [

        p("Colette", 16000039, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .carryThreat], [.piercing, .gapClose],
          3, 3, 3, 3, 3, 3, .high, seed: "antiTank",
          notes: "Percentage-based damage is the cleanest tankAnswer in the roster."),

        p("Colt", 16000001, [.antiTank], .midline, [.poke],
          [.tankAnswer, .spaceControl], [.reloadDependent, .wallBreak, .immobile],
          2, 5, 4, 2, 4, 4, .high, seed: "antiTank"),

        p("Cordelius", 16000070, [.assassin], .midline, [.dive, .poke],
          [.carryThreat], [.gapClose, .crowdControl],
          3, 3, 4, 4, 4, 4, .high, seed: "antiTank",
          notes: "Gap closed by the broadened definition: confining a target to the shadow realm restricts where it can go, which is crowd control even though the target still acts."),

        p("Cosmo", 16000109, [], nil, [], [], [],
          3, 3, 3, 3, 3, 3, .low,
          q: ["The tip alone (\"Use Gravity To Target Enemies\") does not settle role, positioning or exit capability."],
          unresolved: .gameContextExclusion,
          notes: "Hidden from ranked by default; not draftable, so the gap has no practical cost."),

        p("Damian", 16000104, [], nil, [], [], [.gapClose],
          3, 3, 3, 3, 3, 3, .low,
          q: ["\"Jump In To Unleash Chaos\" is direct evidence for gapClose and nothing else.",
              "spaceMaker and assassin both fit; the tie turns on whether he can disengage, which no source states."],
          unresolved: .classificationBoundary),

        p("Darryl", 16000018, [.spaceMaker], .frontline, [.dive, .pressure],
          [.carryThreat, .spaceControl], [.gapClose],
          3, 2, 3, 3, 4, 4, .high, seed: "spaceMaker"),

        p("Doug", 16000071, [.support, .spaceMaker], .frontline, [.pressure],
          [.spaceControl, .diveAnswer], [.secondLife, .teamHealing, .immobile],
          2, 2, 3, 3, 3, 3, .medium, seed: "support",
          q: ["Reviving a fallen teammate is recorded as teamHealing, which is the closest available term but not accurate — a revive is not healing. Flagged rather than given a new term."]),

        p("Draco", 16000080, [.tank], .frontline, [.poke, .pressure],
          [.spaceControl, .carryThreat], [.formShift, .gapClose],
          3, 3, 3, 4, 4, 4, .high, seed: "tank",
          forms: [FormOverride(name: "Dragon", availability: .superGated, addedRoles: [.spaceMaker],
                               addedEngagePatterns: [.dive],
                               notes: "Transformed, he commits rather than pokes.")],
          notes: "Base is the human form: tank, frontline, poke and pressure."),

        p("Dynamike", 16000009, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile, .slowProjectile, .wallBreak],
          2, 4, 4, 3, 4, 5, .high, seed: "thrower"),

        p("El Primo", 16000010, [.tank], .frontline, [.dive, .pressure],
          [.spaceControl, .carryThreat], [.gapClose],
          2, 2, 3, 2, 3, 3, .high, seed: "tank"),

        p("Emz", 16000030, [.control], .midline, [.pressure, .poke],
          [.spaceControl, .diveAnswer], [.areaOnly, .crowdControl, .immobile],
          2, 2, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Seeded Anti-Tank, overridden to Control: wide attack, denial over damage."],
          notes: "The slow now qualifies as crowdControl under the broadened definition — ruling settled."),

        p("Eve", 16000056, [.control], .backline, [.poke, .hold],
          [.spaceControl], [.summon, .immobile],
          3, 3, 4, 3, 3, 4, .high, seed: "control",
          q: ["Walking over water is real repositioning with no trait to hold it; immobile is literally correct but under-describes her."]),

        p("Fang", 16000054, [.spaceMaker], .frontline, [.poke, .dive],
          [.carryThreat, .tankAnswer], [.gapClose],
          3, 3, 4, 3, 4, 4, .medium, seed: "tank",
          q: ["Matches the assassin setup pattern — poke, then commit to finish — but fails the exit criterion, exactly as Bibi does. Held to spaceMaker for consistency rather than promoted on flavour."]),

        p("Finx", 16000092, [.control], .midline, [.poke, .hold],
          [.spaceControl], [.immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Seeded Anti-Tank, overridden to Control on the tip (\"take space\").",
              "A field that slows *enemy projectiles* is not crowd control (it does not touch the enemy), not shielded (it is not personal), and not area denial. Reported as a vocabulary gap."]),

        p("Gale", 16000035, [.control], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.displacement, .immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Seeded Anti-Tank, overridden to Control — his value is pushing enemies off ground, not killing them."]),

        p("Gene", 16000021, [.control], .midline, [.poke, .hold],
          [.spaceControl, .diveAnswer], [.displacement, .areaOnly, .immobile],
          3, 4, 3, 4, 4, 3, .high, seed: "control"),

        p("Gigi", 16000100, [.assassin], .frontline, [.dive, .flank],
          [.carryThreat], [.gapClose, .escapeMobility],
          4, 3, 4, 3, 4, 4, .medium, seed: "spaceMaker",
          q: ["Assassin rests on reading her dodge as a genuine disengage. If it is only a positional evade, she fails the exit criterion and is spaceMaker like Fang."]),

        p("Glowy", 16000101, [.support, .control], .midline, [.hold, .poke],
          [.spaceControl, .diveAnswer], [.teamHealing, .crowdControl, .immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "support",
          q: ["Fear is read as crowd control — it removes control of movement. Same ruling dependency as Emz's slow."]),

        p("Gray", 16000064, [.support], .midline, [.poke, .hold],
          [.spaceControl], [.escapeMobility],
          4, 3, 4, 5, 4, 3, .medium, seed: "support",
          q: ["Portals reposition the whole team, which has no trait. escapeMobility captures only his own use of them and under-describes the mechanic."]),

        p("Griff", 16000050, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .carryThreat], [.areaOnly, .immobile],
          2, 4, 3, 2, 4, 3, .high, seed: "antiTank"),
    ]
}
