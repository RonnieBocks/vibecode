import XCTest
@testable import BrawlTracker

final class UpgradeCostsTests: XCTestCase {
    private func brawler(power: Int, gadgets: Int, sps: Int, gears: Int, hyper: Bool, buffies: Int) -> Brawler {
        func list(_ item: String, _ n: Int) -> String { "[" + Array(repeating: item, count: n).joined(separator: ",") + "]" }
        let json = """
        {"id":16000000,"name":"SHELLY","power":\(power),"rank":5,"trophies":1000,"highestTrophies":1000,
         "gadgets":\(list(#"{"id":1,"name":"G"}"#, gadgets)),
         "starPowers":\(list(#"{"id":2,"name":"S"}"#, sps)),
         "gears":\(list(#"{"id":62000000,"name":"SPEED","level":3}"#, gears)),
         "hyperCharges":\(hyper ? #"[{"id":3,"name":"H"}]"# : "[]"),
         "buffies":{"gadget":\(buffies > 0),"starPower":\(buffies > 1),"hyperCharge":\(buffies > 2)}}
        """
        return try! JSONDecoder().decode(Brawler.self, from: Data(json.utf8))
    }

    func testLevelLadderTotals() {
        let c = UpgradeCosts.levelCost(from: 1, to: 11)
        XCTAssertEqual(c.powerPoints, 3740)
        XCTAssertEqual(c.coins, 7765)
        XCTAssertEqual(UpgradeCosts.levelCost(from: 11, to: 11).coins, 0)
    }

    func testSpentMatchesItemizedLines() {
        let b = brawler(power: 9, gadgets: 1, sps: 2, gears: 2, hyper: false, buffies: 1)
        let total = UpgradeCosts.spent(on: b)
        let lines = UpgradeCosts.spentLines(on: b).reduce(ResourceCost()) { $0 + $1.cost }
        XCTAssertEqual(total, lines)
        XCTAssertEqual(total.coins, UpgradeCosts.levelCost(from: 1, to: 9).coins + 1000 + 4000 + 2000 + 1000)
    }

    func testEligibleAndMaxRemaining() {
        let b = brawler(power: 9, gadgets: 0, sps: 1, gears: 1, hyper: false, buffies: 0)
        let e = UpgradeCosts.toRankedEligible(b)
        XCTAssertEqual(e.coins, UpgradeCosts.levelCost(from: 9, to: 11).coins + 1000 + 1000 + 5000)
        XCTAssertEqual(UpgradeCosts.eligibleLines(b).reduce(ResourceCost()) { $0 + $1.cost }, e)
        let m = UpgradeCosts.toMax(b, reference: nil)
        XCTAssertEqual(m.powerPoints, UpgradeCosts.levelCost(from: 9, to: 11).powerPoints + 3 * 2000)
        let maxed = brawler(power: 11, gadgets: 2, sps: 2, gears: 6, hyper: true, buffies: 3)
        XCTAssertTrue(UpgradeCosts.toMax(maxed, reference: nil).isZero)
        XCTAssertTrue(UpgradeCosts.toRankedEligible(maxed).isZero)
    }
}
