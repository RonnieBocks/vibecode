import Foundation

struct AnalysisBullet: Identifiable {
    enum Kind { case good, warn, neutral }
    let id = UUID()
    let kind: Kind
    let text: String
}

struct AnalysisSection: Identifiable {
    let id = UUID()
    let title: String
    let bullets: [AnalysisBullet]
}

/// Post-match review: bans, draft, result, lessons — rule-based and
/// replicable, using the same playbook rules the assistant drafted with.
enum MatchAnalyzer {
    static func analyze(_ m: MatchRecord, learning: DraftLearning) -> [AnalysisSection] {
        var sections: [AnalysisSection] = []
        let meta = DraftPlaybook.meta(forMode: m.mode)
        let myClasses = m.myTeam.map { DraftPlaybook.draftClass(for: $0) }
        let enemyClasses = m.enemyTeam.map { DraftPlaybook.draftClass(for: $0) }

        // Result
        var result: [AnalysisBullet] = []
        result.append(.init(kind: m.seriesWon ? .good : .warn,
                            text: "\(m.seriesWon ? "Won" : "Lost") the series \(m.seriesText) (\(m.wins)–\(m.losses))."))
        if let wc = m.winChance {
            let pct = Int((wc * 100).rounded())
            if m.seriesWon && wc < 0.45 { result.append(.init(kind: .good, text: "Predicted \(pct)% — you outperformed the draft. Execution carried it; note what worked.")) }
            else if !m.seriesWon && wc > 0.55 { result.append(.init(kind: .warn, text: "Predicted \(pct)% but lost — the draft was fine; look at in-game decisions (see the plan below).")) }
            else { result.append(.init(kind: .neutral, text: "Predicted \(pct)% win chance — the result matched the draft read.")) }
        }
        if let b = m.myBrawler, let st = learning.stat(brawler: b, mode: m.mode, map: m.mapName, minGames: 1) {
            result.append(.init(kind: .neutral, text: "\(b.capitalized) now: \(st.label)."))
        }
        // Your own tags qualify the result: a loss you flagged as execution is
        // not evidence the draft was wrong.
        if m.tags.contains(.iMisplayed) && !m.seriesWon {
            result.append(.init(kind: .neutral, text: "You flagged this as your own misplay — read it as an execution loss, not a draft failure."))
        }
        if m.tags.contains(.teammateIssue) && !m.seriesWon {
            result.append(.init(kind: .neutral, text: "You flagged a teammate issue — the draft read may still have been correct."))
        }
        if m.tags.contains(.gotCountered) {
            result.append(.init(kind: .warn, text: "You flagged getting countered — check the Respect list in the plan below against what actually happened."))
        }
        sections.append(AnalysisSection(title: "Result", bullets: result))

        // Bans
        var bans: [AnalysisBullet] = []
        if let mine = m.myBan {
            if let sugg = m.banSuggestions, let idx = sugg.firstIndex(where: { BrawlerArt.normalize($0) == BrawlerArt.normalize(mine) }) {
                bans.append(.init(kind: idx == 0 ? .good : .neutral, text: "Your ban \(mine.capitalized) was the engine's #\(idx + 1) suggestion."))
            } else if let sugg = m.banSuggestions, !sugg.isEmpty {
                bans.append(.init(kind: .warn, text: "Your ban \(mine.capitalized) wasn't in the engine's top bans (\(sugg.prefix(3).map { $0.capitalized }.joined(separator: ", "))). Fine if you had a read — otherwise deny the meta's top role."))
            }
        }
        let banClasses = m.bans.map { DraftPlaybook.draftClass(for: $0) }
        let dominant = DraftPlaybook.dominantClasses(for: meta).first
        if let dominant {
            let n = banClasses.filter { $0 == dominant }.count
            bans.append(.init(kind: .neutral, text: "\(n) of \(m.bans.count) bans were \(dominant.rawValue)s — the meta's top role."))
        }
        if bans.isEmpty { bans.append(.init(kind: .neutral, text: "No ban data recorded for this match.")) }
        sections.append(AnalysisSection(title: "Bans", bullets: bans))

        // Draft
        var draft: [AnalysisBullet] = []
        if let picks = m.picksInOrder {
            for p in picks where p.isAlly {
                let cls = DraftPlaybook.draftClass(for: p.brawler)
                let idx = DraftEngine.slotIndex(p.globalPick)
                let targets = DraftPlaybook.targetClasses(meta: meta, slotIndex: idx)
                let label = ["1st", "2–3", "4–5", "Last"][idx]
                let who = p.isMine ? "You" : "Teammate"
                if targets.isEmpty {
                    draft.append(.init(kind: .neutral, text: "\(who) picked \(p.brawler.capitalized) (\(cls.rawValue)) at pick \(p.globalPick) — a counter slot."))
                } else if targets.contains(cls) {
                    draft.append(.init(kind: .good, text: "\(who) picked \(p.brawler.capitalized) (\(cls.rawValue)) at pick \(p.globalPick) — on-role for the \(label) slot."))
                } else {
                    draft.append(.init(kind: .warn, text: "\(who) picked \(p.brawler.capitalized) (\(cls.rawValue)) at pick \(p.globalPick) — the \(label) slot wanted \(targets.map(\.rawValue).joined(separator: "/"))."))
                }
            }
        }
        if let s = m.myPickWasSuggested {
            let top = (m.mySuggestions ?? []).prefix(3).map { $0.capitalized }.joined(separator: ", ")
            let text = s ? "Your pick was among the engine's suggestions."
                         : (top.isEmpty ? "Your pick wasn't suggested." : "Your pick wasn't suggested (top: \(top)).")
            draft.append(.init(kind: s ? .good : .warn, text: text))
        }
        // Coverage
        func coverage(_ classes: [DraftClass], _ who: String) -> AnalysisBullet {
            let key: [DraftClass] = meta == .aggro ? [.antiTank, .spaceMaker] : [.control, .sniper]
            let missing = key.filter { !classes.contains($0) }
            return missing.isEmpty
                ? .init(kind: .good, text: "\(who) covered the key roles for \(meta.rawValue.lowercased()): \(key.map(\.rawValue).joined(separator: " + ")).")
                : .init(kind: .warn, text: "\(who) never took \(missing.map(\.rawValue).joined(separator: " or ")) — the meta's key role\(missing.count > 1 ? "s" : "").")
        }
        draft.append(coverage(myClasses, "Your team"))
        draft.append(coverage(enemyClasses, "Enemy"))
        if let stacked = Dictionary(grouping: myClasses, by: { $0 }).first(where: { $0.value.count >= 3 }) {
            draft.append(.init(kind: .warn, text: "Your team stacked three \(stacked.key.rawValue)s — covering the same matchups three times."))
        }
        if let last = m.picksInOrder?.first(where: { $0.globalPick == 6 }), last.isAlly {
            let (targets, note) = DraftEngine.counterTargets(enemy: enemyClasses, mine: myClasses.filter { _ in true }, meta: meta)
            let cls = DraftPlaybook.draftClass(for: last.brawler)
            draft.append(.init(kind: targets.contains(cls) ? .good : .warn,
                               text: targets.contains(cls) ? "Last pick \(last.brawler.capitalized) punished what the enemy lacked. \(note)"
                                                          : "Last pick \(last.brawler.capitalized) didn't counter the enemy's gap. \(note)"))
        }
        sections.append(AnalysisSection(title: "Draft", bullets: draft))

        // Lessons
        var lessons: [AnalysisBullet] = []
        if meta == .aggro, let first = m.picksInOrder?.first(where: { $0.globalPick == 1 }), first.isAlly,
           DraftPlaybook.draftClass(for: first.brawler) != .antiTank {
            lessons.append(.init(kind: .warn, text: "Aggro first pick wasn't an anti-tank — playbook rule 01: first pick is always the best available anti-tank."))
        }
        if let early = m.picksInOrder?.first(where: { $0.isAlly && $0.globalPick <= 3 && DraftPlaybook.draftClass(for: $0.brawler) == .thrower }) {
            lessons.append(.init(kind: .warn, text: "\(early.brawler.capitalized) (thrower) went at pick \(early.globalPick) — throwers only work as a clean last pick."))
        }
        if !m.seriesWon, let b = m.myBrawler, let st = learning.stat(brawler: b, mode: m.mode, map: nil), st.rate < 0.45 {
            lessons.append(.init(kind: .warn, text: "\(b.capitalized) keeps underperforming for you in \(m.mode) (\(st.label)) — consider another eligible option next time."))
        }
        if m.seriesWon, myClasses.contains(.antiTank), myClasses.contains(.spaceMaker) {
            lessons.append(.init(kind: .good, text: "Anti-tank + space maker won again — keep drafting that pairing in aggro modes."))
        }
        if lessons.isEmpty { lessons.append(.init(kind: .good, text: "No structural mistakes found in this draft — the outcome came down to play.")) }
        // Anything you tagged as model feedback is called out for tuning.
        let feedback = m.tags.filter(\.isModelFeedback)
        if !feedback.isEmpty {
            for t in feedback {
                switch t {
                case .suggestionBad:
                    lessons.append(.init(kind: .warn, text: "You marked the suggestion as a miss — worth checking the Draft Model weights, or whether this brawler's class is right."))
                case .suggestionGood:
                    lessons.append(.init(kind: .good, text: "You marked the suggestion as correct — the current weights are working here."))
                case .tierStale:
                    lessons.append(.init(kind: .warn, text: "You flagged the tier list as stale — update it in the Tier List tab so suggestions follow the current meta."))
                case .mapSpecific:
                    lessons.append(.init(kind: .neutral, text: "You flagged this as map-specific — the engine already weights your record on this map once it has 3+ games here."))
                default: break
                }
            }
        }
        sections.append(AnalysisSection(title: "Lessons", bullets: lessons))

        return sections
    }
}
