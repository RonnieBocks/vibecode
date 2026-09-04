import XCTest
@testable import BrawlTracker

/// Phase 0 — the foundational type system only. Nothing here touches
/// DraftEngine V1, DraftClass, or any production flow.
final class DraftCoreTests: XCTestCase {

    // MARK: - Fixtures (a handful of brawlers, not the roster)

    /// A controller with a slow area projectile and no escape tool.
    private var controller: BrawlerProfile {
        BrawlerProfile(key: BrawlerKey("Testlou", id: 901),
                       roles: [.control, .antiTank],
                       positioning: .midline,
                       engagePatterns: [.hold, .poke],
                       draftFunctions: [.tankAnswer, .spaceControl],
                       traits: [.slowProjectile, .areaOnly, .immobile],
                       skill: SkillProfile(mechanicalDifficulty: 2, aimDifficulty: 2, positioningDifficulty: 3))
    }

    /// A diver that can leave a fight whenever it likes.
    private var diver: BrawlerProfile {
        BrawlerProfile(key: BrawlerKey("Testedgar", id: 902),
                       roles: [.assassin],
                       positioning: .frontline,
                       engagePatterns: [.dive],
                       draftFunctions: [.carryThreat],
                       traits: [.escapeMobility, .gapClose, .selfHealing],
                       skill: SkillProfile(mechanicalDifficulty: 2, variance: 5, mistakePunishment: 5))
    }

    /// Deliberately carries NO antiTank draft function, but hits hard from range.
    private var undeclaredAntiTank: BrawlerProfile {
        BrawlerProfile(key: BrawlerKey("Testnewcomer", id: 903),
                       roles: [.antiTank],
                       positioning: .midline,
                       draftFunctions: [.carryThreat],
                       traits: [.piercing])
    }

    private func attributes(_ key: BrawlerKey, _ pairs: [(AttributeKind, AttributeBand)]) -> BrawlerAttributes {
        var a = BrawlerAttributes(key: key)
        for (kind, band) in pairs { a[kind] = AttributeValue(band: band, provenance: .estimated) }
        return a
    }

    /// A tank-countering rule: mostly damage and range, with a modest bonus for
    /// brawlers actually expected to do the job.
    private var tankCounterModel: CapabilityModel {
        let rule = CapabilityRule(
            baseline: 0.5,
            attributeWeights: [.damage: 0.6, .range: 0.4, .effectiveHealth: 0.1],
            traitAdjustments: [.piercing: 0.05],
            functionAffinity: [.tankAnswer: 0.10],
            rationale: "Damage and range decide whether a tank can be pushed off.")
        return CapabilityModel(rules: [.tankCountering: rule])
    }

    // MARK: - Vocabularies stay open

    func testUnknownVocabularyTermSurvivesRoundTrip() throws {
        // A term from a newer build must decode, not throw.
        let json = #"{"key":"futurebrawler","roles":["timeMage"],"traits":["chronoShift"],"positioning":"orbital"}"#
        let profile = try JSONDecoder().decode(BrawlerProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.roles.first?.rawValue, "timeMage")
        XCTAssertTrue(profile.traits.contains(Trait(rawValue: "chronoShift")))
        XCTAssertFalse(profile.roles[0].isKnown)
        XCTAssertEqual(profile.unknownTerms, ["chronoShift", "orbital", "timeMage"])

        // And survives a re-encode unchanged.
        let again = try JSONDecoder().decode(BrawlerProfile.self,
                                             from: JSONEncoder().encode(profile))
        XCTAssertEqual(again.roles.first?.rawValue, "timeMage")
    }

    func testMissingFieldsFallBackInsteadOfFailing() throws {
        let profile = try JSONDecoder().decode(BrawlerProfile.self, from: Data(#"{"key":"minimal"}"#.utf8))
        XCTAssertEqual(profile.key.normalized, "minimal")
        XCTAssertTrue(profile.roles.isEmpty)
        XCTAssertNil(profile.positioning, "unset must not become flexible")
        XCTAssertEqual(profile.skill.mechanicalDifficulty, 3)
    }

    func testTermMapEncodesAsAJSONObject() throws {
        let map: TermMap<AttributeKind, AttributeValue> = [.damage: AttributeValue(band: .high)]
        let json = String(data: try JSONEncoder().encode(map), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"damage\""), "authored files must be readable objects, not key/value arrays")
    }

    // MARK: - Identity

    func testRoleOrderIsPreserved() throws {
        let round = try JSONDecoder().decode(BrawlerProfile.self,
                                             from: JSONEncoder().encode(controller))
        XCTAssertEqual(round.roles, [.control, .antiTank])
        XCTAssertEqual(round.primaryRole, .control)
    }

    func testBrawlerKeyIdentityIgnoresDisplayAndResolvesAliases() {
        let a = BrawlerKey("Larry & Lawrie", id: 1)
        let b = BrawlerKey("larry  and  lawrie")
        XCTAssertEqual(a.normalized, BrawlerArt.normalize("Larry & Lawrie"))
        XCTAssertNotEqual(a, b, "normalization is the identity; these differ")

        var renamed = BrawlerKey("Newname")
        renamed.aliases = ["Oldname"]
        XCTAssertTrue(renamed.matches("oldname"), "history keyed by the old name must still resolve")
    }

    // MARK: - Attributes and fixed anchors

    func testBandsUseFixedNormalizedValues() {
        XCTAssertEqual(AttributeBand.average.normalized, 0.5, accuracy: 0.0001)
        XCTAssertEqual(AttributeBand.veryLow.normalized, 0.0, accuracy: 0.0001)
        XCTAssertEqual(AttributeBand.veryHigh.normalized, 1.0, accuracy: 0.0001)
        XCTAssertTrue(AttributeBand.low < AttributeBand.high)
    }

    func testOneBrawlerChangeDoesNotMoveAnother() {
        // The percentile trap: buffing one brawler must not shift anyone else.
        let model = tankCounterModel
        let subject = undeclaredAntiTank
        let base = attributes(subject.key, [(.damage, .average), (.range, .average)])
        let before = CapabilityResolver.resolve(profile: subject, attributes: base, model: model,
                                                anchors: .empty, balanceVersion: "p1")

        var buffed = BalanceState(version: "p2")
        buffed.attributes = [base, attributes(BrawlerKey("Someoneelse"),
                                              [(.damage, .veryHigh), (.range, .veryHigh)])]
        let after = CapabilityResolver.resolve(profile: subject,
                                               attributes: buffed.attributes(for: subject.key),
                                               model: model, anchors: .empty, balanceVersion: "p2")
        XCTAssertEqual(before.value(.tankCountering), after.value(.tankCountering), accuracy: 0.0001)
    }

    func testRawValueWithAnchorBeatsBand() {
        var anchors = AttributeAnchors()
        anchors.anchors[.range] = AttributeAnchor(low: 0, high: 10, unit: "tiles")
        let value = AttributeValue(band: .veryLow, raw: 10)
        let resolved = value.resolve(.range, anchors: anchors)
        XCTAssertEqual(resolved?.value ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(resolved?.how, .raw)

        // With no anchor for that kind, the band is used instead.
        XCTAssertEqual(AttributeValue(band: .veryLow, raw: 10)
            .resolve(.damage, anchors: .empty)?.how, .band)
    }

    // MARK: - Capabilities are derived, and functions never gate

    func testDraftFunctionIsNotACapabilityGate() {
        // The approved requirement: a brawler with no antiTank draft function
        // must still resolve high tank-countering when its attributes justify it.
        let model = tankCounterModel
        let strong = attributes(undeclaredAntiTank.key, [(.damage, .veryHigh), (.range, .veryHigh)])
        let resolved = CapabilityResolver.resolve(profile: undeclaredAntiTank, attributes: strong,
                                                  model: model, anchors: .empty, balanceVersion: "p1")

        XCTAssertFalse(undeclaredAntiTank.performs(.tankAnswer))
        XCTAssertGreaterThan(resolved.value(.tankCountering), 0.7,
                             "attributes alone must be able to produce a high capability")
        XCTAssertGreaterThan(resolved[.tankCountering].confidence, 0.8)
    }

    func testFunctionAffinityShiftsButDoesNotDominate() {
        let model = tankCounterModel
        let weak: [(AttributeKind, AttributeBand)] = [(.damage, .veryLow), (.range, .veryLow)]

        let declared = CapabilityResolver.resolve(profile: controller,
                                                  attributes: attributes(controller.key, weak),
                                                  model: model, anchors: .empty, balanceVersion: "p1")
        let undeclared = CapabilityResolver.resolve(profile: undeclaredAntiTank,
                                                    attributes: attributes(undeclaredAntiTank.key, weak),
                                                    model: model, anchors: .empty, balanceVersion: "p1")
        // The declared anti-tank scores a little higher on the same numbers…
        XCTAssertGreaterThan(declared.value(.tankCountering), undeclared.value(.tankCountering))
        // …but bad attributes still produce a bad score.
        XCTAssertLessThan(declared.value(.tankCountering), 0.5)
    }

    func testMissingAttributesLeaveOnlyIdentityContributions() {
        // With no balance data the attribute terms contribute nothing and
        // confidence is 0 — but identity still applies, because traits and
        // draft functions don't depend on the current patch.
        let resolved = CapabilityResolver.resolve(profile: undeclaredAntiTank, attributes: nil,
                                                  model: tankCounterModel, anchors: .empty,
                                                  balanceVersion: "unknown")
        XCTAssertEqual(resolved[.tankCountering].confidence, 0, accuracy: 0.0001,
                       "confidence reports attribute coverage only")
        // baseline 0.5 + piercing 0.05, and nothing from damage/range.
        XCTAssertEqual(resolved.value(.tankCountering), 0.55, accuracy: 0.0001)
        let labels = resolved[.tankCountering].contributions.map(\.label)
        XCTAssertEqual(labels, ["Baseline", "Piercing"])

        // A profile with no matching identity terms sits exactly on the baseline.
        let plain = BrawlerProfile(key: BrawlerKey("Testplain"))
        let neutral = CapabilityResolver.resolve(profile: plain, attributes: nil,
                                                 model: tankCounterModel, anchors: .empty,
                                                 balanceVersion: "unknown")
        XCTAssertEqual(neutral.value(.tankCountering), 0.5, accuracy: 0.0001)
    }

    func testResolutionIsDeterministicAndExplained() {
        let a = CapabilityResolver.resolve(profile: controller,
                                           attributes: attributes(controller.key, [(.damage, .high)]),
                                           model: tankCounterModel, anchors: .empty, balanceVersion: "p1")
        let b = CapabilityResolver.resolve(profile: controller,
                                           attributes: attributes(controller.key, [(.damage, .high)]),
                                           model: tankCounterModel, anchors: .empty, balanceVersion: "p1")
        XCTAssertEqual(a, b)
        XCTAssertFalse(a[.tankCountering].contributions.isEmpty, "every score must show its arithmetic")
        XCTAssertEqual(a[.tankCountering].value,
                       a[.tankCountering].contributions.reduce(0) { $0 + $1.amount },
                       accuracy: 0.0001,
                       "contributions must add up to the score")
    }

    func testUnresolvedCapabilityIsNeutral() {
        let empty = CapabilityResolver.resolve(profile: controller, attributes: nil,
                                               model: CapabilityModel(), anchors: .empty,
                                               balanceVersion: "unknown")
        XCTAssertEqual(empty[.burstPotential].value, 0.5, accuracy: 0.0001)
    }

    // MARK: - Interactions: traits + explicit overrides

    private var escapeRule: TraitInteractionRule {
        TraitInteractionRule(id: "escape-vs-immobile",
                             attackerTraits: [.escapeMobility],
                             defenderTraits: [.immobile, .slowProjectile],
                             polarity: .advantage, magnitude: 0.6,
                             rationale: "A repeatable escape beats a slow, immobile answer.")
    }

    func testTraitRuleProducesGeneralVerdict() {
        let model = InteractionModel(traitRules: [escapeRule])
        let verdict = model.verdict(for: .init(profile: diver), against: .init(profile: controller),
                                    model: CapabilityModel())
        XCTAssertEqual(verdict.polarity, .advantage)
        XCTAssertEqual(verdict.decidedBy, .traitRules)
        XCTAssertEqual(verdict.magnitude, 0.6, accuracy: 0.0001)
    }

    func testExplicitOverrideReplacesVerdictAndRetainsTraitEvidence() {
        let override = BrawlerMatchupOverride(attacker: diver.key, defender: controller.key,
                                              polarity: .disadvantage, magnitude: 0.4,
                                              rationale: "Specific kit interaction.")
        let model = InteractionModel(traitRules: [escapeRule], overrides: [override])
        let verdict = model.verdict(for: .init(profile: diver), against: .init(profile: controller),
                                    model: CapabilityModel())

        XCTAssertEqual(verdict.polarity, .disadvantage, "the override replaces the verdict")
        XCTAssertEqual(verdict.decidedBy, .explicitOverride)
        XCTAssertEqual(verdict.magnitude, 0.4, accuracy: 0.0001)

        // The trait-derived result is retained, marked superseded.
        let traitEvidence = verdict.evidence.filter { $0.source == .traitRules }
        XCTAssertEqual(traitEvidence.count, 1)
        XCTAssertTrue(traitEvidence[0].superseded)
        XCTAssertEqual(traitEvidence[0].polarity, .advantage,
                       "we can still say what the general model expected")
        XCTAssertTrue(verdict.evidence.contains { $0.source == .explicitOverride && !$0.superseded })
    }

    func testCapabilitiesChangeMagnitudeNotDirection() {
        let rule = TraitInteractionRule(id: "scaled", attackerTraits: [.escapeMobility],
                                        defenderTraits: [.immobile, .slowProjectile],
                                        polarity: .advantage, magnitude: 0.5,
                                        magnitudeCapability: .burstPotential,
                                        rationale: "Severity scales with burst.")
        let interactions = InteractionModel(traitRules: [rule])
        let capModel = CapabilityModel(interactionModulation: 0.5)

        func set(_ key: BrawlerKey, burst: Double) -> CapabilitySet {
            var scores = TermMap<Capability, CapabilityScore>()
            scores[.burstPotential] = CapabilityScore(value: burst, confidence: 1)
            return CapabilitySet(key: key, balanceVersion: "p1", modelVersion: 1, scores: scores)
        }

        let plain = interactions.verdict(for: .init(profile: diver),
                                         against: .init(profile: controller), model: capModel)
        let amplified = interactions.verdict(
            for: .init(profile: diver, capabilities: set(diver.key, burst: 1.0)),
            against: .init(profile: controller, capabilities: set(controller.key, burst: 0.0)),
            model: capModel)
        let damped = interactions.verdict(
            for: .init(profile: diver, capabilities: set(diver.key, burst: 0.0)),
            against: .init(profile: controller, capabilities: set(controller.key, burst: 1.0)),
            model: capModel)

        XCTAssertEqual(plain.polarity, .advantage)
        XCTAssertEqual(amplified.polarity, .advantage, "direction must not change")
        XCTAssertEqual(damped.polarity, .advantage, "direction must not change")
        XCTAssertGreaterThan(amplified.magnitude, plain.magnitude)
        XCTAssertLessThan(damped.magnitude, plain.magnitude)
    }

    func testScopedOverrideBeatsUnscopedOne() {
        let global = BrawlerMatchupOverride(attacker: diver.key, defender: controller.key,
                                            polarity: .advantage, magnitude: 0.3)
        let onHeist = BrawlerMatchupOverride(attacker: diver.key, defender: controller.key,
                                             polarity: .disadvantage, magnitude: 0.8,
                                             scope: InteractionScope(mode: "Heist"))
        let model = InteractionModel(overrides: [global, onHeist])
        XCTAssertEqual(model.override(attacker: diver.key, defender: controller.key,
                                      mode: "Heist")?.polarity, .disadvantage)
        XCTAssertEqual(model.override(attacker: diver.key, defender: controller.key,
                                      mode: "Bounty")?.polarity, .advantage)
    }

    func testNoRulesMeansNeutralNotAnError() {
        let verdict = InteractionModel().verdict(for: .init(profile: diver),
                                                 against: .init(profile: controller),
                                                 model: CapabilityModel())
        XCTAssertEqual(verdict.polarity, .neutral)
        XCTAssertEqual(verdict.decidedBy, .none)
        XCTAssertEqual(verdict.signed, 0, accuracy: 0.0001)
    }

    // MARK: - RankedSeason

    func testRankedSeasonIsUsableWithNoReferencesYet() {
        let season = RankedSeason(name: "September 2026")
        XCTAssertTrue(season.isActive)
        XCTAssertFalse(season.isFullyConfigured)
        XCTAssertEqual(season.unresolvedReferences,
                       ["balance version", "tier list", "map pool", "mode rotation"])
    }

    func testRankedSeasonCarriesEveryDynamicReference() throws {
        let tierList = UUID(), pool = UUID()
        let season = RankedSeason(name: "S1", balanceVersion: "2026.09",
                                  tierListID: tierList, mapPoolID: pool, modeRotation: [1, 2, 3])
        let round = try JSONDecoder().decode(RankedSeason.self, from: JSONEncoder().encode(season))
        XCTAssertEqual(round.balanceVersion, "2026.09")
        XCTAssertEqual(round.tierListID, tierList)
        XCTAssertEqual(round.mapPoolID, pool)
        XCTAssertEqual(round.modeRotation, [1, 2, 3])
        XCTAssertTrue(round.isFullyConfigured)
    }

    // MARK: - Coverage reporting (partial data must be survivable)

    func testMissingProfilesAndAttributesAreReportedNotFatal() {
        let profiles = BrawlerProfileSet(profiles: [controller, diver])
        XCTAssertEqual(profiles.missingProfiles(in: ["Testlou", "Brandnew"]), ["Brandnew"])

        let balance = BalanceState(version: "p1",
                                   attributes: [attributes(controller.key, [(.damage, .high)])])
        XCTAssertEqual(balance.missingAttributes(in: profiles), [diver.key.normalized])

        // Resolving the whole roster still succeeds despite the gap.
        let all = CapabilityResolver.resolveAll(profiles: profiles, balance: balance,
                                                model: tankCounterModel)
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all[diver.key]?[.tankCountering].confidence, 0)
    }
}
