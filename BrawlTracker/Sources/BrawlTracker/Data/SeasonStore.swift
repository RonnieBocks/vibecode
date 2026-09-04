import Foundation
import Observation

/// A point-in-time capture of everything the API lets us count, so gains
/// across a season can be computed as a diff.
struct ProgressSnapshot: Codable, Equatable {
    var trophies = 0, highestTrophies = 0, expLevel = 0
    var brawlers = 0, power11 = 0
    var gadgets = 0, starPowers = 0, gears = 0, hypercharges = 0, buffies = 0
    var skins = 0            // distinct non-default equipped skins seen
    var rankedElo = 0
    var wins3v3 = 0, soloWins = 0, duoWins = 0

    static func capture(_ p: Player) -> ProgressSnapshot {
        var s = ProgressSnapshot()
        s.trophies = p.trophies
        s.highestTrophies = p.highestTrophies
        s.expLevel = p.expLevel ?? 0
        s.brawlers = p.brawlers.count
        s.power11 = p.brawlers.filter { $0.power >= 11 }.count
        s.gadgets = p.brawlers.reduce(0) { $0 + $1.gadgets.count }
        s.starPowers = p.brawlers.reduce(0) { $0 + $1.starPowers.count }
        s.gears = p.brawlers.reduce(0) { $0 + $1.gears.count }
        s.hypercharges = p.brawlers.reduce(0) { $0 + $1.hyperCharges.count }
        s.buffies = p.brawlers.reduce(0) { $0 + UpgradeCosts.ownedBuffies($1) }
        s.skins = p.brawlers.filter { b in
            guard let sk = b.skin else { return false }
            return BrawlerArt.normalize(sk.name) != BrawlerArt.normalize(b.name)
        }.count
        s.rankedElo = p.rankedElo ?? 0
        s.wins3v3 = p.threeVsThreeVictories ?? 0
        s.soloWins = p.soloVictories ?? 0
        s.duoWins = p.duoVictories ?? 0
        return s
    }

    /// other − self
    func delta(to other: ProgressSnapshot) -> ProgressSnapshot {
        var d = ProgressSnapshot()
        d.trophies = other.trophies - trophies
        d.highestTrophies = other.highestTrophies - highestTrophies
        d.expLevel = other.expLevel - expLevel
        d.brawlers = other.brawlers - brawlers
        d.power11 = other.power11 - power11
        d.gadgets = other.gadgets - gadgets
        d.starPowers = other.starPowers - starPowers
        d.gears = other.gears - gears
        d.hypercharges = other.hypercharges - hypercharges
        d.buffies = other.buffies - buffies
        d.skins = other.skins - skins
        d.rankedElo = other.rankedElo - rankedElo
        d.wins3v3 = other.wins3v3 - wins3v3
        d.soloWins = other.soloWins - soloWins
        d.duoWins = other.duoWins - duoWins
        return d
    }
}

/// Currency balances aren't in the API — logged manually.
struct ResourceEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var gold: Int
    var powerPoints: Int
    var gems: Int
    var bling: Int
}

struct Season: Identifiable, Codable {
    var id: UUID
    var name: String
    var start: Date
    var end: Date?
    var startSnapshot: ProgressSnapshot
    var endSnapshot: ProgressSnapshot?
    var resources: [ResourceEntry]

    var isActive: Bool { end == nil }
    func gains(current: ProgressSnapshot?) -> ProgressSnapshot {
        startSnapshot.delta(to: endSnapshot ?? current ?? startSnapshot)
    }
    /// Latest logged balances minus the first logged balances.
    var resourceDelta: ResourceEntry? {
        guard let first = resources.first, let last = resources.last, resources.count >= 2 else { return nil }
        return ResourceEntry(id: UUID(), date: last.date, gold: last.gold - first.gold,
                             powerPoints: last.powerPoints - first.powerPoints,
                             gems: last.gems - first.gems, bling: last.bling - first.bling)
    }
}

@MainActor
@Observable
final class SeasonStore {
    private(set) var seasons: [Season] = []   // newest first

    init() { load() }

    var active: Season? { seasons.first { $0.isActive } }

    func startSeason(named name: String, player: Player) {
        // Close any open season first.
        if let i = seasons.firstIndex(where: { $0.isActive }) {
            seasons[i].end = Date()
            seasons[i].endSnapshot = .capture(player)
        }
        let s = Season(id: UUID(), name: name.isEmpty ? "Season \(seasons.count + 1)" : name,
                       start: Date(), end: nil, startSnapshot: .capture(player), endSnapshot: nil, resources: [])
        seasons.insert(s, at: 0)
        save()
    }

    func endActive(player: Player) {
        guard let i = seasons.firstIndex(where: { $0.isActive }) else { return }
        seasons[i].end = Date()
        seasons[i].endSnapshot = .capture(player)
        save()
    }

    func logResources(gold: Int, powerPoints: Int, gems: Int, bling: Int) {
        guard let i = seasons.firstIndex(where: { $0.isActive }) else { return }
        seasons[i].resources.append(ResourceEntry(id: UUID(), date: Date(), gold: gold,
                                                  powerPoints: powerPoints, gems: gems, bling: bling))
        save()
    }

    func delete(_ id: UUID) { seasons.removeAll { $0.id == id }; save() }

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("seasons.json")
    }
    private func save() { if let d = try? JSONEncoder().encode(seasons) { try? d.write(to: fileURL) } }
    private func load() {
        guard let d = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode([Season].self, from: d) else { return }
        seasons = s
    }
}
