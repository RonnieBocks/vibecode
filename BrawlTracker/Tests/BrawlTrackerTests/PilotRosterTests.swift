import XCTest
@testable import BrawlTracker

/// Validates the Phase 1 pilot against the approved vocabulary and against the
/// coverage matrix it was selected from.
final class PilotRosterTests: XCTestCase {

    private var roster: [BrawlerProfile] { PilotRoster.profiles }

    // MARK: - Vocabulary discipline

    func testPilotUsesOnlyControlledVocabulary() {
        for p in roster {
            XCTAssertTrue(p.unknownTerms.isEmpty,
                          "\(p.key) uses off-vocabulary terms: \(p.unknownTerms)")
        }
    }

    func testEveryProfileRoundTripsThroughJSON() throws {
        // The pilot is authored in Swift, but Phase 1 proper ships JSON — so the
        // documents must survive encode/decode unchanged.
        let data = try JSONEncoder().encode(PilotRoster.set)
        let back = try JSONDecoder().decode(BrawlerProfileSet.self, from: data)
        XCTAssertEqual(back.profiles.count, roster.count)
        for original in roster {
            let decoded = back.profile(for: original.key)
            XCTAssertNotNil(decoded, "\(original.key) lost in round trip")
            XCTAssertEqual(decoded, original, "\(original.key) changed in round trip")
        }
    }

    func testSkillRatingsAreInRange() {
        for p in roster {
            let s = p.skill
            for (name, v) in [("mechanical", s.mechanicalDifficulty), ("aim", s.aimDifficulty),
                              ("positioning", s.positioningDifficulty), ("knowledge", s.gameKnowledge),
                              ("variance", s.variance), ("punishment", s.mistakePunishment)] {
                XCTAssertTrue((1...5).contains(v), "\(p.key) \(name) = \(v), outside 1…5")
            }
        }
    }

    func testConsistencyIsDerivedNotAuthored() {
        // Variance 5 must read as minimum consistency, and vice versa.
        XCTAssertEqual(PilotRoster.edgar.skill.variance, 5)
        XCTAssertEqual(PilotRoster.edgar.skill.consistency, 0, accuracy: 0.0001)
        XCTAssertEqual(SkillProfile(variance: 1).consistency, 1, accuracy: 0.0001)
    }

    func testUniformPolarityAcrossAllSixDimensions() {
        // Every dimension must move the same way: 1 = low, 5 = high.
        let low = SkillProfile(mechanicalDifficulty: 1, aimDifficulty: 1, positioningDifficulty: 1,
                               gameKnowledge: 1, variance: 1, mistakePunishment: 1)
        let high = SkillProfile(mechanicalDifficulty: 5, aimDifficulty: 5, positioningDifficulty: 5,
                                gameKnowledge: 5, variance: 5, mistakePunishment: 5)
        XCTAssertEqual(low.mechanical, 0, accuracy: 0.0001)
        XCTAssertEqual(high.mechanical, 1, accuracy: 0.0001)
        XCTAssertLessThan(low.floor, high.floor)
        XCTAssertLessThan(low.ceiling, high.ceiling)
    }

    // MARK: - Coverage matrix

    func testAllEightRolesAreExercised() {
        let covered = Set(roster.flatMap(\.roles))
        let missing = BrawlerRole.known.filter { !covered.contains($0) }
        XCTAssertTrue(missing.isEmpty, "roles not covered by the pilot: \(missing.map(\.rawValue))")
    }

    func testAllEngagePatternsAndFunctionsAreExercised() {
        let engage = Set(roster.flatMap(\.engagePatterns))
        XCTAssertTrue(EngagePattern.known.allSatisfy { engage.contains($0) },
                      "engage patterns missing: \(EngagePattern.known.filter { !engage.contains($0) }.map(\.rawValue))")
        let functions = Set(roster.flatMap(\.draftFunctions))
        XCTAssertTrue(DraftFunction.known.allSatisfy { functions.contains($0) },
                      "functions missing: \(DraftFunction.known.filter { !functions.contains($0) }.map(\.rawValue))")
    }

    func testAllFourTraitFamiliesAreExercised() {
        let traits = Set(roster.flatMap(\.traits))
        let families: [String: [Trait]] = [
            "mobility": [.escapeMobility, .gapClose, .immobile],
            "delivery": [.indirectFire, .slowProjectile, .piercing, .areaOnly, .reloadDependent, .windUp],
            "state": [.resourceMeter, .conditionalEmpowerment, .inMatchProgression, .formShift],
            "resilience": [.selfHealing, .shielded, .secondLife, .antiHeal],
            "utility": [.invisibility, .wallBreak, .summon, .crowdControl, .displacement, .teamHealing],
        ]
        for (family, terms) in families {
            XCTAssertTrue(terms.contains { traits.contains($0) }, "trait family untested: \(family)")
        }
    }

    func testSkillExtremesArePresentAtBothEnds() {
        XCTAssertEqual(PilotRoster.frank.skill.aimDifficulty, 1, "need a low-aim anchor")
        XCTAssertEqual(PilotRoster.bea.skill.aimDifficulty, 5, "need a high-aim anchor")
        XCTAssertEqual(PilotRoster.tick.skill.mistakePunishment, 5)
        XCTAssertLessThanOrEqual(PilotRoster.frank.skill.variance, 2)
    }

    func testMultiRoleCasesSpanAdjacentAndDistantPairs() {
        XCTAssertEqual(PilotRoster.lou.roles.count, 2, "adjacent pair")
        XCTAssertEqual(PilotRoster.crow.roles.count, 1,
                       "single role: Control was tested as a secondary and failed its own definition")
        XCTAssertEqual(PilotRoster.berry.roles, [.support, .thrower, .control],
                       "the distant set — and the first three-role profile")
        // Order is identity: primary must be first and must not be re-sorted.
        XCTAssertEqual(PilotRoster.lou.primaryRole, .control)
    }

    // MARK: - Authoring discipline

    func testFlexibleIsGoneFromTheVocabulary() {
        // Audited and removed: depth variation is a property of the mode, not
        // the brawler, so "flexible" could only ever mean "unknown" — which the
        // optional positioning already expresses.
        XCTAssertEqual(Positioning.known, [.frontline, .midline, .backline])
        XCTAssertFalse(Positioning(rawValue: "flexible").isKnown)
        for p in roster {
            XCTAssertNotEqual(p.positioning?.rawValue, "flexible", "\(p.key) still uses a removed term")
        }
    }

    func testUnsetPositioningStaysUnset() {
        XCTAssertNil(PilotRoster.bolt.positioning)
    }

    // MARK: - diveAnswer must not be personal durability

    func testDiveAnswerRequiresAnActiveMechanism() {
        for p in roster where p.performs(.diveAnswer) {
            XCTAssertTrue(DraftFunction.qualifiesForDiveAnswer(p),
                          "\(p.key) claims diveAnswer with no interrupting, displacing, peeling or blocking tool")
        }
    }

    /// The negative invariant: durability alone must never qualify. This is the
    /// guard against `assassinResistance` leaking into stable identity.
    func testHighSurvivabilityAloneDoesNotQualifyForDiveAnswer() {
        let durableButToothless = BrawlerProfile(
            key: BrawlerKey("Testwall"),
            roles: [.tank],
            positioning: .frontline,
            engagePatterns: [.hold],
            traits: [.shielded, .selfHealing, .immobile])   // pure personal durability
        XCTAssertFalse(DraftFunction.qualifiesForDiveAnswer(durableButToothless),
                       "shields and self-healing keep the brawler alive; they do not protect a teammate")

        // Adding one active mechanism flips it.
        var withPeel = durableButToothless
        withPeel.traits.insert(.crowdControl)
        XCTAssertTrue(DraftFunction.qualifiesForDiveAnswer(withPeel))
    }

    func testDurabilityTraitsAreExcludedFromTheQualifyingSet() {
        for t in [Trait.shielded, .selfHealing, .secondLife] {
            XCTAssertFalse(DraftFunction.diveAnswerMechanisms.contains(t),
                           "\(t) is personal durability and must not qualify")
        }
    }

    // MARK: - The chargeUp split

    func testChargeUpSplitIsAppliedByMechanism() {
        // Three mechanically different systems that used to share one term.
        XCTAssertTrue(PilotRoster.frank.has(.windUp), "a commit window inside one attack")
        XCTAssertTrue(PilotRoster.bibi.has(.resourceMeter), "a quantity accumulating across attacks")
        XCTAssertTrue(PilotRoster.bea.has(.conditionalEmpowerment), "empowerment from a discrete trigger")
        // And they are mutually exclusive on these three.
        XCTAssertFalse(PilotRoster.frank.has(.resourceMeter))
        XCTAssertFalse(PilotRoster.bibi.has(.conditionalEmpowerment))
        XCTAssertFalse(PilotRoster.bea.has(.windUp))
        XCTAssertFalse(Trait(rawValue: "chargeUp").isKnown, "the overloaded term is retired")
    }

    func testProgressionAndFormShiftAreDistinctConcepts() {
        XCTAssertTrue(PilotRoster.surge.has(.inMatchProgression))
        XCTAssertFalse(PilotRoster.surge.has(.formShift),
                       "Surge scales; he does not switch between different kits")
        XCTAssertTrue(Trait.formShift.isKnown)
    }

    // MARK: - Assassin definition: attrition vs pure poke

    /// The widened definition must admit set-up-then-commit assassination while
    /// still excluding poke and control brawlers that happen to be mobile.
    func testAssassinAdmitsAttritionButExcludesMobilePoke() {
        // Crow: poke → deny sustain → commit with mobility → secure → leave.
        let crow = PilotRoster.crow
        XCTAssertTrue(crow.has(.antiHeal), "denies sustain to create a kill threshold")
        XCTAssertTrue(crow.has(.gapClose) && crow.has(.escapeMobility), "commits, then leaves")
        XCTAssertTrue(crow.engagePatterns.contains(.dive), "the commitment is real, not just repositioning")
        XCTAssertEqual(crow.roles.first, .assassin)

        // Lou pokes and creates a threshold too, but cannot commit — excluded.
        let lou = PilotRoster.lou
        XCTAssertTrue(lou.has(.crowdControl))
        XCTAssertTrue(lou.has(.immobile), "no tool to commit onto a target")
        XCTAssertNotEqual(lou.roles.first, .assassin)

        // A mobile control brawler with no elimination threat stays excluded.
        let mobileZoner = BrawlerProfile(
            key: BrawlerKey("Testzoner"), roles: [.control], positioning: .midline,
            engagePatterns: [.poke], traits: [.escapeMobility, .areaOnly])
        XCTAssertFalse(mobileZoner.engagePatterns.contains(.dive))
        XCTAssertNotEqual(mobileZoner.roles.first, .assassin)
    }

    // MARK: - indirectFire is not redundant with the thrower role

    func testIndirectFireIsIndependentOfTheThrowerRole() {
        // Structural: an interaction rule matches on traits only — it cannot
        // see a role — so the mechanic must exist as a trait to be reasoned about.
        let arcing = TraitInteractionRule(
            id: "arc-vs-cover", attackerTraits: [.indirectFire], defenderTraits: [.immobile],
            polarity: .advantage, magnitude: 0.4, rationale: "Cover does not save an immobile target.")
        XCTAssertTrue(arcing.applies(attacker: PilotRoster.berry, defender: PilotRoster.tick),
                      "Berry is Support-primary; a role-keyed rule would have missed him")
        XCTAssertTrue(Trait.indirectFire.isKnown)
    }

    // MARK: - Evidence-driven role orders

    func testLouAndBerryOrdersMatchTheEvidence() {
        XCTAssertEqual(PilotRoster.lou.roles, [.control, .antiTank])
        XCTAssertEqual(PilotRoster.crow.roles, [.assassin], "attrition assassination qualifies")
        XCTAssertTrue(PilotRoster.crow.performs(.tankAnswer),
                      "the seed's Anti-Tank meaning survives as the function")
        XCTAssertTrue(PilotRoster.lou.performs(.tankAnswer),
                      "the seed's Anti-Tank meaning survives as the function")
        XCTAssertEqual(PilotRoster.berry.roles, [.support, .thrower, .control])
        XCTAssertTrue(PilotRoster.berry.has(.indirectFire),
                      "restored: a tip string is corroborating, not exhaustive (law 5)")
    }

    func testLowConfidenceProfileInventsNothing() {
        let bolt = PilotRoster.bolt
        XCTAssertTrue(bolt.roles.isEmpty, "the role is the part evidence cannot settle")
        XCTAssertTrue(bolt.draftFunctions.isEmpty)
        XCTAssertNil(bolt.positioning)
        // One trait is authored, and only because the description states it
        // outright. Everything beyond that stays unset.
        XCTAssertEqual(bolt.traits, [.gapClose])
        XCTAssertTrue(bolt.engagePatterns.isEmpty)
        XCTAssertEqual(bolt.authoring?.confidence, .low)
        XCTAssertFalse(bolt.authoring?.openQuestions.isEmpty ?? true,
                       "an empty profile must say why it is empty")
    }

    func testEveryProfileRecordsProvenance() {
        for p in roster {
            XCTAssertNotNil(p.authoring, "\(p.key) has no authoring metadata")
            XCTAssertFalse(p.authoring?.sources.isEmpty ?? true, "\(p.key) cites no evidence")
        }
    }

    func testSubHighConfidenceProfilesExplainThemselves() {
        for p in roster where (p.authoring?.confidence ?? .low) < .high {
            XCTAssertFalse(p.authoring?.openQuestions.isEmpty ?? true,
                           "\(p.key) is below high confidence but gives no reason")
        }
    }

    func testReviewQueueSurfacesExactlyTheUncertainProfiles() {
        let names = Set(PilotRoster.set.needingReview.map(\.key.normalized))
        // Evidence resolved Lou, Surge and Berry. Crow is high confidence but
        // carries an open question (Control tested and rejected); Bolt is low.
        XCTAssertEqual(names, Set(["crow", "bolt"].map { BrawlerArt.normalize($0) }))
    }

    // MARK: - Boundary decisions hold

    func testAssassinBoundaryIsDecidedByExitNotDamage() {
        // Edgar can leave; Bibi cannot. That single criterion separates them.
        XCTAssertTrue(PilotRoster.edgar.has(.escapeMobility))
        XCTAssertEqual(PilotRoster.edgar.roles.first, .assassin)
        XCTAssertFalse(PilotRoster.bibi.has(.escapeMobility))
        XCTAssertEqual(PilotRoster.bibi.roles.first, .spaceMaker)
    }

    func testImmobileIsAuthoredExplicitlyWhereverBothMobilityTraitsAreAbsent() {
        // Until rules can express absence, immobile must be stated, not inferred.
        for p in roster where !p.roles.isEmpty {
            let mobile = p.has(.escapeMobility) || p.has(.gapClose)
            if !mobile {
                XCTAssertTrue(p.has(.immobile),
                              "\(p.key) has no mobility trait and no explicit immobile — invisible to dive rules")
            } else {
                XCTAssertFalse(p.has(.immobile), "\(p.key) is both mobile and immobile")
            }
        }
    }

    // MARK: - Capability resolution works on real profiles

    func testPilotProfilesResolveCapabilitiesWithoutBalanceData() {
        // No BalanceState authored yet: every profile must still resolve.
        let model = CapabilityModel(rules: [
            .tankCountering: CapabilityRule(attributeWeights: [.damage: 0.6, .range: 0.4],
                                            functionAffinity: [.tankAnswer: 0.10]),
        ])
        let resolved = CapabilityResolver.resolveAll(profiles: PilotRoster.set,
                                                     balance: .unknown, model: model)
        XCTAssertEqual(resolved.count, roster.count)
        for p in roster {
            XCTAssertEqual(resolved[p.key]?[.tankCountering].confidence, 0,
                           "\(p.key) should report zero confidence with no attributes")
        }
        // The function affinity still shifts the score without gating it.
        let lou = resolved[PilotRoster.lou.key]!.value(.tankCountering)
        let tick = resolved[PilotRoster.tick.key]!.value(.tankCountering)
        XCTAssertGreaterThan(lou, tick, "tankAnswer affinity should lift Lou above Tick")
    }
}

/// Invariants applied to every seeded batch as the roster is filled in.
final class SeededRosterTests: XCTestCase {
    private var roster: [BrawlerProfile] { SeededRoster.all }

    func testNoOffVocabularyTerms() {
        for p in roster {
            XCTAssertTrue(p.unknownTerms.isEmpty, "\(p.key): \(p.unknownTerms)")
        }
    }

    func testNoDuplicateKeys() {
        let keys = roster.map(\.key.normalized)
        XCTAssertEqual(Set(keys).count, keys.count, "duplicate profiles seeded")
    }

    func testEveryProfileCitesEvidence() {
        for p in roster {
            XCTAssertFalse(p.authoring?.sources.isEmpty ?? true, "\(p.key) cites no evidence")
        }
    }

    func testSubHighConfidenceExplainsItself() {
        for p in roster where (p.authoring?.confidence ?? .low) < .high {
            XCTAssertFalse(p.authoring?.openQuestions.isEmpty ?? true,
                           "\(p.key) is below high confidence with no reason given")
        }
    }

    func testSkillRatingsInRange() {
        for p in roster {
            let s = p.skill
            for v in [s.mechanicalDifficulty, s.aimDifficulty, s.positioningDifficulty,
                      s.gameKnowledge, s.variance, s.mistakePunishment] {
                XCTAssertTrue((1...5).contains(v), "\(p.key) skill value \(v) outside 1…5")
            }
        }
    }

    func testImmobileIsExplicitWhereverMobilityIsAbsent() {
        for p in roster where !p.roles.isEmpty {
            let mobile = p.has(.escapeMobility) || p.has(.gapClose)
            XCTAssertEqual(p.has(.immobile), !mobile,
                           "\(p.key): immobile must be stated exactly when both mobility traits are absent")
        }
    }

    func testDiveAnswerAlwaysHasAnActiveMechanism() {
        for p in roster where p.performs(.diveAnswer) {
            XCTAssertTrue(DraftFunction.qualifiesForDiveAnswer(p),
                          "\(p.key) claims diveAnswer with no qualifying tool")
        }
    }

    func testFlexibleIsNeverUsed() {
        for p in roster {
            XCTAssertNotEqual(p.positioning?.rawValue, "flexible", "\(p.key)")
        }
    }

    func testAssassinsCanCommitAndLeave() {
        for p in roster where p.roles.first == .assassin {
            XCTAssertTrue(p.has(.gapClose) || p.has(.escapeMobility),
                          "\(p.key) is assassin-primary with no committing or exiting tool")
        }
    }

    func testWholeRosterRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(SeededRoster.set)
        let back = try JSONDecoder().decode(BrawlerProfileSet.self, from: data)
        XCTAssertEqual(back.profiles.count, roster.count)
    }

    /// The architectural boundary, checked rather than documented: no field in
    /// any objective type may look like player data.
    func testObjectiveModelCarriesNoPlayerData() throws {
        let samples: [Any] = [
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(SeededRoster.set)),
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(BalanceState.unknown)),
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(InteractionModel())),
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(RankedSeason(name: "s"))),
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(
                CapabilitySet(key: BrawlerKey("x"), balanceVersion: "v", modelVersion: 1))),
        ]
        for sample in samples {
            for key in DraftCoreBoundary.keys(in: sample) {
                for fragment in DraftCoreBoundary.forbiddenFieldFragments {
                    XCTAssertFalse(key.contains(fragment),
                                   "player-specific field '\(key)' leaked into the objective model")
                }
            }
        }
    }
}

/// Completeness checks that only make sense once the whole roster is seeded.
final class FullRosterTests: XCTestCase {

    func testEveryBrawlerInTheReferenceRosterHasAProfile() {
        // 109 brawlers exist in BrawlAPI; every one must be represented.
        XCTAssertEqual(SeededRoster.all.count, 109)
    }

    func testEveryRoleIsUsed() {
        let used = Set(SeededRoster.all.flatMap(\.roles))
        XCTAssertEqual(Set(BrawlerRole.known), used, "every controlled role must earn its place")
    }

    func testProfilesWithRolesAreCompletelyAuthored() {
        for p in SeededRoster.all where !p.roles.isEmpty {
            XCTAssertNotNil(p.positioning, "\(p.key) has a role but no positioning")
            XCTAssertFalse(p.engagePatterns.isEmpty, "\(p.key) has a role but no engage pattern")
            XCTAssertFalse(p.draftFunctions.isEmpty, "\(p.key) has a role but no draft function")
        }
    }

    func testUnrolledProfilesAreAllLowConfidence() {
        for p in SeededRoster.all where p.roles.isEmpty {
            XCTAssertEqual(p.authoring?.confidence, .low,
                           "\(p.key) has no role but is not marked low confidence")
        }
    }

    func testCapabilityResolutionRunsOverTheWholeRoster() {
        let model = CapabilityModel(rules: [
            .tankCountering: CapabilityRule(attributeWeights: [.damage: 0.6, .range: 0.4],
                                            functionAffinity: [.tankAnswer: 0.10]),
        ])
        let resolved = CapabilityResolver.resolveAll(profiles: SeededRoster.set,
                                                     balance: .unknown, model: model)
        XCTAssertEqual(resolved.count, 109)
    }
}

/// Phase 1.5 — the ally-protection trait, the broadened crowdControl ruling,
/// and the form/state override model.
final class Phase15Tests: XCTestCase {

    // MARK: - allyProtection

    func testAllyProtectionIsUsedByMultipleBrawlers() {
        let holders = SeededRoster.all.filter { $0.has(.allyProtection) }
        XCTAssertGreaterThanOrEqual(holders.count, 3,
                                    "a new term must earn its place across several profiles")
        XCTAssertEqual(Set(holders.map(\.key.normalized)),
                       Set(["buster", "gus", "wendy"].map { BrawlerArt.normalize($0) }))
    }

    func testAllyProtectionQualifiesForDiveAnswer() {
        XCTAssertTrue(DraftFunction.diveAnswerMechanisms.contains(.allyProtection))
        for name in ["Buster", "Gus", "Wendy"] {
            let p = SeededRoster.set.profile(for: name)!
            XCTAssertTrue(p.performs(.diveAnswer), "\(name) should now answer dives")
            XCTAssertTrue(DraftFunction.qualifiesForDiveAnswer(p))
        }
    }

    func testAllyProtectionIsDistinctFromPersonalDurability() {
        // Buster carries both: shielded for himself, allyProtection for the team.
        let buster = SeededRoster.set.profile(for: "Buster")!
        XCTAssertTrue(buster.has(.shielded) && buster.has(.allyProtection))
        // Rosa is personally durable and must not qualify.
        let rosa = SeededRoster.set.profile(for: "Rosa")!
        XCTAssertTrue(rosa.has(.shielded))
        XCTAssertFalse(rosa.has(.allyProtection))
        XCTAssertFalse(DraftFunction.qualifiesForDiveAnswer(rosa))
        // Nor may ordinary healing be conflated with protection.
        let poco = SeededRoster.set.profile(for: "Poco")!
        XCTAssertTrue(poco.has(.teamHealing))
        XCTAssertFalse(poco.has(.allyProtection))
    }

    // MARK: - Broadened crowdControl

    func testSlowsNowCountAsCrowdControl() {
        for name in ["Emz", "Glowy", "Ollie", "Spike"] {
            XCTAssertTrue(SeededRoster.set.profile(for: name)!.has(.crowdControl),
                          "\(name) depends on the broadened ruling")
        }
    }

    func testConfinementCountsAsCrowdControl() {
        // Cordelius's target isolation is resolved by the broadened definition
        // rather than by a new term.
        XCTAssertTrue(SeededRoster.set.profile(for: "Cordelius")!.has(.crowdControl))
    }

    func testDisplacementStaysDistinctFromCrowdControl() {
        // Pure forced movement must not silently become crowd control.
        for name in ["Gene", "Mr. P", "Jacky", "Shelly", "Maisie"] {
            let p = SeededRoster.set.profile(for: name)!
            XCTAssertTrue(p.has(.displacement), "\(name)")
            XCTAssertFalse(p.has(.crowdControl), "\(name) has only forced movement")
        }
    }

    // MARK: - Form / state model

    func testFormsAreDiffsNotDuplicateProfiles() {
        let bonnie = SeededRoster.set.profile(for: "Bonnie")!
        XCTAssertEqual(bonnie.positioning, .backline, "base is authoritative")
        XCTAssertEqual(bonnie.roles, [.sniper])

        let out = bonnie.resolved(inForm: "Out of cannon")
        XCTAssertEqual(out.positioning, .frontline)
        XCTAssertEqual(out.roles, [.sniper, .spaceMaker], "base order preserved, form appended")
        XCTAssertTrue(out.engagePatterns.contains(.pressure))
        XCTAssertFalse(out.engagePatterns.contains(.poke), "removals apply")
        XCTAssertEqual(bonnie.key, out.key, "a form is the same brawler")
    }

    func testUnknownOrNilFormReturnsTheBaseUnchanged() {
        let kaze = SeededRoster.set.profile(for: "Kaze")!
        XCTAssertEqual(kaze.resolved(inForm: nil), kaze)
        XCTAssertEqual(kaze.resolved(inForm: "Nonexistent"), kaze)
    }

    func testEveryFormShiftBrawlerHasFormsAuthored() {
        for p in SeededRoster.all where p.has(.formShift) {
            XCTAssertFalse(p.forms.isEmpty,
                           "\(p.key) carries formShift but has no form override authored")
        }
    }

    func testFormsRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(SeededRoster.set)
        let back = try JSONDecoder().decode(BrawlerProfileSet.self, from: data)
        let kaze = back.profile(for: "Kaze")!
        XCTAssertEqual(kaze.formNames, ["Ninja"])
        XCTAssertEqual(kaze.resolved(inForm: "Ninja").positioning, .frontline)
    }

    // MARK: - Unresolved profiles must say why

    func testEveryZeroRoleProfileRecordsItsReason() {
        for p in SeededRoster.all where p.roles.isEmpty {
            XCTAssertNotNil(p.authoring?.unresolvedReason,
                            "\(p.key) has no role and no stated reason — the silent gap this field exists to prevent")
        }
    }

    func testFormsDoNotLeakPlayerData() throws {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SeededRoster.set))
        for key in DraftCoreBoundary.keys(in: json) {
            for fragment in DraftCoreBoundary.forbiddenFieldFragments {
                XCTAssertFalse(key.contains(fragment), "player field '\(key)' leaked in")
            }
        }
    }
}

/// Phase 1.6 — synthetic invariants guarding the crowdControl/displacement
/// boundary, and the form model's fitness for future draft-time reasoning.
final class Phase16Tests: XCTestCase {

    private func synthetic(_ name: String, _ traits: Set<Trait>) -> BrawlerProfile {
        BrawlerProfile(key: BrawlerKey(name), roles: [.control], positioning: .midline,
                       engagePatterns: [.hold], traits: traits)
    }

    // MARK: - crowdControl / displacement are independent

    func testSlowOnlyIsCrowdControlAndNotDisplacement() {
        let p = synthetic("Testslow", [.crowdControl, .immobile])
        XCTAssertTrue(p.has(.crowdControl))
        XCTAssertFalse(p.has(.displacement), "restricting movement does not relocate anyone")
    }

    func testKnockbackOnlyIsDisplacementAndNotCrowdControl() {
        let p = synthetic("Testknock", [.displacement, .immobile])
        XCTAssertTrue(p.has(.displacement))
        XCTAssertFalse(p.has(.crowdControl),
                       "being moved is not being restricted — a knocked-back target keeps full agency")
    }

    func testFreezeRootAndStunAreAllCrowdControl() {
        // All three are the same trait: presence, not severity. Magnitude lives
        // in attributes and capabilities.
        for label in ["Testfreeze", "Testroot", "Teststun"] {
            XCTAssertTrue(synthetic(label, [.crowdControl, .immobile]).has(.crowdControl))
        }
    }

    func testBothCoexistWhenEachIsIndependentlyJustified() {
        let p = synthetic("Testboth", [.crowdControl, .displacement, .immobile])
        XCTAssertTrue(p.has(.crowdControl) && p.has(.displacement),
                      "the model must permit a kit that both restricts and relocates")
    }

    func testNeitherTraitImpliesTheOtherAcrossTheRoster() {
        // Guards against drift: no profile may have gained one by inheriting the
        // other. Every co-occurrence must be deliberate.
        for p in SeededRoster.all {
            if p.has(.displacement) && p.has(.crowdControl) {
                XCTAssertFalse(p.notes?.isEmpty ?? true,
                               "\(p.key) carries both and must justify it in notes")
            }
        }
        // As authored, the two are entirely disjoint on the live roster.
        let both = SeededRoster.all.filter { $0.has(.displacement) && $0.has(.crowdControl) }
        XCTAssertTrue(both.isEmpty, "unexpected overlap: \(both.map(\.key.description))")
    }

    // MARK: - Concealment broadening

    func testInvisibilityCoversSelfAndAlliedConcealment() {
        let leon = SeededRoster.set.profile(for: "Leon")!      // self
        let sandy = SeededRoster.set.profile(for: "Sandy")!    // team
        XCTAssertTrue(leon.has(.invisibility))
        XCTAssertTrue(sandy.has(.invisibility), "allied concealment now qualifies")
        XCTAssertFalse(Trait(rawValue: "teamConcealment").isKnown,
                       "broadened rather than split")
    }

    // MARK: - Draft-time versus current-state identity

    func testBaseIsTheStateTheBrawlerStartsIn() {
        // Meg starts outside the mecha, so the mecha is the override.
        let meg = SeededRoster.set.profile(for: "Meg")!
        XCTAssertEqual(meg.positioning, .backline)
        XCTAssertEqual(meg.formNames, ["Mecha"])
        XCTAssertEqual(meg.resolved(inForm: "Mecha").positioning, .frontline)
    }

    func testReachableStatesExposePotentialWithoutMergingIt() {
        let bonnie = SeededRoster.set.profile(for: "Bonnie")!
        let states = bonnie.reachableStates
        XCTAssertEqual(states.count, 2, "the base plus one form")
        XCTAssertNil(states[0].form, "the first state is always the certain one")
        XCTAssertEqual(states[0].profile.positioning, .backline)
        XCTAssertEqual(states[1].profile.positioning, .frontline)
        // The states stay separate — nothing hands an engine a merged profile
        // carrying the strength of both at once.
        XCTAssertNotEqual(states[0].profile, states[1].profile)
    }

    func testFormAvailabilityIsRecordedForEveryForm() {
        for p in SeededRoster.all {
            for form in p.forms {
                XCTAssertTrue(FormOverride.Availability.allCases.contains(form.availability),
                              "\(p.key) form \(form.name) has no availability")
            }
        }
    }

    func testEveryFormOnTheLiveRosterIsDeniable() {
        // A finding rather than a rule: no brawler currently reaches an alternate
        // form without a Super or a random trigger, so every form can be denied
        // by pressure. An engine may treat base identity as certain and forms as
        // discounted potential.
        for p in SeededRoster.all where p.hasForms {
            XCTAssertTrue(p.allFormsAreDeniable, "\(p.key) has a guaranteed form — revisit the assumption")
        }
    }

    func testChestersRotationIsConditionalNotSuperGated() {
        let chester = SeededRoster.set.profile(for: "Chester")!
        XCTAssertTrue(chester.forms.allSatisfy { $0.availability == .conditional },
                      "a random rotation cannot be planned around by either side")
    }
}
