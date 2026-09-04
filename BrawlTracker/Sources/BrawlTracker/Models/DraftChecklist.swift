import Foundation

/// One comp requirement and its live status.
struct ChecklistItem: Identifiable {
    enum Status { case done, pending, unfillable }
    let id: String
    let role: String
    let allowed: [DraftClass]
    let why: String
    var status: Status
    var filledBy: (brawler: String, seat: Int)?
    var assignedSeat: Int?
}

struct DraftChecklistResult {
    let meta: DraftMeta
    let items: [ChecklistItem]
    let warnings: [String]
    let practices: [String]
}

/// Live drafting checklist. It grades the comp you actually have, in any
/// order: a space maker at pick 1 and an anti-tank at pick 4 still tick both
/// boxes. Unmet requirements are pointed at the next seats on your side to
/// pick, by pick order.
enum DraftChecklist {
    struct OwnPick {
        let seat: Int
        let globalPick: Int
        let brawler: String?     // nil = hasn't picked yet
    }

    typealias Requirement = (role: String, allowed: [DraftClass], why: String)

    static func requirements(for meta: DraftMeta) -> [Requirement] {
        switch meta {
        case .aggro: return [
            ("Anti-Tank", [.antiTank], "Kills tanks and divers — the default first pick in aggro."),
            ("Space Maker", [.spaceMaker], "Pairs with the anti-tank to run down weak matchups."),
            ("Tank / Control / 2nd Anti-Tank", [.tank, .control, .antiTank], "Third slot — fill against what the enemy shows."),
        ]
        default: return [
            ("Control", [.control], "Solid all-rounder that holds territory in passive modes."),
            ("Ranged hybrid (Sniper / Control)", [.sniper, .control], "Range comes back to life in passive metas."),
            ("Counter (Thrower / Support / Space Maker / Anti-Tank)", [.thrower, .support, .spaceMaker, .antiTank],
             "Punish what their comp is missing."),
        ]}
    }

    static func build(mode: String, own: [OwnPick], enemyClasses: [DraftClass]) -> DraftChecklistResult {
        let meta = DraftPlaybook.meta(forMode: mode)
        let reqs = requirements(for: meta)
        let picked = own.compactMap { p -> (seat: Int, globalPick: Int, brawler: String, cls: DraftClass)? in
            guard let b = p.brawler else { return nil }
            return (p.seat, p.globalPick, b, DraftPlaybook.draftClass(for: b))
        }

        // 1) Satisfy requirements in priority order, order-agnostic. Each pick
        //    can tick at most one box.
        var used = Set<Int>()
        var items: [ChecklistItem] = []
        for (i, r) in reqs.enumerated() {
            var item = ChecklistItem(id: "req\(i)", role: r.role, allowed: r.allowed, why: r.why,
                                     status: .pending, filledBy: nil, assignedSeat: nil)
            if let m = picked.first(where: { !used.contains($0.seat) && r.allowed.contains($0.cls) }) {
                used.insert(m.seat)
                item.status = .done
                item.filledBy = (m.brawler, m.seat)
            }
            items.append(item)
        }

        // 2) Point unmet requirements at the remaining seats on your side, in pick order.
        let remaining = own.filter { $0.brawler == nil }.sorted { $0.globalPick < $1.globalPick }.map(\.seat)
        var seats = remaining.makeIterator()
        for i in items.indices where items[i].status == .pending {
            if let s = seats.next() { items[i].assignedSeat = s } else { items[i].status = .unfillable }
        }

        // 3) Best-practice violations, evaluated on the comp as it stands.
        var warnings: [String] = []
        let classes = picked.map(\.cls)
        if meta == .aggro, let first = picked.first(where: { $0.globalPick == 1 }), first.cls != .antiTank {
            warnings.append("First pick \(first.brawler.capitalized) is a \(first.cls.rawValue) — aggro first pick should be the best anti-tank.")
        }
        if meta == .aggro, let control = picked.first(where: { $0.globalPick == 1 && $0.cls == .control }) {
            warnings.append("\(control.brawler.capitalized) first in aggro gets run down with no anti-tank to protect it.")
        }
        for p in picked where p.cls == .thrower && p.globalPick < 6 {
            warnings.append("\(p.brawler.capitalized) (Thrower) at pick \(p.globalPick) — throwers only work as a clean last pick.")
        }
        if let stacked = Dictionary(grouping: classes, by: { $0 }).first(where: { $0.value.count >= 3 }) {
            warnings.append("Three \(stacked.key.rawValue)s — the same matchups covered three times.")
        }
        for p in picked where !reqs.contains(where: { $0.allowed.contains(p.cls) }) {
            warnings.append("\(p.brawler.capitalized) (\(p.cls.rawValue)) covers none of the core roles for a \(meta.rawValue.lowercased()) comp.")
        }
        if items.contains(where: { $0.status == .unfillable }) {
            warnings.append("Not enough seats left to cover every core role — the last pick must be the best counter available.")
        }

        // 4) Practices for this meta, plus enemy-aware nudges as their comp fills in.
        var practices: [String] = meta == .aggro
            ? ["1st: best anti-tank → 2–3: next anti-tank or space maker → 4–5: fill the gap → last: hard counter.",
               "Anti-tank + space maker together is the game plan. Never first-pick control, pure snipers, or throwers."]
            : ["1st: solid all-rounder → 2–3: hybrid ranged → 4–5: counter the read → last: hard counter.",
               "Range and control come back; pure throwers and snipers still want to go last."]
        if !enemyClasses.isEmpty {
            if !enemyClasses.contains(.antiTank) { practices.append("Enemy has no anti-tank yet: a tank or space maker can push freely.") }
            if !enemyClasses.contains(.spaceMaker) { practices.append("Enemy has no space maker yet: a thrower or ranged pick is safe late.") }
            if enemyClasses.filter({ $0 == .sniper || $0 == .thrower }).count >= 2 { practices.append("Enemy is range-heavy: a diver wins this draft.") }
        }
        return DraftChecklistResult(meta: meta, items: items, warnings: warnings, practices: practices)
    }
}
