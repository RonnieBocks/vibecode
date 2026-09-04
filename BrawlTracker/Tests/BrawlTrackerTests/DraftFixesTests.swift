import XCTest
@testable import BrawlTracker

/// Covers the four fixes made after reviewing the annotated match log:
/// ban/pick conflicts, unclassified brawlers, win-chance calibration, and
/// series cut short by a crash.
final class DraftFixesTests: XCTestCase {
    private let roster = [
        TierBrawler(id: 1, name: "Crow"),     // anti-tank
        TierBrawler(id: 2, name: "Mortis"),   // space maker
        TierBrawler(id: 3, name: "Tick"),     // thrower
        TierBrawler(id: 4, name: "Piper"),    // sniper
        TierBrawler(id: 5, name: "Frank"),    // tank
    ]

    private func ctx(mode: String, tiers: [Int: Int] = [:], eligible: Set<Int>,
                     extra: [TierBrawler] = []) -> DraftContext {
        DraftContext(mode: mode, roster: roster + extra,
                     tierScore: { tiers[$0] ?? 0 },
                     tierLabel: { id in tiers[id].map { ["", "D", "C", "B", "A", "S"][$0] } },
                     eligibleIDs: eligible)
    }

    // MARK: - Ban/pick conflict

    func testBanAdviceDoesNotDenyYourOwnBestPick() {
        // Aggro first pick wants an anti-tank (Crow). Not knowing your slot, the
        // ban list also leads with Crow — denying you the pick it's about to
        // recommend. This is the Lou-on-Hot-Zone case from the match log.
        var c = ctx(mode: "Brawl Ball", tiers: [1: 5], eligible: [1, 2, 3, 4, 5])
        XCTAssertEqual(DraftEngine.pickAdvice(c, globalPick: 1).suggestions.first?.brawler.name, "Crow")
        XCTAssertEqual(DraftEngine.banSuggestions(c).first?.brawler.name, "Crow")

        c.myGlobalPick = 1
        let bans = DraftEngine.banSuggestions(c)
        XCTAssertNotEqual(bans.first?.brawler.name, "Crow",
                          "shouldn't recommend banning a brawler it also wants you to pick")
        let crow = bans.first { $0.brawler.name == "Crow" }
        XCTAssertTrue(crow?.components.contains { $0.0.contains("want this pick") } ?? false,
                      "the demotion should be visible in the reasoning")
    }

    func testBanAdviceUnchangedWhenYourSlotIsUnknown() {
        let c = ctx(mode: "Brawl Ball", tiers: [1: 5], eligible: [1, 2, 3, 4, 5])
        XCTAssertNil(c.myGlobalPick)
        XCTAssertEqual(DraftEngine.banSuggestions(c).first?.brawler.name, "Crow")
    }

    // MARK: - Unclassified brawlers

    func testUnclassifiedBrawlerStillScores() {
        let newcomer = TierBrawler(id: 99, name: "Zzzznewbrawler")
        XCTAssertEqual(DraftPlaybook.draftClass(for: newcomer.name), .unknown)
        XCTAssertGreaterThan(DraftEngine.roleWeight(.unknown, meta: .aggro), 0,
                             "no class must not mean no score")

        let c = ctx(mode: "Brawl Ball", tiers: [99: 5], eligible: [99], extra: [newcomer])
        XCTAssertTrue(DraftEngine.pickAdvice(c, globalPick: 1).suggestions.contains { $0.brawler.id == 99 },
                      "an S-tier unclassified brawler should still be suggestable")
    }

    // MARK: - Win-chance calibration

    func testCalibrationPullsDownAHotModel() {
        let mine = [WinProbability.Pick(cls: .antiTank, tier: 5, personal: 0.7)]
        let enemy = [WinProbability.Pick(cls: .support, tier: 1, personal: nil)]
        func est(_ cal: (bias: Double, samples: Int)?) -> Double {
            WinProbability.estimate(meta: .aggro, mine: mine, enemy: enemy, wonToss: true,
                                    baseline: nil, loggedMatches: 100, calibration: cal).probability
        }
        let raw = est(nil), corrected = est((bias: 0.08, samples: 32))
        XCTAssertLessThan(corrected, raw)
        XCTAssertEqual(raw - corrected, 0.08, accuracy: 0.001)
    }

    func testCalibrationIgnoredOnTinySamples() {
        let mine = [WinProbability.Pick(cls: .antiTank, tier: 4, personal: nil)]
        func est(_ cal: (bias: Double, samples: Int)?) -> Double {
            WinProbability.estimate(meta: .aggro, mine: mine, enemy: [], wonToss: false,
                                    baseline: nil, loggedMatches: 100, calibration: cal).probability
        }
        XCTAssertEqual(est(nil), est((bias: 0.08, samples: 3)), accuracy: 0.0001)
    }

    func testCalibrationCorrectsAColdModelUpward() {
        let mine = [WinProbability.Pick(cls: .thrower, tier: 1, personal: nil)]
        let enemy = [WinProbability.Pick(cls: .antiTank, tier: 5, personal: nil)]
        func est(_ cal: (bias: Double, samples: Int)?) -> Double {
            WinProbability.estimate(meta: .aggro, mine: mine, enemy: enemy, wonToss: false,
                                    baseline: nil, loggedMatches: 100, calibration: cal).probability
        }
        XCTAssertGreaterThan(est((bias: -0.06, samples: 40)), est(nil))
    }

    // MARK: - Incomplete series

    func testIncompleteSeriesKeepsGamesButDropsVerdict() {
        var m = MatchRecord(id: UUID(), date: Date(), mode: "Heist", mapName: "Safe Zone",
                            myTeam: [], enemyTeam: [], bans: [], series: [.loss, .none, .none],
                            wonToss: true, mySlot: 1)
        XCTAssertTrue(m.countsForRecord)
        m.incomplete = true
        XCTAssertFalse(m.countsForRecord, "a crashed series shouldn't count as a loss")
        XCTAssertEqual(m.gamesPlayed, 1, "the game that was played is still real data")
        XCTAssertEqual(m.losses, 1)
    }

    func testOlderRecordsDefaultToComplete() {
        let m = MatchRecord(id: UUID(), date: Date(), mode: "Bounty", mapName: "Layer Cake",
                            myTeam: [], enemyTeam: [], bans: [], series: [.win, .loss, .win],
                            wonToss: true, mySlot: 3)
        XCTAssertNil(m.incomplete)
        XCTAssertTrue(m.countsForRecord)
        XCTAssertTrue(m.seriesWon)
    }
}
