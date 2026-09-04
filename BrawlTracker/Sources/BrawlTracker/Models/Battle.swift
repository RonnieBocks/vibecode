import Foundation

/// `/players/{tag}/battlelog` response: the last ~25 battles. Shapes vary by
/// mode (3v3 modes use `teams`; showdown uses `players` and `rank` instead of
/// `result`), so most fields are optional.
struct BattleLog: Codable {
    let items: [BattleEntry]
}

struct BattleEntry: Codable, Identifiable {
    let battleTime: String
    let event: BattleEvent?
    let battle: BattleInfo?

    /// Stable id for dedupe/storage: battle time + mode.
    var id: String { "\(battleTime)|\(event?.mode ?? battle?.mode ?? "")" }
}

struct BattleEvent: Codable {
    let id: Int?
    let mode: String?
    let map: String?
}

struct BattleInfo: Codable {
    let mode: String?
    let type: String?          // e.g. "ranked", "soloRanked", "teamRanked", "friendly"
    let result: String?        // victory / defeat / draw (nil for showdown)
    let rank: Int?             // showdown finishing rank
    let duration: Int?
    let trophyChange: Int?
    let starPlayer: BattlePlayer?
    let teams: [[BattlePlayer]]?
    let players: [BattlePlayer]?

    var isRanked: Bool {
        (type?.lowercased().contains("ranked")) ?? false
    }
}

struct BattlePlayer: Codable {
    let tag: String?
    let name: String?
    let brawler: BattleBrawler?
}

struct BattleBrawler: Codable {
    let id: Int?
    let name: String?
    let power: Int?
    let trophies: Int?
    let trophyChange: Int?
}
