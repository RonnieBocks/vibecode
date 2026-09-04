import Foundation

/// A piece of in-match guidance generated from both comps.
struct MatchTip: Identifiable {
    enum Category: String, CaseIterable {
        case role = "Your role"
        case threats = "Watch out for"
        case plan = "Team plan"
        case history = "From your history"
        case mode = "Mode"
    }
    let id = UUID()
    let category: Category
    let text: String
    let priority: Int

    init(category: Category, text: String, priority: Int) {
        self.category = category; self.text = text; self.priority = priority
    }
    init(category: Category, priority: Int, text: String) {
        self.category = category; self.text = text; self.priority = priority
    }
}

/// Deterministic, replicable tip generator. Five tip types, each produced by a
/// rule that reads the two comps (classes), the mode's meta, and your history.
enum MatchTips {
    /// Which classes each class reliably beats (from the playbook class notes).
    static let beats: [DraftClass: [DraftClass]] = [
        .antiTank: [.tank, .spaceMaker],
        .spaceMaker: [.thrower, .sniper, .support],
        .tank: [.spaceMaker, .support],
        .thrower: [.tank, .control, .antiTank],
        .sniper: [.tank, .antiTank, .control],
        .control: [.antiTank],
        .support: [],
        .unknown: [],
    ]

    static func counters(of cls: DraftClass) -> [DraftClass] {
        beats.filter { $0.value.contains(cls) }.map(\.key)
    }

    private static let roleJob: [DraftClass: String] = [
        .antiTank: "kill their tanks and divers, and hold the line so your ranged picks can work.",
        .spaceMaker: "dive their backline (throwers/snipers) so it can't play, and pair with your anti-tank to run down weak matchups.",
        .tank: "use your HP to take space and walk down their undefended space maker — never into their anti-tank or a thrower.",
        .control: "hold territory once your anti-tank has secured it and win the positional 1v1s.",
        .sniper: "poke from max range and never let their space maker reach you.",
        .thrower: "deny area over walls and stay untouchable — you die to any dive.",
        .support: "enable your damage dealer or tank; never be alone.",
        .unknown: "play to your brawler's strengths and stay with your team.",
    ]

    private static let threatAdvice: [DraftClass: String] = [
        .thrower: "lobs over walls — don't camp cover near them; close the gap or force them to move.",
        .sniper: "out-ranges you — cross lanes only through cover and let your space maker pressure them.",
        .antiTank: "shreds tanks and divers — don't dive alone; bait out their ammo or super first.",
        .spaceMaker: "will dive you — keep an escape, stay near teammates, save your gadget/super for their engage.",
        .tank: "wins up close — keep distance, kite, and focus fire together.",
        .control: "holds lanes — don't push into their zone; flank or wait for their super to be spent.",
        .support: "keeps their team alive — split them from their carry or kill them first.",
        .unknown: "unknown role — respect them until you see their kit.",
    ]

    private static let modeTips: [String: String] = [
        "brawlball": "Ball control wins — pass when marked, and remember the ball lets you tank one hit.",
        "gemgrab": "Protect the gem carrier: hold 10 for the countdown; never chase kills when you're up.",
        "hotzone": "Zone time is the only score — contest in numbers, rotate together, don't chase off the zone.",
        "heist": "Damage on the safe is all that matters — trade safe damage rather than 'defending'.",
        "bounty": "Stars make you a target: don't overextend when you're up; punish their lead carrier.",
        "knockout": "No respawns — take only favorable trades, and go together once you're a player up.",
    ]

    static func generate(mode: String, map: String?, myBrawler: String?, myTeam: [String], enemy: [String],
                         learning: DraftLearning?) -> [MatchTip] {
        var tips: [MatchTip] = []
        let meta = DraftPlaybook.meta(forMode: mode)
        let myClass = myBrawler.map { DraftPlaybook.draftClass(for: $0) } ?? .unknown
        let myClasses = myTeam.map { DraftPlaybook.draftClass(for: $0) }
        let enemyPairs = enemy.map { ($0, DraftPlaybook.draftClass(for: $0)) }
        let enemyClasses = enemyPairs.map(\.1)

        // 1. Your role
        if let b = myBrawler {
            var text = "\(b.capitalized) is your \(myClass.rawValue): \(roleJob[myClass] ?? "")"
            let prey = enemyPairs.filter { (beats[myClass] ?? []).contains($0.1) }.map { $0.0.capitalized }
            if !prey.isEmpty { text += " Your best targets: \(prey.joined(separator: ", "))." }
            tips.append(MatchTip(category: .role, text: text, priority: 100))
        }

        // 2. Threats (enemy classes that beat yours)
        for (name, cls) in enemyPairs where counters(of: myClass).contains(cls) {
            tips.append(MatchTip(category: .threats,
                                 text: "\(name.capitalized) (\(cls.rawValue)) \(threatAdvice[cls] ?? "")", priority: 90))
        }

        // 3. Team plan
        let haveAT = myClasses.contains(.antiTank), haveSM = myClasses.contains(.spaceMaker)
        if haveAT, haveSM {
            let weakest = enemyPairs.first { [.thrower, .sniper, .support, .tank].contains($0.1) }?.0.capitalized
            tips.append(MatchTip(category: .plan, priority: 85,
                                 text: "Anti-tank + space maker: move as a pair and run down \(weakest.map { "\($0) first" } ?? "their weakest lane").".replacingOccurrences(of: "priority", with: "")))
        }
        if !enemyClasses.contains(.antiTank), myClasses.contains(where: { $0 == .tank || $0 == .spaceMaker }) {
            tips.append(MatchTip(category: .plan, text: "They have no anti-tank — your tank/space maker can push aggressively; nothing on their side punishes it.", priority: 84))
        }
        if let thrower = enemyPairs.first(where: { $0.1 == .thrower }), haveSM {
            tips.append(MatchTip(category: .plan, text: "Send your space maker at \(thrower.0.capitalized) early — a thrower with a diver on them can't play.", priority: 82))
        }
        if enemyClasses.filter({ $0 == .sniper || $0 == .thrower }).count >= 2 {
            tips.append(MatchTip(category: .plan, text: "Range-heavy enemy comp: don't trade at range; group up and dive together through cover.", priority: 81))
        }
        if meta == .aggro, !haveAT {
            tips.append(MatchTip(category: .plan, text: "No anti-tank on your side in an aggro mode: never let their tank walk free — focus fire it as a team.", priority: 83))
        }
        if let stacked = Dictionary(grouping: myClasses, by: { $0 }).first(where: { $0.value.count >= 3 }) {
            tips.append(MatchTip(category: .plan, text: "Three \(stacked.key.rawValue)s: you cover the same matchups — spread lanes instead of stacking one side.", priority: 80))
        }
        if let support = enemyPairs.first(where: { $0.1 == .support }) {
            tips.append(MatchTip(category: .plan, text: "\(support.0.capitalized) is their support — kill or isolate them and their carry falls over.", priority: 78))
        }

        // 4. History
        if let learning, let b = myBrawler, let st = learning.stat(brawler: b, mode: mode, map: map) {
            let pct = Int(st.rate * 100)
            tips.append(MatchTip(category: .history, priority: 75,
                                 text: pct >= 55 ? "\(b.capitalized) is one of your winners here (\(st.label)) — play your usual game."
                                     : pct <= 45 ? "\(b.capitalized) has been rough for you here (\(st.label)) — play safer and follow your team's calls."
                                     : "\(b.capitalized): \(st.label)."))
        }
        if let learning {
            for (name, _) in enemyPairs {
                if let th = learning.threat(enemy: name), th.rate >= 0.6 {
                    tips.append(MatchTip(category: .history, text: "\(name.capitalized): \(th.label) — respect that matchup.", priority: 72))
                }
            }
        }

        // 5. Mode
        tips.append(MatchTip(category: .mode, priority: 60,
                             text: meta == .aggro ? "Aggro meta: constant pressure wins — don't give them time to set up."
                                 : meta == .passive ? "Passive meta: patience wins — only take trades with an advantage and respect range."
                                 : "Play the objective first."))
        if let m = modeTips[DraftPlaybook.normalizeMode(mode)] {
            tips.append(MatchTip(category: .mode, text: m, priority: 58))
        }

        return tips.sorted { $0.priority > $1.priority }
    }
}


// MARK: - Glanceable game plan (structured, short phrases, for the loading screen)

struct GamePlan {
    struct Threat: Identifiable {
        let name: String
        let cls: DraftClass
        let tip: String
        var id: String { name }
    }
    let meta: DraftMeta
    let modeName: String
    let tempo: String            // one word
    let tempoLine: String        // one short sentence
    let modeLine: String?        // objective in a few words
    let myBrawler: String?
    let myClass: DraftClass
    let job: String              // imperative, short
    let targets: [String]        // enemy brawlers you beat — kill priority
    let threats: [Threat]        // enemy brawlers that beat you
    let plan: [String]           // ≤ 4 short bullets
    let history: String?         // e.g. "90% for you · 11g"
    let historyGood: Bool?
}

extension MatchTips {
    private static let shortJob: [DraftClass: String] = [
        .antiTank: "Kill their tanks & divers. Hold the line.",
        .spaceMaker: "Dive their backline. Pair with your anti-tank.",
        .tank: "Take space. Walk down their diver. Avoid anti-tanks.",
        .control: "Hold ground behind your anti-tank. Win the 1v1s.",
        .sniper: "Poke from max range. Never get dived.",
        .thrower: "Deny over walls. Stay untouchable.",
        .support: "Stick to your carry. Never alone.",
        .unknown: "Play the objective. Stay with your team.",
    ]
    private static let shortThreat: [DraftClass: String] = [
        .thrower: "Don't camp cover — close in",
        .sniper: "Cross only through cover",
        .antiTank: "Never dive alone — bait super",
        .spaceMaker: "Keep an escape — stay grouped",
        .tank: "Kite — focus fire",
        .control: "Don't push their zone — flank",
        .support: "Kill first",
        .unknown: "Respect until seen",
    ]
    private static let shortMode: [String: String] = [
        "brawlball": "Control the ball · pass when marked",
        "gemgrab": "Protect the carrier · hold at 10",
        "hotzone": "Zone time only · rotate together",
        "heist": "Safe damage beats defending",
        "bounty": "Don't overextend when up · hunt their star carrier",
        "knockout": "No respawns · go together when a player up",
    ]

    static func plan(mode: String, map: String?, myBrawler: String?, myTeam: [String], enemy: [String],
                     learning: DraftLearning?) -> GamePlan {
        let meta = DraftPlaybook.meta(forMode: mode)
        let myClass = myBrawler.map { DraftPlaybook.draftClass(for: $0) } ?? .unknown
        let myClasses = myTeam.map { DraftPlaybook.draftClass(for: $0) }
        let enemyPairs = enemy.map { ($0, DraftPlaybook.draftClass(for: $0)) }
        let enemyClasses = enemyPairs.map(\.1)

        let targets = enemyPairs.filter { (beats[myClass] ?? []).contains($0.1) }.map(\.0)
        let threats = enemyPairs.filter { counters(of: myClass).contains($0.1) }
            .map { GamePlan.Threat(name: $0.0, cls: $0.1, tip: shortThreat[$0.1] ?? "") }

        var plan: [String] = []
        let haveAT = myClasses.contains(.antiTank), haveSM = myClasses.contains(.spaceMaker)
        if haveAT, haveSM {
            let weakest = enemyPairs.first { [.thrower, .sniper, .support, .tank].contains($0.1) }?.0.capitalized
            plan.append("Pair anti-tank + diver" + (weakest.map { " → run down \($0)" } ?? ""))
        }
        if !enemyClasses.contains(.antiTank), myClasses.contains(where: { $0 == .tank || $0 == .spaceMaker }) {
            plan.append("No enemy anti-tank → push freely")
        }
        if let thrower = enemyPairs.first(where: { $0.1 == .thrower }), haveSM {
            plan.append("Dive \(thrower.0.capitalized) early")
        }
        if enemyClasses.filter({ $0 == .sniper || $0 == .thrower }).count >= 2 {
            plan.append("Range-heavy enemy → group up, dive through cover")
        }
        if meta == .aggro, !haveAT { plan.append("No anti-tank → focus-fire their tank") }
        if Dictionary(grouping: myClasses, by: { $0 }).values.contains(where: { $0.count >= 3 }) {
            plan.append("Stacked comp → spread lanes")
        }
        if let support = enemyPairs.first(where: { $0.1 == .support }) {
            plan.append("Kill \(support.0.capitalized) (support) first")
        }
        if plan.isEmpty { plan.append(meta == .aggro ? "Push together, win the trades" : "Hold position, punish mistakes") }

        var history: String? = nil, historyGood: Bool? = nil
        if let learning, let b = myBrawler, let st = learning.stat(brawler: b, mode: mode, map: map) {
            let scope = st.label.contains("map") ? "on this map" : st.label.contains("mode") ? "in this mode" : "overall"
            history = "\(Int(st.rate * 100))% for you \(scope) · \(Int(st.games.rounded()))g"
            historyGood = st.rate >= 0.5
        }

        return GamePlan(
            meta: meta,
            modeName: mode,
            tempo: meta == .aggro ? "PRESSURE" : meta == .passive ? "PATIENCE" : "OBJECTIVE",
            tempoLine: meta == .aggro ? "Never let them set up." : meta == .passive ? "Only advantaged trades. Respect range." : "Play the objective first.",
            modeLine: shortMode[DraftPlaybook.normalizeMode(mode)],
            myBrawler: myBrawler, myClass: myClass,
            job: shortJob[myClass] ?? "",
            targets: targets, threats: threats,
            plan: Array(plan.prefix(4)),
            history: history, historyGood: historyGood)
    }
}
