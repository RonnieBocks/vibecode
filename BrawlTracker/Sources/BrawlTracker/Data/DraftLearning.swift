import Foundation

/// A personal performance stat for a brawler in some context.
struct PersonalStat {
    let rate: Double      // smoothed win rate 0…1
    let games: Double     // recency-weighted game count
    let label: String     // human explanation
}

/// Learns from YOUR results — every archived battle (regular + ranked) and
/// every logged ranked series — with recency weighting so the model follows
/// the meta instead of remembering last year's balance. Rebuilt on demand
/// from the raw data, so there is never a stale "trained" file to reset when
/// a new map pool or tier list arrives.
struct DraftLearning {
    private struct Tally { var wins = 0.0; var games = 0.0 }

    private var overall: [String: Tally] = [:]        // brawler
    private var byMode: [String: Tally] = [:]         // brawler|mode
    private var byMap: [String: Tally] = [:]          // brawler|mode|map
    private var vsEnemy: [String: Tally] = [:]        // enemy brawler -> (my LOSSES, games)
    /// Every brawler seen in any game, scored from ITS side's result — so a
    /// brawler you never play still builds a record.
    private var observed: [String: Tally] = [:]
    private var observedByMode: [String: Tally] = [:]   // brawler|mode
    private var observedByMap: [String: Tally] = [:]    // brawler|mode|map
    private var modeBaseline: [String: Tally] = [:]   // mode -> wins, games
    private var mapBaseline: [String: Tally] = [:]    // mode|map

    let halfLifeDays: Double

    init(archive: [BattleRecord], matches: [MatchRecord], since: Date? = nil, halfLifeDays: Double? = nil) {
        let cfg = DraftPlaybook.config.weights
        let hl = halfLifeDays ?? cfg.halfLifeDays
        self.halfLifeDays = hl
        let now = Date()
        func weight(_ d: Date) -> Double {
            if let since, d < since { return 0 }
            let age = max(0, now.timeIntervalSince(d) / 86400)
            return pow(0.5, age / hl)
        }
        // Archived battles: one game each.
        for r in archive {
            let w = weight(r.time); guard w > 0, r.outcome != .draw else { continue }
            let win = r.outcome == .win ? w : 0
            let mode = DraftPlaybook.normalizeMode(r.mode), map = Self.norm(r.map)
            Self.add(&modeBaseline, mode, win, w); Self.add(&mapBaseline, mode + "|" + map, win, w)
            // Everyone in the game counts, from their own side's perspective.
            func seen(_ name: String, _ theirWin: Double) {
                let k = Self.norm(name)
                Self.add(&observed, k, theirWin, w)
                Self.add(&observedByMode, k + "|" + mode, theirWin, w)
                Self.add(&observedByMap, k + "|" + mode + "|" + map, theirWin, w)
            }
            for a in (r.allies ?? []) { seen(a, win) }
            for o in (r.opponents ?? []) {
                seen(o, w - win)                                   // they won when you lost
                Self.add(&vsEnemy, Self.norm(o), r.outcome == .loss ? w : 0, w)
            }
            guard let b = r.myBrawler.map(Self.norm) else { continue }
            seen(b, win)
            Self.add(&overall, b, win, w); Self.add(&byMode, b + "|" + mode, win, w); Self.add(&byMap, b + "|" + mode + "|" + map, win, w)
        }
        // Ranked series: each played game counts for my brawler; enemy comp feeds matchups.
        for m in matches {
            let w = weight(m.date) * cfg.rankedGameWeight; guard w > 0 else { continue }   // ranked games weighted
            let mode = DraftPlaybook.normalizeMode(m.mode), map = Self.norm(m.mapName)
            guard let mine = Self.myBrawler(in: m).map(Self.norm) else { continue }
            for g in m.series where g != .none {
                let win = g == .win ? w : 0
                Self.add(&modeBaseline, mode, win, w); Self.add(&mapBaseline, mode + "|" + map, win, w)
                Self.add(&overall, mine, win, w); Self.add(&byMode, mine + "|" + mode, win, w); Self.add(&byMap, mine + "|" + mode + "|" + map, win, w)
                func seen(_ name: String, _ theirWin: Double) {
                    let k = Self.norm(name)
                    Self.add(&observed, k, theirWin, w)
                    Self.add(&observedByMode, k + "|" + mode, theirWin, w)
                    Self.add(&observedByMap, k + "|" + mode + "|" + map, theirWin, w)
                }
                for t in m.myTeam { seen(t, win) }
                for e in m.enemyTeam {
                    seen(e, w - win)
                    Self.add(&vsEnemy, Self.norm(e), g == .loss ? w : 0, w)
                }
            }
        }
    }

    private static func add(_ dict: inout [String: Tally], _ key: String, _ win: Double, _ w: Double) {
        var t = dict[key] ?? Tally(); t.wins += win; t.games += w; dict[key] = t
    }

    static func norm(_ s: String) -> String { BrawlerArt.normalize(s) }

    /// Which of `myTeam` was me: myTeam is in pick order, mySlot is my global pick.
    static func myBrawler(in m: MatchRecord) -> String? {
        let mySeatsPicks = m.wonToss ? [1, 4, 5] : [2, 3, 6]
        guard let idx = mySeatsPicks.firstIndex(of: m.mySlot), idx < m.myTeam.count else { return m.myTeam.first }
        return m.myTeam[idx]
    }

    private static func smooth(_ t: Tally) -> Double {
        let c = DraftPlaybook.config.weights
        return (t.wins + c.smoothPseudoWins) / (t.games + c.smoothPseudoGames)
    }

    /// Most specific stat with enough data: map → mode → overall.
    func stat(brawler: String, mode: String, map: String?, minGames: Double? = nil) -> PersonalStat? {
        let minGames = minGames ?? DraftPlaybook.config.weights.minGames
        let b = Self.norm(brawler), md = DraftPlaybook.normalizeMode(mode)
        if let map, let t = byMap[b + "|" + md + "|" + Self.norm(map)], t.games >= minGames {
            return PersonalStat(rate: Self.smooth(t), games: t.games,
                                label: "\(Int(t.wins / t.games * 100))% for you on this map (\(Int(t.games.rounded()))g)")
        }
        if let t = byMode[b + "|" + md], t.games >= minGames {
            return PersonalStat(rate: Self.smooth(t), games: t.games,
                                label: "\(Int(t.wins / t.games * 100))% for you in this mode (\(Int(t.games.rounded()))g)")
        }
        if let t = overall[b], t.games >= minGames {
            return PersonalStat(rate: Self.smooth(t), games: t.games,
                                label: "\(Int(t.wins / t.games * 100))% for you overall (\(Int(t.games.rounded()))g)")
        }
        return nil
    }

    /// 0…1 — how much you tend to LOSE against this brawler (nil without data).
    func threat(enemy: String, minGames: Double? = nil) -> PersonalStat? {
        let minGames = minGames ?? DraftPlaybook.config.weights.minGames
        guard let t = vsEnemy[Self.norm(enemy)], t.games >= minGames else { return nil }
        let lossRate = t.wins / t.games
        return PersonalStat(rate: lossRate, games: t.games,
                            label: "you lose \(Int(lossRate * 100))% vs them (\(Int(t.games.rounded()))g)")
    }

    /// How a brawler performs in games you've seen, whoever played it. Fills
    /// the gap for brawlers you rarely pick so the model isn't lopsided toward
    /// your mains.
    func observedRate(brawler: String, mode: String? = nil, map: String? = nil, minGames: Double? = nil) -> PersonalStat? {
        let floor = minGames ?? DraftPlaybook.config.weights.minGames
        let b = Self.norm(brawler)
        if let mode, let map, let t = observedByMap[b + "|" + DraftPlaybook.normalizeMode(mode) + "|" + Self.norm(map)], t.games >= floor {
            return PersonalStat(rate: Self.smooth(t), games: t.games,
                                label: "wins \(Int(t.wins / t.games * 100))% on this map in games you've seen (\(Int(t.games.rounded()))g)")
        }
        if let mode, let t = observedByMode[b + "|" + DraftPlaybook.normalizeMode(mode)], t.games >= floor {
            return PersonalStat(rate: Self.smooth(t), games: t.games,
                                label: "wins \(Int(t.wins / t.games * 100))% in this mode in games you've seen (\(Int(t.games.rounded()))g)")
        }
        guard let t = observed[b], t.games >= floor else { return nil }
        return PersonalStat(rate: Self.smooth(t), games: t.games,
                            label: "wins \(Int(t.wins / t.games * 100))% in games you've seen (\(Int(t.games.rounded()))g)")
    }

    /// Sample-size coverage, for the data-balance readout.
    struct Coverage {
        var brawlersSeen: Int, withEnoughData: Int
        var yourGames: Double, observedGames: Double
        var topYours: [(String, Double)], thinnest: [(String, Double)]
    }
    func coverage() -> Coverage {
        let floor = DraftPlaybook.config.weights.minGames
        let mine = overall.map { ($0.key, $0.value.games) }.sorted { $0.1 > $1.1 }
        let obs = observed.map { ($0.key, $0.value.games) }.sorted { $0.1 > $1.1 }
        return Coverage(brawlersSeen: observed.count,
                        withEnoughData: observed.values.filter { $0.games >= floor }.count,
                        yourGames: overall.values.reduce(0) { $0 + $1.games },
                        observedGames: observed.values.reduce(0) { $0 + $1.games },
                        topYours: Array(mine.prefix(6)),
                        thinnest: Array(obs.reversed().prefix(6)))
    }

    /// Your baseline win rate on a mode (and map when known).
    func baseline(mode: String, map: String?) -> (rate: Double, games: Double)? {
        let md = DraftPlaybook.normalizeMode(mode)
        if let map, let t = mapBaseline[md + "|" + Self.norm(map)], t.games >= 4 { return (Self.smooth(t), t.games) }
        if let t = modeBaseline[md], t.games >= 4 { return (Self.smooth(t), t.games) }
        return nil
    }
}
