import Foundation

/// Batch 5 — Rico through Ziggy.
extension SeededRoster {
    static let batch5: [BrawlerProfile] = [

        p("Rico", 16000004, [.antiTank], .midline, [.poke, .pressure],
          [.tankAnswer, .spaceControl], [.immobile],
          3, 4, 4, 4, 4, 4, .high, seed: "antiTank",
          q: ["Bullets that ricochet off terrain have no trait. It is not piercing (nothing passes through a target) and not indirectFire (line of sight is still required). Reported as a vocabulary gap — Sprout shares it."]),

        p("Rosa", 16000024, [.tank], .frontline, [.pressure],
          [.spaceControl], [.shielded, .immobile],
          2, 2, 3, 3, 3, 3, .high, seed: "tank"),

        p("Ruffs", 16000044, [.support, .antiTank], .midline, [.poke, .hold],
          [.spaceControl, .tankAnswer], [.immobile],
          3, 3, 3, 3, 3, 3, .medium, seed: "antiTank",
          q: ["Dropping power-ups that buff teammates has no trait — the same family of gap as Max's speed and Gray's portals."]),

        p("Sam", 16000060, [.spaceMaker], .frontline, [.pressure, .dive],
          [.carryThreat, .spaceControl], [.conditionalEmpowerment, .gapClose],
          3, 3, 3, 3, 4, 4, .medium, seed: "spaceMaker",
          q: ["Holding the knuckles is read as a discrete empowered state rather than an accumulating meter; the trigger is inferred from \"Throw Fists Reclaim Repeat\"."]),

        p("Sandy", 16000028, [.control], .midline, [.poke, .hold],
          [.spaceControl], [.areaOnly, .invisibility, .immobile],
          3, 3, 3, 3, 3, 3, .high, seed: "antiTank",
          notes: "Gap closed by broadening rather than by a new term: invisibility now covers allied concealment, and the sandstorm conceals Sandy along with his team."),

        p("Shade", 16000086, [.assassin], .frontline, [.flank, .dive],
          [.carryThreat], [.gapClose, .escapeMobility],
          4, 3, 4, 4, 4, 4, .medium, seed: "spaceMaker",
          q: ["Recent brawler; the wall-phasing is confidently an exit as well as an approach, but the skill ratings are archetype-led."],
          notes: "Moving through walls serves as both approach and exit, which satisfies Assassin on both criteria."),

        p("Shelly", 16000000, [.antiTank], .midline, [.pressure, .poke],
          [.tankAnswer, .diveAnswer], [.displacement, .wallBreak, .areaOnly, .immobile],
          2, 3, 3, 2, 3, 3, .high, seed: "antiTank",
          notes: "Her tip — \"Counter Tanks And Assassins With Burst Damage\" — names both draft functions outright, and the knockback is the qualifying mechanism for diveAnswer."),

        p("Sirius", 16000102, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile],
          3, 3, 4, 3, 3, 4, .low, seed: "thrower",
          q: ["Recent brawler with no direct kit knowledge; everything here follows the thrower archetype and the tip, and the skill ratings are archetype defaults rather than judgements."]),

        p("Spike", 16000005, [.antiTank, .control], .midline, [.poke, .hold],
          [.tankAnswer, .spaceControl, .diveAnswer], [.areaOnly, .crowdControl, .immobile],
          3, 4, 4, 3, 4, 4, .high, seed: "antiTank",
          notes: "The slowing Super qualifies as crowdControl under the broadened definition, which settles diveAnswer for him."),

        p("Sprout", 16000037, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile, .slowProjectile],
          3, 3, 4, 4, 3, 5, .high, seed: "thrower",
          q: ["Placing a hedge wall creates terrain. That is neither summon (it does not act) nor displacement. Reported as a vocabulary gap alongside Rico's ricochet."]),

        p("Squeak", 16000047, [.control], .midline, [.poke, .hold],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile, .slowProjectile],
          3, 3, 3, 3, 3, 4, .high, seed: "control",
          notes: "A third non-thrower with indirectFire, alongside Meeple and Penny."),

        p("Starr Nova", 16000105, [.assassin], .midline, [.poke],
          [.carryThreat], [.formShift, .gapClose],
          4, 3, 4, 4, 4, 4, .low,
          q: ["Conflict stands. Your class override records her as Support; the tip reads \"Poke Then Transform And Strike\" and her star power is \"Power Level Maximum\" — transformation and scaling, with nothing pointing at healing, shielding or buffing allies.",
              "Authored from the kit evidence and left low confidence. If she does buff allies, Support belongs first and this profile is wrong."],
          forms: [FormOverride(name: "Transformed", availability: .superGated, positioning: .frontline,
                               addedEngagePatterns: [.dive], removedEngagePatterns: [.poke],
                               notes: "Strikes after the transform.")],
          notes: "Base engage corrected in the Phase 1.6 audit: diving belongs to the transformed state, not to the state she starts in."),

        p("Stu", 16000045, [.assassin], .frontline, [.dive, .flank],
          [.carryThreat], [.gapClose, .escapeMobility],
          4, 3, 4, 3, 4, 4, .high, seed: "control",
          q: ["Seeded Control, overridden: \"Use Your Dash To Get Close Or Dodge\" is the assassin pattern stated in one line."]),

        p("Tara", 16000017, [.antiTank, .control], .midline, [.poke, .pressure],
          [.tankAnswer, .spaceControl, .diveAnswer], [.piercing, .displacement, .immobile],
          3, 4, 3, 4, 4, 4, .high, seed: "antiTank",
          notes: "Both roles independently satisfied: piercing cards punish bulk, and the gravity pull reshapes where a fight happens."),

        p("Trunk", 16000096, [.tank], .frontline, [.pressure, .dive],
          [.spaceControl], [.resourceMeter, .gapClose, .summon],
          3, 3, 3, 3, 3, 4, .medium, seed: "tank",
          q: ["Ants are recorded as both an accumulating resource and a placed entity; whether they act independently is unconfirmed."]),

        p("Vince", 16000110, [], nil, [], [], [.resourceMeter, .inMatchProgression],
          3, 3, 3, 3, 3, 3, .low,
          q: ["\"Collect Caterpillars To Become More Powerful\" is direct evidence for an accumulating resource that converts into growing power, and for nothing else."],
          unresolved: .gameContextExclusion,
          notes: "Hidden from ranked by default. The two traits are evidenced; the role is not, and is not forced."),

        p("Wendy", 16000108, [.support], .midline, [.hold],
          [.spaceControl, .diveAnswer], [.allyProtection, .immobile],
          3, 3, 3, 3, 3, 3, .high,
          q: ["Star powers Slowing Shield and Solar Shield corroborate the base mechanic, but are themselves excluded by law 3."],
          notes: "Role agrees with your own class override and with the tip. Your Safe Zone match note called her S-tier there; that is meta strength and stays out of this layer."),

        p("Willow", 16000067, [.thrower, .control], .backline, [.poke, .hold],
          [.spaceControl], [.indirectFire, .crowdControl, .immobile],
          3, 3, 4, 4, 4, 4, .medium, seed: "thrower",
          q: ["Control is independently satisfied through mind control, but whether her base attack arcs — and so whether Thrower should lead — rests on the seed rather than confirmed evidence."],
          notes: "Mind control is the least ambiguous crowd control in the roster — it removes agency completely."),

        p("Ziggy", 16000098, [.thrower], .backline, [.hold, .poke],
          [.spaceControl], [.indirectFire, .areaOnly, .immobile],
          3, 3, 4, 3, 3, 4, .low, seed: "thrower",
          q: ["Newest brawler in the roster and the least evidenced. Authored to the thrower archetype from the tip; skill ratings are defaults, not judgements."]),
    ]
}
