import Foundation

struct DraftSuggestion: Identifiable {
    let brawler: TierBrawler
    let draftClass: DraftClass
    let tierLabel: String?
    let eligible: Bool
    let reason: String
    let score: Int
    let components: [(label: String, value: Int)]   // full score breakdown, for transparency
    var id: Int { brawler.id }
}

struct PickAdvice {
    let slotLabel: String
    let guidance: String
    let targetClasses: [DraftClass]
    let suggestions: [DraftSuggestion]
}

/// Whose pick we're advising on, from your point of view.
enum DraftPerspective { case you, teammate, enemy }

struct DraftContext {
    let mode: String
    let roster: [TierBrawler]
    let tierScore: (Int) -> Int
    let tierLabel: (Int) -> String?
    let eligibleIDs: Set<Int>
    var banned: Set<Int> = []
    var picked: Set<Int> = []
    var myTeamClasses: [DraftClass] = []
    var enemyClasses: [DraftClass] = []
    /// Enemy brawler names, parallel to `enemyClasses` when known (for reasons).
    var enemyNames: [String] = []
    var personal: (Int) -> PersonalStat? = { _ in nil }
    var threat: (Int) -> PersonalStat? = { _ in nil }
    /// The brawler's record across every game you've archived, whoever played it.
    var observed: (Int) -> PersonalStat? = { _ in nil }
    /// Your own global pick number (1…6), when known. Used so ban advice can
    /// avoid denying you a brawler the engine would tell you to pick.
    var myGlobalPick: Int? = nil
}

/// Role-first draft engine. Every number comes from `DraftPlaybook.config`
/// (editable in the app). Priority: role for the slot → Ranked-Eligibility →
/// tier list → your own results → playbook callouts.
enum DraftEngine {
    private static var w: DraftWeights { DraftPlaybook.config.weights }

    /// N (most dominant class for this meta) … 1; 0 if unclassified.
    static func roleWeight(_ cls: DraftClass, meta: DraftMeta) -> Int {
        let order = DraftPlaybook.dominantClasses(for: meta)
        guard let i = order.firstIndex(of: cls) else {
            // No class yet (a brand-new brawler). Scoring it 0 made it invisible
            // to picks and bans; a low neutral rank lets tier and learned data
            // carry it until it's classified.
            return cls == .unknown ? Int(w.unknownRoleWeight) : 0
        }
        return order.count - i
    }

    // MARK: - Bans

    static func banSuggestions(_ ctx: DraftContext, limit: Int = 8) -> [DraftSuggestion] {
        let meta = DraftPlaybook.meta(forMode: ctx.mode)
        let callouts = Set(DraftPlaybook.callouts(forMode: ctx.mode).map { BrawlerArt.normalize($0) })
        // Brawlers the engine would tell you to pick at your own turn. Banning
        // one of these denies you your own best option, so they're pushed down.
        var ownPicks: Set<Int> = []
        if let gp = ctx.myGlobalPick {
            var probe = ctx
            probe.myGlobalPick = nil            // guard against re-entry
            ownPicks = Set(pickAdvice(probe, globalPick: gp, limit: 3).suggestions.map(\.brawler.id))
        }
        let scored: [DraftSuggestion] = ctx.roster
            .filter { !ctx.banned.contains($0.id) }
            .compactMap { b in
                let cls = DraftPlaybook.draftClass(for: b.name)
                let role = roleWeight(cls, meta: meta)
                let tier = ctx.tierScore(b.id)
                guard role > 0 || tier > 0 else { return nil }
                var parts: [(String, Int)] = []
                parts.append(("Role (\(cls.rawValue), rank \(role))", Int(Double(role) * w.banRole)))
                if tier > 0 { parts.append(("Tier \(ctx.tierLabel(b.id) ?? "")", Int(Double(tier) * w.banTier))) }
                let isCallout = callouts.contains(BrawlerArt.normalize(b.name))
                if isCallout { parts.append(("Playbook must-ban", Int(w.banCallout))) }
                var why = "\(cls.rawValue) — \(roleRank(role)) role in \(meta.rawValue.lowercased()) meta"
                if let t = ctx.tierLabel(b.id) { why += " · \(t) tier" }
                if isCallout { why += " · playbook must-ban" }
                if let th = ctx.threat(b.id) {
                    let conf = min(1, th.games / max(1, w.threatConfidenceGames))
                    let v = Int(max(0, th.rate - 0.5) * 2 * w.banThreatMax * conf)
                    if v != 0 { parts.append(("You lose to them", v)) }
                    why += " · \(th.label)"
                }
                if ownPicks.contains(b.id) {
                    parts.append(("You'd want this pick yourself", -Int(w.banOwnPickPenalty)))
                    why += " · but it's one of your own best picks"
                }
                let total = parts.reduce(0) { $0 + $1.1 }
                return DraftSuggestion(brawler: b, draftClass: cls, tierLabel: ctx.tierLabel(b.id),
                                       eligible: ctx.eligibleIDs.contains(b.id), reason: why, score: total, components: parts)
            }
            .sorted { $0.score > $1.score }
        return Array(scored.prefix(limit))
    }

    // MARK: - Picks

    static func pickAdvice(_ ctx: DraftContext, globalPick: Int,
                           perspective: DraftPerspective = .you, limit: Int = 6) -> PickAdvice {
        let meta = DraftPlaybook.meta(forMode: ctx.mode)
        let guide = DraftPlaybook.guide(forMode: ctx.mode)
        let idx = slotIndex(globalPick)
        let slot = guide?.slots[safe: idx]
        let callouts = Set(DraftPlaybook.callouts(forMode: ctx.mode).map { BrawlerArt.normalize($0) })

        // Advise from the picking player's side of the board.
        let isEnemy = perspective == .enemy
        let sideClasses = isEnemy ? ctx.enemyClasses : ctx.myTeamClasses
        let opposingClasses = isEnemy ? ctx.myTeamClasses : ctx.enemyClasses
        // Your Ranked-Eligible roster is your constraint alone; a teammate or
        // opponent can play anything. Your personal win rates likewise only
        // predict your own games.
        let useEligibility = perspective == .you
        let usePersonal = perspective == .you

        var targets = DraftPlaybook.targetClasses(meta: meta, slotIndex: idx)
        var counterNote = ""
        if targets.isEmpty {
            (targets, counterNote) = counterTargets(enemy: opposingClasses, mine: sideClasses, meta: meta)
        } else if targets.allSatisfy({ sideClasses.contains($0) }) {
            // Everything this slot normally wants is already on the board, so
            // swap to whatever the comp still needs instead of doubling up.
            let (backup, note) = backupTargets(mine: sideClasses, enemy: opposingClasses, meta: meta)
            if !backup.isEmpty { targets = backup; counterNote = note }
        }
        // The meta's most important role is never optional: if the comp still
        // lacks it, it leads the targets whatever the slot says (the playbook's
        // "circle back to the anti-tank").
        if let top = keyRoles(for: meta).first, !sideClasses.contains(top), !targets.contains(top) {
            targets.insert(top, at: 0)
            if counterNote.isEmpty { counterNote = "Your team still has no \(top.rawValue) — that comes first." }
        }
        targets = targets.filter { cls in sideClasses.filter { $0 == cls }.count < 2 }

        // Enemy picks as (name, class) for matchup reasoning.
        let enemyPairs: [(String, DraftClass)] = (!isEnemy && ctx.enemyNames.count == opposingClasses.count)
            ? Array(zip(ctx.enemyNames, opposingClasses))
            : opposingClasses.map { ($0.rawValue, $0) }

        let available = ctx.roster.filter { !ctx.banned.contains($0.id) && !ctx.picked.contains($0.id) }
        let eligibleOnly = available.filter { ctx.eligibleIDs.contains($0.id) }
        let pool = (useEligibility && !eligibleOnly.isEmpty) ? eligibleOnly : available

        let scored: [DraftSuggestion] = pool.map { b in
            let cls = DraftPlaybook.draftClass(for: b.name)
            let tier = ctx.tierScore(b.id)
            let inTarget = targets.contains(cls)
            let have = sideClasses.filter { $0 == cls }.count
            let eligible = ctx.eligibleIDs.contains(b.id)
            let isCallout = callouts.contains(BrawlerArt.normalize(b.name))
            var parts: [(String, Int)] = []
            if inTarget { parts.append(("Role match (\(cls.rawValue))", Int(w.pickRoleMatch))) }
            else { parts.append(("Off-role (\(cls.rawValue), rank \(roleWeight(cls, meta: meta)))", Int(Double(roleWeight(cls, meta: meta)) * w.pickOffRolePerWeight))) }
            if tier > 0 { parts.append(("Tier \(ctx.tierLabel(b.id) ?? "")", Int(Double(tier) * w.pickTier))) }
            if useEligibility {
                parts.append((eligible ? "Ranked-Eligible" : "Not eligible",
                              eligible ? Int(w.pickEligibleBonus) : -Int(w.pickIneligiblePenalty)))
            }
            if isCallout { parts.append(("Playbook pick", Int(w.pickCallout))) }
            // Matchups against what the enemy has already shown.
            let beatsThem = enemyPairs.filter { (MatchTips.beats[cls] ?? []).contains($0.1) }
            let beatenBy = enemyPairs.filter { (MatchTips.beats[$0.1] ?? []).contains(cls) }
            if !beatsThem.isEmpty {
                parts.append(("Counters \(beatsThem.map { $0.0.capitalized }.joined(separator: ", "))", Int(Double(beatsThem.count) * w.pickCounterBonus)))
            }
            if !beatenBy.isEmpty {
                parts.append(("Countered by \(beatenBy.map { $0.0.capitalized }.joined(separator: ", "))", -Int(Double(beatenBy.count) * w.pickCounteredPenalty)))
            }
            if have >= 2 { parts.append(("Would be 3rd of class", -Int(w.pickStackTwo))) }
            else if have == 1 { parts.append(("Team has one already", -Int(w.pickStackOne))) }
            var why = inTarget ? "Fits the \(slot?.label ?? "slot") role: \(cls.rawValue)" : "\(cls.rawValue) (off-role)"
            if let t = ctx.tierLabel(b.id) { why += " · \(t) tier" }
            if useEligibility { why += eligible ? " · Ranked-Eligible" : " · NOT eligible" }
            if have == 1 { why += " · \(isEnemy ? "they" : "team") already have one" }
            if isCallout { why += " · playbook pick" }
            if !beatsThem.isEmpty { why += " · counters \(beatsThem.map { $0.0.capitalized }.joined(separator: "/"))" }
            if !beatenBy.isEmpty { why += " · countered by \(beatenBy.map { $0.0.capitalized }.joined(separator: "/"))" }
            if usePersonal, let ps = ctx.personal(b.id) {
                let conf = min(1, ps.games / max(1, w.personalConfidenceGames))
                let v = Int((ps.rate - 0.5) * 2 * w.pickPersonalMax * conf)
                parts.append(("Your results", v))
                why += " · \(ps.label)"
            } else if let obs = ctx.observed(b.id) {
                // No personal history: fall back to how the brawler does in
                // every game you've archived, so rarely-played picks aren't blind.
                let conf = min(1, obs.games / max(1, w.observedConfidenceGames))
                let v = Int((obs.rate - 0.5) * 2 * w.pickObservedMax * conf)
                parts.append(("Observed record", v))
                why += " · \(obs.label)"
            }
            let total = parts.reduce(0) { $0 + $1.1 }
            return DraftSuggestion(brawler: b, draftClass: cls, tierLabel: ctx.tierLabel(b.id),
                                   eligible: eligible, reason: why, score: total, components: parts)
        }
        .sorted { $0.score > $1.score }

        var guidance = slot?.text ?? "Take the best available Ranked-Eligible brawler for the comp."
        if !counterNote.isEmpty { guidance += " \(counterNote)" }
        return PickAdvice(slotLabel: slot?.label ?? "Pick \(globalPick)", guidance: guidance,
                          targetClasses: targets, suggestions: Array(scored.prefix(limit)))
    }

    // MARK: - Helpers

    private static func roleRank(_ w: Int) -> String {
        switch w { case 7: return "top"; case 6: return "2nd"; case 5: return "3rd"; default: return "lower" }
    }

    static func slotIndex(_ g: Int) -> Int {
        switch g { case 1: return 0; case 2, 3: return 1; case 4, 5: return 2; default: return 3 }
    }

    /// The roles a comp wants covered in each meta, best first.
    static func keyRoles(for meta: DraftMeta) -> [DraftClass] {
        meta == .passive ? [.control, .sniper, .antiTank, .support]
                         : [.antiTank, .spaceMaker, .tank, .control]
    }

    /// Your slot's usual role is taken by a teammate: fill a gap instead.
    static func backupTargets(mine: [DraftClass], enemy: [DraftClass], meta: DraftMeta) -> ([DraftClass], String) {
        let key = keyRoles(for: meta)
        let missing = key.filter { !mine.contains($0) }
        guard !missing.isEmpty else { return counterTargets(enemy: enemy, mine: mine, meta: meta) }
        let taken = key.filter { mine.contains($0) }
        let note = "Your slot's usual role (\(taken.map(\.rawValue).joined(separator: "/"))) is already covered by your team — filling \(missing.prefix(2).map(\.rawValue).joined(separator: "/")) instead."
        return (Array(missing.prefix(3)), note)
    }

    /// Counter-pick logic for slots with no fixed target: read what the enemy
    /// comp is missing and punish it (playbook mantras 01/06).
    static func counterTargets(enemy: [DraftClass], mine: [DraftClass], meta: DraftMeta) -> ([DraftClass], String) {
        var t: [DraftClass] = []
        var notes: [String] = []
        if !enemy.contains(.antiTank) {
            t += [.tank, .spaceMaker]; notes.append("Enemy has no anti-tank → a tank/space maker punishes them.")
        }
        if !enemy.contains(.spaceMaker) {
            t += [.thrower, .sniper, .control]; notes.append("Enemy has no space maker → a thrower/ranged pick is safe.")
        }
        if enemy.filter({ $0 == .sniper || $0 == .thrower }).count >= 2 {
            t += [.spaceMaker]; notes.append("Enemy is range-heavy → dive them with a space maker.")
        }
        if meta == .aggro, !mine.contains(.antiTank) {
            t.insert(.antiTank, at: 0); notes.append("Your team still lacks an anti-tank — cover it.")
        }
        if t.isEmpty { t = Array(DraftPlaybook.dominantClasses(for: meta).prefix(2)) }
        var seen = Set<DraftClass>()
        t = t.filter { seen.insert($0).inserted }
        return (t, notes.joined(separator: " "))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
