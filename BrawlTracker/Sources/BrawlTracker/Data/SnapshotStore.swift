import Foundation
import Observation

/// Minimal per-brawler state captured in a launch snapshot.
struct BrawlerSnap: Codable {
    var id: Int, name: String, power: Int, trophies: Int
    var gadgets: Int, starPowers: Int, gears: Int, hypercharges: Int, buffies: Int
}

/// A dated capture of the account taken on each successful live fetch.
struct LaunchSnapshot: Identifiable, Codable {
    var id: UUID
    var date: Date
    var progress: ProgressSnapshot
    var brawlers: [BrawlerSnap]
}

/// Snapshot history (data only — no charts by design). One entry per fetch
/// that actually changed something, so the file stays small.
@MainActor
@Observable
final class SnapshotStore {
    private(set) var snapshots: [LaunchSnapshot] = []   // oldest first

    init() { snapshots = JSONStore.load([LaunchSnapshot].self, from: "snapshots.json") ?? [] }

    var latest: LaunchSnapshot? { snapshots.last }

    /// Records a snapshot unless it's identical to the previous one.
    func record(_ player: Player) {
        let snap = LaunchSnapshot(
            id: UUID(), date: Date(), progress: .capture(player),
            brawlers: player.brawlers.map {
                BrawlerSnap(id: $0.id, name: $0.name, power: $0.power, trophies: $0.trophies,
                            gadgets: $0.gadgets.count, starPowers: $0.starPowers.count, gears: $0.gears.count,
                            hypercharges: $0.hyperCharges.count, buffies: UpgradeCosts.ownedBuffies($0))
            })
        if let last = latest, last.progress == snap.progress { return }
        snapshots.append(snap)
        if snapshots.count > 400 { snapshots.removeFirst(snapshots.count - 400) }
        JSONStore.save(snapshots, to: "snapshots.json")
    }

    /// First snapshot at/after a date (e.g. a season start).
    func snapshot(onOrAfter date: Date) -> LaunchSnapshot? { snapshots.first { $0.date >= date } }
}
