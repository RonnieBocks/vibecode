import Foundation

/// Coins + power points.
struct ResourceCost: Equatable {
    var coins: Int = 0
    var powerPoints: Int = 0
    static func + (a: ResourceCost, b: ResourceCost) -> ResourceCost {
        ResourceCost(coins: a.coins + b.coins, powerPoints: a.powerPoints + b.powerPoints)
    }
    var isZero: Bool { coins == 0 && powerPoints == 0 }
}

/// One labelled line of a cost breakdown ("Power 9 → 11", "Gear ×2", …).
struct CostLine: Identifiable {
    let label: String
    let cost: ResourceCost
    var id: String { label }
}

/// Brawl Stars upgrade economics. Power-level steps are the long-standing
/// in-game values (1→2 through 10→11); item prices per the user's spec.
enum UpgradeCosts {
    /// Index 0 = level 1→2 … index 9 = level 10→11.
    static let levelSteps: [(pp: Int, coins: Int)] = [
        (20, 20), (30, 35), (50, 75), (80, 140), (130, 290),
        (210, 480), (340, 800), (550, 1250), (890, 1875), (1440, 2800),
    ]
    static let maxPower = 11
    static let gadgetCoins = 1000
    static let starPowerCoins = 2000
    static let gearCoins = 1000
    static let hyperchargeCoins = 5000
    static let buffyCoins = 1000
    static let buffyPowerPoints = 2000
    static let standardGearCount = 6
    static let totalBuffies = 3

    /// Total cost to climb from `from` to `to` (each ≤ 11).
    static func levelCost(from: Int, to: Int) -> ResourceCost {
        var c = ResourceCost()
        let lo = max(1, from), hi = min(to, maxPower)
        guard hi > lo else { return c }
        for lvl in lo..<hi {
            let s = levelSteps[lvl - 1]
            c.coins += s.coins
            c.powerPoints += s.pp
        }
        return c
    }

    static func ownedBuffies(_ b: Brawler) -> Int {
        guard let f = b.buffies else { return 0 }
        return [f.gadget, f.starPower, f.hyperCharge].filter { $0 }.count
    }

    // MARK: - Itemized breakdowns

    static func spentLines(on b: Brawler) -> [CostLine] {
        var lines: [CostLine] = []
        if b.power > 1 { lines.append(CostLine(label: "Power 1 → \(b.power)", cost: levelCost(from: 1, to: b.power))) }
        if !b.gadgets.isEmpty { lines.append(CostLine(label: "Gadget ×\(b.gadgets.count)", cost: ResourceCost(coins: b.gadgets.count * gadgetCoins))) }
        if !b.starPowers.isEmpty { lines.append(CostLine(label: "Star power ×\(b.starPowers.count)", cost: ResourceCost(coins: b.starPowers.count * starPowerCoins))) }
        if !b.gears.isEmpty { lines.append(CostLine(label: "Gear ×\(b.gears.count)", cost: ResourceCost(coins: b.gears.count * gearCoins))) }
        if !b.hyperCharges.isEmpty { lines.append(CostLine(label: "Hypercharge", cost: ResourceCost(coins: hyperchargeCoins))) }
        let buffies = ownedBuffies(b)
        if buffies > 0 { lines.append(CostLine(label: "Buffy ×\(buffies)", cost: ResourceCost(coins: buffies * buffyCoins, powerPoints: buffies * buffyPowerPoints))) }
        return lines
    }

    static func eligibleLines(_ b: Brawler) -> [CostLine] {
        var lines: [CostLine] = []
        if b.power < maxPower { lines.append(CostLine(label: "Power \(b.power) → 11 (hyper needs 11)", cost: levelCost(from: b.power, to: maxPower))) }
        if b.gadgets.isEmpty { lines.append(CostLine(label: "Gadget ×1", cost: ResourceCost(coins: gadgetCoins))) }
        if b.starPowers.isEmpty { lines.append(CostLine(label: "Star power ×1", cost: ResourceCost(coins: starPowerCoins))) }
        let gearsNeeded = max(0, 2 - b.gears.count)
        if gearsNeeded > 0 { lines.append(CostLine(label: "Gear ×\(gearsNeeded) (need 2)", cost: ResourceCost(coins: gearsNeeded * gearCoins))) }
        if b.hyperCharges.isEmpty { lines.append(CostLine(label: "Hypercharge", cost: ResourceCost(coins: hyperchargeCoins))) }
        return lines
    }

    static func maxLines(_ b: Brawler, reference: ReferenceBrawler?) -> [CostLine] {
        var lines: [CostLine] = []
        if b.power < maxPower { lines.append(CostLine(label: "Power \(b.power) → 11", cost: levelCost(from: b.power, to: maxPower))) }
        let totalGadgets = max(reference?.gadgets.count ?? 2, b.gadgets.count)
        let totalSP = max(reference?.starPowers.count ?? 2, b.starPowers.count)
        let g = totalGadgets - b.gadgets.count
        if g > 0 { lines.append(CostLine(label: "Gadget ×\(g) (all \(totalGadgets))", cost: ResourceCost(coins: g * gadgetCoins))) }
        let sp = totalSP - b.starPowers.count
        if sp > 0 { lines.append(CostLine(label: "Star power ×\(sp) (all \(totalSP))", cost: ResourceCost(coins: sp * starPowerCoins))) }
        let gears = max(0, standardGearCount - b.gears.count)
        if gears > 0 { lines.append(CostLine(label: "Gear ×\(gears) (all 6)", cost: ResourceCost(coins: gears * gearCoins))) }
        if b.hyperCharges.isEmpty { lines.append(CostLine(label: "Hypercharge", cost: ResourceCost(coins: hyperchargeCoins))) }
        let missing = max(0, totalBuffies - ownedBuffies(b))
        if missing > 0 { lines.append(CostLine(label: "Buffy ×\(missing) (all 3)", cost: ResourceCost(coins: missing * buffyCoins, powerPoints: missing * buffyPowerPoints))) }
        return lines
    }

    // MARK: - Totals (sums of the lines above, so they always agree)

    /// Everything already invested in this brawler.
    static func spent(on b: Brawler) -> ResourceCost {
        var c = levelCost(from: 1, to: b.power)
        c.coins += b.gadgets.count * gadgetCoins
        c.coins += b.starPowers.count * starPowerCoins
        c.coins += b.gears.count * gearCoins
        c.coins += b.hyperCharges.count * hyperchargeCoins
        let buffies = ownedBuffies(b)
        c.coins += buffies * buffyCoins
        c.powerPoints += buffies * buffyPowerPoints
        return c
    }

    /// Remaining to reach Ranked-Eligible: power 11 (hypercharge needs it),
    /// ≥1 gadget, ≥1 star power, ≥2 gears, hypercharge.
    static func toRankedEligible(_ b: Brawler) -> ResourceCost {
        var c = levelCost(from: b.power, to: maxPower)
        if b.gadgets.isEmpty { c.coins += gadgetCoins }
        if b.starPowers.isEmpty { c.coins += starPowerCoins }
        c.coins += max(0, 2 - b.gears.count) * gearCoins
        if b.hyperCharges.isEmpty { c.coins += hyperchargeCoins }
        return c
    }

    /// Remaining to fully max: power 11, every gadget & star power (from the
    /// reference catalog), all six standard gears, hypercharge, all three buffies.
    static func toMax(_ b: Brawler, reference: ReferenceBrawler?) -> ResourceCost {
        var c = levelCost(from: b.power, to: maxPower)
        let totalGadgets = max(reference?.gadgets.count ?? 2, b.gadgets.count)
        let totalSP = max(reference?.starPowers.count ?? 2, b.starPowers.count)
        c.coins += (totalGadgets - b.gadgets.count) * gadgetCoins
        c.coins += (totalSP - b.starPowers.count) * starPowerCoins
        c.coins += max(0, standardGearCount - b.gears.count) * gearCoins
        if b.hyperCharges.isEmpty { c.coins += hyperchargeCoins }
        let missing = max(0, totalBuffies - ownedBuffies(b))
        c.coins += missing * buffyCoins
        c.powerPoints += missing * buffyPowerPoints
        return c
    }
}
