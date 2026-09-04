import Foundation
import Observation

/// One archived battle, from your perspective.
struct BattleRecord: Identifiable, Codable {
    enum Outcome: String, Codable { case win, loss, draw }
    var id: String
    var time: Date
    var mode: String
    var map: String
    var type: String
    var outcome: Outcome
    var trophyChange: Int
    var myBrawler: String?
    var starPlayer: Bool
    var isRanked: Bool
    var showdownRank: Int?
    /// Everyone else in the game, so brawler records stay balanced instead of
    /// only accumulating for the brawlers you personally play. Optional so
    /// battles archived before this existed still decode.
    var allies: [String]?
    var opponents: [String]?
}

/// Permanent, de-duplicated archive of battles. The API only keeps the last
/// ~25, so every launch appends what's new and the history grows over time.
@MainActor
@Observable
final class BattleArchiveStore {
    private(set) var records: [BattleRecord] = []   // newest first

    init() { load() }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss.SSS'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Append any entries not already archived. Returns how many were new.
    @discardableResult
    func ingest(_ entries: [BattleEntry], myTag: String) -> Int {
        let existing = Set(records.map(\.id))
        let tag = myTag.uppercased()
        var added: [BattleRecord] = []
        for e in entries where !existing.contains(e.id) {
            guard let b = e.battle else { continue }
            let time = Self.timeFormatter.date(from: e.battleTime) ?? Date()
            let everyone = (b.teams?.flatMap { $0 } ?? []) + (b.players ?? [])
            let me = everyone.first { ($0.tag ?? "").uppercased() == tag }
            // Split the two teams around you (3v3 modes only).
            var allies: [String] = [], opponents: [String] = []
            if let teams = b.teams, teams.count == 2 {
                let mineIdx = teams.firstIndex { team in team.contains { ($0.tag ?? "").uppercased() == tag } }
                if let mineIdx {
                    allies = teams[mineIdx].filter { ($0.tag ?? "").uppercased() != tag }.compactMap { $0.brawler?.name }
                    opponents = teams[1 - mineIdx].compactMap { $0.brawler?.name }
                }
            }
            let outcome: BattleRecord.Outcome
            switch b.result?.lowercased() {
            case "victory": outcome = .win
            case "defeat": outcome = .loss
            case "draw": outcome = .draw
            default:
                let tc = b.trophyChange ?? 0
                outcome = tc > 0 ? .win : (tc < 0 ? .loss : .draw)
            }
            added.append(BattleRecord(
                id: e.id, time: time,
                mode: e.event?.mode ?? b.mode ?? "unknown",
                map: e.event?.map ?? "—",
                type: b.type ?? "",
                outcome: outcome,
                trophyChange: b.trophyChange ?? 0,
                myBrawler: me?.brawler?.name,
                starPlayer: (b.starPlayer?.tag ?? "").uppercased() == tag,
                isRanked: b.isRanked,
                showdownRank: b.rank,
                allies: allies.isEmpty ? nil : allies,
                opponents: opponents.isEmpty ? nil : opponents))
        }
        guard !added.isEmpty else { return 0 }
        records = (records + added).sorted { $0.time > $1.time }
        save()
        return added.count
    }

    func clear() { records = []; save() }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("battles.json")
    }
    private func save() {
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: fileURL) }
    }
    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BattleRecord].self, from: data) else { return }
        records = decoded
    }
}

/// Aggregated stats for one group (a brawler, mode, or map).
struct StatLine: Identifiable {
    let name: String
    var games = 0
    var wins = 0
    var trophies = 0
    var id: String { name }
    var winRate: Double { games > 0 ? Double(wins) / Double(games) : 0 }
}

enum BattleStats {
    static func group(_ records: [BattleRecord], by key: (BattleRecord) -> String?) -> [StatLine] {
        var map: [String: StatLine] = [:]
        for r in records {
            guard let k = key(r), !k.isEmpty else { continue }
            var line = map[k] ?? StatLine(name: k)
            line.games += 1
            if r.outcome == .win { line.wins += 1 }
            line.trophies += r.trophyChange
            map[k] = line
        }
        return map.values.sorted { $0.games == $1.games ? $0.winRate > $1.winRate : $0.games > $1.games }
    }

    static func winRate(_ records: [BattleRecord]) -> Double {
        let decided = records.filter { $0.outcome != .draw }
        guard !decided.isEmpty else { return 0 }
        return Double(decided.filter { $0.outcome == .win }.count) / Double(decided.count)
    }

    static func prettyMode(_ raw: String) -> String {
        // "gemGrab" -> "Gem Grab"
        var out = ""
        for (i, ch) in raw.enumerated() {
            if ch.isUppercase && i > 0 { out += " " }
            out += String(i == 0 ? Character(ch.uppercased()) : ch)
        }
        return out
    }
}
