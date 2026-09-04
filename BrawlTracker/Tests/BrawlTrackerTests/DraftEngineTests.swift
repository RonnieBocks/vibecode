import XCTest
@testable import BrawlTracker

final class DraftEngineTests: XCTestCase {
    private let roster = [
        TierBrawler(id: 1, name: "Crow"),     // anti-tank
        TierBrawler(id: 2, name: "Mortis"),   // space maker
        TierBrawler(id: 3, name: "Tick"),     // thrower
        TierBrawler(id: 4, name: "Piper"),    // sniper
        TierBrawler(id: 5, name: "Frank"),    // tank
    ]

    private func ctx(mode: String, tiers: [Int: Int] = [:], eligible: Set<Int>, enemy: [DraftClass] = [],
                     mine: [DraftClass] = []) -> DraftContext {
        DraftContext(mode: mode, roster: roster,
                     tierScore: { tiers[$0] ?? 0 },
                     tierLabel: { id in tiers[id].map { ["", "D", "C", "B", "A", "S"][$0] } },
                     eligibleIDs: eligible, banned: [], picked: [], myTeamClasses: mine, enemyClasses: enemy)
    }

    func testAggroFirstPickPrefersAntiTankOverHigherTierThrower() {
        // Tick is S tier, Crow is B tier — role must win.
        let c = ctx(mode: "Brawl Ball", tiers: [3: 5, 1: 3], eligible: [1, 2, 3, 4, 5])
        let advice = DraftEngine.pickAdvice(c, globalPick: 1)
        XCTAssertEqual(advice.suggestions.first?.brawler.name, "Crow")
        XCTAssertEqual(advice.targetClasses, [.antiTank])
    }

    func testEligibilityBeatsTier() {
        // Only Piper is eligible; Crow is S tier but not eligible.
        let c = ctx(mode: "Brawl Ball", tiers: [1: 5], eligible: [4])
        let advice = DraftEngine.pickAdvice(c, globalPick: 1)
        XCTAssertEqual(advice.suggestions.first?.brawler.name, "Piper")
        XCTAssertTrue(advice.suggestions.first?.eligible ?? false)
    }

    func testCounterSlotReadsEnemyComp() {
        // Enemy has no anti-tank: last pick should target tank / space maker.
        let c = ctx(mode: "Gem Grab", eligible: [1, 2, 3, 4, 5], enemy: [.sniper, .thrower, .control])
        let advice = DraftEngine.pickAdvice(c, globalPick: 6)
        XCTAssertTrue(advice.targetClasses.contains(.tank) || advice.targetClasses.contains(.spaceMaker))
    }

    func testBansAreRoleFirst() {
        let c = ctx(mode: "Hot Zone", tiers: [3: 5, 1: 2], eligible: [])
        let bans = DraftEngine.banSuggestions(c, limit: 2)
        XCTAssertEqual(bans.first?.draftClass, .antiTank)
    }

    func testWinProbabilityIsBoundedAndMovesWithComp() {
        let strong = [WinProbability.Pick(cls: .antiTank, tier: 5, personal: 0.7),
                      WinProbability.Pick(cls: .spaceMaker, tier: 5, personal: nil)]
        let weak = [WinProbability.Pick(cls: .thrower, tier: 1, personal: nil)]
        // With enough logged matches the estimate leans toward the better comp…
        let p = WinProbability.estimate(meta: .aggro, mine: strong, enemy: weak, wonToss: true,
                                        baseline: nil, loggedMatches: 50)
        XCTAssertGreaterThan(p.probability, 0.5)
        XCTAssertLessThanOrEqual(p.probability, DraftWeights().wpClampMax)
        let q = WinProbability.estimate(meta: .aggro, mine: weak, enemy: strong, wonToss: false,
                                        baseline: nil, loggedMatches: 50)
        XCTAssertLessThan(q.probability, 0.5)
        // …and with no history at all it refuses to guess.
        let none = WinProbability.estimate(meta: .aggro, mine: strong, enemy: weak, wonToss: true,
                                           baseline: nil, loggedMatches: 0)
        XCTAssertEqual(none.probability, 0.5, accuracy: 0.001)
    }
}

final class CalibrationTests: XCTestCase {
    override func setUp() { DraftPlaybook.config = .defaults }

    private let strong = [WinProbability.Pick(cls: .antiTank, tier: 5, personal: 0.8),
                          WinProbability.Pick(cls: .antiTank, tier: 5, personal: nil),
                          WinProbability.Pick(cls: .spaceMaker, tier: 5, personal: nil)]
    private let weak = [WinProbability.Pick(cls: .sniper, tier: 1, personal: nil),
                        WinProbability.Pick(cls: .thrower, tier: 1, personal: nil),
                        WinProbability.Pick(cls: .control, tier: 1, personal: nil)]

    func testExtremeCompsStayInsideClamp() {
        // The 95%-then-lost case: role theory must not produce near-certainty.
        let p = WinProbability.estimate(meta: .aggro, mine: strong, enemy: weak, wonToss: true,
                                        baseline: nil, loggedMatches: 17).probability
        XCTAssertLessThanOrEqual(p, DraftWeights().wpClampMax)
        XCTAssertGreaterThanOrEqual(p, DraftWeights().wpClampMin)
        XCTAssertLessThan(p, 0.80, "with few logged matches the model must stay humble")
    }

    func testConfidenceGrowsWithLoggedMatches() {
        let few = WinProbability.estimate(meta: .aggro, mine: strong, enemy: weak, wonToss: true, baseline: nil, loggedMatches: 5)
        let many = WinProbability.estimate(meta: .aggro, mine: strong, enemy: weak, wonToss: true, baseline: nil, loggedMatches: 50)
        XCTAssertLessThan(few.confidence, many.confidence)
        XCTAssertLessThan(abs(few.probability - 0.5), abs(many.probability - 0.5))
    }

    func testPersonalResultsCanOutrankSameRolePeer() {
        // Two anti-tanks, same tier: the one you actually win with must rank first.
        let roster = [TierBrawler(id: 1, name: "Crow"), TierBrawler(id: 2, name: "Otis")]
        let ctx = DraftContext(mode: "Brawl Ball", roster: roster,
                               tierScore: { _ in 4 }, tierLabel: { _ in "A" },
                               eligibleIDs: [1, 2],
                               personal: { id in
                                   id == 2 ? PersonalStat(rate: 0.75, games: 10, label: "75% for you")
                                           : PersonalStat(rate: 0.25, games: 10, label: "25% for you")
                               })
        let advice = DraftEngine.pickAdvice(ctx, globalPick: 1)
        XCTAssertEqual(advice.suggestions.first?.brawler.name, "Otis")
    }

    func testConfigDecodesWhenNewKeysAreMissing() {
        // A v1 file must still load (and keep customisations) after new weights are added.
        let legacy = #"{"version":1,"weights":{"pickRoleMatch":1234,"wpSigmoidK":2.4,"pickPersonalMax":250},"playbook":{"modeMeta":{"heist":"Aggro"},"dominantAggro":[],"dominantPassive":[],"targetsAggro":[],"targetsPassive":[],"callouts":{},"classOverrides":{"crow":"Tank"}}}"#
        let cfg = try! JSONDecoder().decode(DraftConfig.self, from: Data(legacy.utf8))
        XCTAssertEqual(cfg.weights.pickRoleMatch, 1234)                 // customisation kept
        XCTAssertEqual(cfg.weights.wpClampMax, DraftWeights().wpClampMax) // new key defaulted
        XCTAssertEqual(cfg.playbook.classOverrides["crow"], .tank)       // overrides kept
        XCTAssertEqual(cfg.version, 1)                                   // so migration can run
    }
}

final class PerspectiveTests: XCTestCase {
    override func setUp() { DraftPlaybook.config = .defaults }

    private let roster = [
        TierBrawler(id: 1, name: "Crow"),    // anti-tank
        TierBrawler(id: 2, name: "Mortis"),  // space maker
        TierBrawler(id: 3, name: "Tick"),    // thrower
    ]

    /// Only id 3 is in YOUR eligible roster.
    private func ctx(mine: [DraftClass] = [], enemy: [DraftClass] = []) -> DraftContext {
        DraftContext(mode: "Brawl Ball", roster: roster,
                     tierScore: { _ in 3 }, tierLabel: { _ in "B" },
                     eligibleIDs: [3], myTeamClasses: mine, enemyClasses: enemy)
    }

    func testTeammateAdviceIgnoresYourEligibility() {
        // For you, the thrower is the only eligible option and wins by default.
        XCTAssertEqual(DraftEngine.pickAdvice(ctx(), globalPick: 1, perspective: .you)
            .suggestions.first?.brawler.name, "Tick")
        // For a teammate, eligibility is irrelevant: role must win.
        let mate = DraftEngine.pickAdvice(ctx(), globalPick: 1, perspective: .teammate)
        XCTAssertEqual(mate.suggestions.first?.brawler.name, "Crow")
        XCTAssertFalse(mate.suggestions.first?.reason.contains("Eligible") ?? true)
    }

    func testEnemyAdviceReadsTheirSideOfTheBoard() {
        // Last pick. Your team has no anti-tank, so THEIR counter slot should
        // want a tank/space maker against you, judged from their side.
        let advice = DraftEngine.pickAdvice(ctx(mine: [.sniper, .thrower], enemy: [.control]),
                                            globalPick: 6, perspective: .enemy)
        XCTAssertTrue(advice.targetClasses.contains(.spaceMaker) || advice.targetClasses.contains(.tank))
    }

    func testStackPenaltyFollowsThePickingSide() {
        // Enemy already has two space makers: a third must not be their top pick.
        let advice = DraftEngine.pickAdvice(ctx(mine: [], enemy: [.spaceMaker, .spaceMaker]),
                                            globalPick: 4, perspective: .enemy)
        XCTAssertNotEqual(advice.suggestions.first?.draftClass, .spaceMaker)
    }
}

final class DataBalanceTests: XCTestCase {
    override func setUp() { DraftPlaybook.config = .defaults }

    private func battle(_ id: String, mine: String, allies: [String], opponents: [String],
                        won: Bool, daysAgo: Double = 0) -> BattleRecord {
        BattleRecord(id: id, time: Date().addingTimeInterval(-daysAgo * 86400),
                     mode: "brawlBall", map: "Center Stage", type: "soloRanked",
                     outcome: won ? .win : .loss, trophyChange: 0, myBrawler: mine,
                     starPlayer: false, isRanked: true, showdownRank: nil,
                     allies: allies, opponents: opponents)
    }

    func testOpponentsAndAlliesBuildTheirOwnRecords() {
        // You always play Pearl; Crow only ever appears on the enemy team and wins.
        let games = (0..<6).map { i in
            battle("g\(i)", mine: "PEARL", allies: ["MAX"], opponents: ["CROW", "OTIS", "BULL"], won: false)
        }
        let l = DraftLearning(archive: games, matches: [])
        let crow = l.observedRate(brawler: "Crow")
        XCTAssertNotNil(crow, "a brawler you never play must still build a record")
        XCTAssertGreaterThan(crow!.rate, 0.5, "Crow won every game it appeared in")
        let max = l.observedRate(brawler: "Max")
        XCTAssertLessThan(max!.rate, 0.5, "your teammate shared your losses")
        // And your own brawler is still tracked personally.
        XCTAssertNotNil(l.stat(brawler: "Pearl", mode: "Brawl Ball", map: nil))
    }

    func testCoverageCountsEveryBrawlerNotJustYours() {
        let games = (0..<4).map { i in
            battle("g\(i)", mine: "PEARL", allies: ["MAX"], opponents: ["CROW", "OTIS", "BULL"], won: i % 2 == 0)
        }
        let cov = DraftLearning(archive: games, matches: []).coverage()
        XCTAssertEqual(cov.brawlersSeen, 5)                      // Pearl, Max, Crow, Otis, Bull
        XCTAssertGreaterThan(cov.observedGames, cov.yourGames)   // not lopsided toward your mains
    }

    func testObservedRecordFillsInWhenYouHaveNoHistory() {
        // Two anti-tanks, no personal history with either; the one that keeps
        // winning in games you've seen should rank first.
        let roster = [TierBrawler(id: 1, name: "Crow"), TierBrawler(id: 2, name: "Otis")]
        let ctx = DraftContext(mode: "Brawl Ball", roster: roster,
                               tierScore: { _ in 3 }, tierLabel: { _ in "B" }, eligibleIDs: [1, 2],
                               observed: { id in
                                   id == 1 ? PersonalStat(rate: 0.75, games: 12, label: "wins 75%")
                                           : PersonalStat(rate: 0.25, games: 12, label: "wins 25%")
                               })
        XCTAssertEqual(DraftEngine.pickAdvice(ctx, globalPick: 1).suggestions.first?.brawler.name, "Crow")
    }

    func testPersonalHistoryStillOutranksObserved() {
        let roster = [TierBrawler(id: 1, name: "Crow"), TierBrawler(id: 2, name: "Otis")]
        let ctx = DraftContext(mode: "Brawl Ball", roster: roster,
                               tierScore: { _ in 3 }, tierLabel: { _ in "B" }, eligibleIDs: [1, 2],
                               personal: { id in
                                   id == 2 ? PersonalStat(rate: 0.80, games: 12, label: "80% for you") : nil
                               },
                               observed: { id in
                                   id == 1 ? PersonalStat(rate: 0.75, games: 12, label: "wins 75%") : nil
                               })
        XCTAssertEqual(DraftEngine.pickAdvice(ctx, globalPick: 1).suggestions.first?.brawler.name, "Otis")
    }
}

final class BackupSwapTests: XCTestCase {
    override func setUp() { DraftPlaybook.config = .defaults }

    private let roster = [
        TierBrawler(id: 1, name: "Crow"),    // anti-tank
        TierBrawler(id: 2, name: "Otis"),    // anti-tank
        TierBrawler(id: 3, name: "Mortis"),  // space maker
        TierBrawler(id: 4, name: "Frank"),   // tank
        TierBrawler(id: 5, name: "Tick"),    // thrower
    ]

    private func ctx(mine: [DraftClass], enemy: [DraftClass] = [.control]) -> DraftContext {
        DraftContext(mode: "Brawl Ball", roster: roster, tierScore: { _ in 3 }, tierLabel: { _ in "B" },
                     eligibleIDs: [1, 2, 3, 4, 5], myTeamClasses: mine, enemyClasses: enemy)
    }

    func testSlotRoleTakenByTeammateSwapsToAGap() {
        // Aggro 1st slot wants an anti-tank, but a teammate already has one.
        let advice = DraftEngine.pickAdvice(ctx(mine: [.antiTank]), globalPick: 1)
        XCTAssertFalse(advice.targetClasses.contains(.antiTank), "shouldn't re-target a covered role")
        XCTAssertTrue(advice.targetClasses.contains(.spaceMaker), "should fill the next key role")
        XCTAssertEqual(advice.suggestions.first?.draftClass, .spaceMaker)
        XCTAssertTrue(advice.guidance.contains("already covered"), "the swap should be explained")
    }

    func testNoSwapWhileTheSlotStillHasAnUncoveredTarget() {
        // 2–3 wants anti-tank OR space maker; only anti-tank is taken, so the
        // slot still has work to do and must not jump to a backup role.
        let advice = DraftEngine.pickAdvice(ctx(mine: [.antiTank]), globalPick: 2)
        XCTAssertTrue(advice.targetClasses.contains(.spaceMaker))
        XCTAssertFalse(advice.guidance.contains("already covered"))
    }

    func testSwapPrefersMissingKeyRoleOverDoublingUp() {
        // Both of 4–5's targets are covered; the comp still lacks a control pick.
        let advice = DraftEngine.pickAdvice(ctx(mine: [.antiTank, .spaceMaker, .tank]), globalPick: 4)
        XCTAssertFalse(advice.targetClasses.contains(.spaceMaker))
        XCTAssertFalse(advice.targetClasses.contains(.tank))
        XCTAssertTrue(advice.targetClasses.contains(.control))
    }

    func testPassiveMetaSwapsWithinItsOwnKeyRoles() {
        let c = DraftContext(mode: "Knockout", roster: roster, tierScore: { _ in 3 }, tierLabel: { _ in "B" },
                             eligibleIDs: [1, 2, 3, 4, 5], myTeamClasses: [.control], enemyClasses: [.tank])
        let advice = DraftEngine.pickAdvice(c, globalPick: 1)
        XCTAssertFalse(advice.targetClasses.contains(.control))
        XCTAssertTrue(advice.targetClasses.contains(.sniper) || advice.targetClasses.contains(.antiTank))
    }
}

final class ChecklistAndMatchupTests: XCTestCase {
    override func setUp() { DraftPlaybook.config = .defaults }

    private func own(_ picks: [(Int, Int, String?)]) -> [DraftChecklist.OwnPick] {
        picks.map { DraftChecklist.OwnPick(seat: $0.0, globalPick: $0.1, brawler: $0.2) }
    }

    func testWonkyOrderStillCountsAsCorrect() {
        // Space maker went first, anti-tank fourth: both boxes ticked, no order complaint.
        let r = DraftChecklist.build(mode: "Gem Grab",
                                     own: own([(0, 1, "Mortis"), (1, 4, "Crow"), (2, 5, nil)]),
                                     enemyClasses: [])
        XCTAssertEqual(r.items[0].status, .done)          // Anti-Tank ← Crow
        XCTAssertEqual(r.items[0].filledBy?.brawler, "Crow")
        XCTAssertEqual(r.items[1].status, .done)          // Space Maker ← Mortis
        XCTAssertEqual(r.items[2].assignedSeat, 2)        // third role → the seat still to pick
        XCTAssertTrue(r.warnings.contains { $0.contains("First pick") }, "still flags the risky first pick")
        XCTAssertFalse(r.warnings.contains { $0.contains("covers none") })
    }

    func testUnmetRolesPointAtNextSeatsInPickOrder() {
        let r = DraftChecklist.build(mode: "Brawl Ball",
                                     own: own([(0, 1, nil), (1, 4, nil), (2, 5, nil)]),
                                     enemyClasses: [])
        XCTAssertEqual(r.items.map(\.assignedSeat), [0, 1, 2])
        XCTAssertTrue(r.items.allSatisfy { $0.status == .pending })
    }

    func testUnfillableWhenSeatsRunOut() {
        // Two throwers picked: neither covers a core aggro role, one seat left for three needs.
        let r = DraftChecklist.build(mode: "Heist",
                                     own: own([(0, 1, "Tick"), (1, 4, "Barley"), (2, 5, nil)]),
                                     enemyClasses: [])
        XCTAssertEqual(r.items.filter { $0.status == .unfillable }.count, 2)
        XCTAssertTrue(r.warnings.contains { $0.contains("Not enough seats") })
    }

    func testEnginePenalisesWalkingIntoACounter() {
        // Enemy has two throwers. A tank (beaten by throwers) must rank below a
        // space maker (beats throwers), even though both are 4–5 targets.
        let roster = [TierBrawler(id: 1, name: "Frank"), TierBrawler(id: 2, name: "Mortis")]
        let ctx = DraftContext(mode: "Brawl Ball", roster: roster, tierScore: { _ in 3 }, tierLabel: { _ in "B" },
                               eligibleIDs: [1, 2], myTeamClasses: [.antiTank],
                               enemyClasses: [.thrower, .thrower], enemyNames: ["Tick", "Barley"])
        let advice = DraftEngine.pickAdvice(ctx, globalPick: 4)
        XCTAssertEqual(advice.suggestions.first?.brawler.name, "Mortis")
        XCTAssertTrue(advice.suggestions.first?.reason.contains("counters Tick/Barley") ?? false)
        XCTAssertTrue(advice.suggestions.last?.reason.contains("countered by") ?? false)
    }

    func testMissingTopRoleLeadsTargetsEvenMidDraft() {
        // 4–5 slot normally wants space maker / tank, but with no anti-tank yet it must come first.
        let roster = [TierBrawler(id: 1, name: "Crow"), TierBrawler(id: 2, name: "Mortis")]
        let ctx = DraftContext(mode: "Hot Zone", roster: roster, tierScore: { _ in 3 }, tierLabel: { _ in "B" },
                               eligibleIDs: [1, 2], myTeamClasses: [.control], enemyClasses: [])
        let advice = DraftEngine.pickAdvice(ctx, globalPick: 4)
        XCTAssertEqual(advice.targetClasses.first, .antiTank)
        XCTAssertEqual(advice.suggestions.first?.brawler.name, "Crow")
        XCTAssertTrue(advice.guidance.contains("still has no Anti-Tank"))
    }
}
