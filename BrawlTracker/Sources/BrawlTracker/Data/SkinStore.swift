import Foundation
import Observation

/// A skin you know about. The official API only reveals each brawler's
/// currently-equipped skin, so skins are accumulated as they're observed plus
/// anything you add by hand (with its cost).
struct SkinEntry: Identifiable, Codable, Hashable {
    enum CostType: String, Codable, CaseIterable { case bling = "Bling", gems = "Gems", coins = "Coins", free = "Free" }
    var id: String                 // "<brawler>|<skin>" normalized
    var brawler: String
    var name: String
    var owned: Bool
    var costType: CostType
    var costAmount: Int
    var fromAPI: Bool
}

@MainActor
@Observable
final class SkinStore {
    private(set) var skins: [SkinEntry] = []

    init() { load() }

    static func key(_ brawler: String, _ skin: String) -> String {
        BrawlerArt.normalize(brawler) + "|" + BrawlerArt.normalize(skin)
    }

    /// Record every non-default equipped skin from the live player data as owned.
    func observe(_ player: Player?) {
        guard let player else { return }
        var changed = false
        for b in player.brawlers {
            guard let sk = b.skin,
                  BrawlerArt.normalize(sk.name) != BrawlerArt.normalize(b.name) else { continue }
            let k = Self.key(b.name, sk.name)
            if let i = skins.firstIndex(where: { $0.id == k }) {
                if !skins[i].owned { skins[i].owned = true; changed = true }
            } else {
                skins.append(SkinEntry(id: k, brawler: b.name, name: sk.name, owned: true,
                                       costType: .bling, costAmount: 0, fromAPI: true))
                changed = true
            }
        }
        if changed { save() }
    }

    func add(brawler: String, name: String, owned: Bool, costType: SkinEntry.CostType, amount: Int) {
        let k = Self.key(brawler, name)
        if let i = skins.firstIndex(where: { $0.id == k }) {
            skins[i].owned = owned; skins[i].costType = costType; skins[i].costAmount = amount
        } else {
            skins.append(SkinEntry(id: k, brawler: brawler, name: name, owned: owned,
                                   costType: costType, costAmount: amount, fromAPI: false))
        }
        save()
    }

    func toggleOwned(_ id: String) {
        guard let i = skins.firstIndex(where: { $0.id == id }) else { return }
        skins[i].owned.toggle(); save()
    }

    func setCost(_ id: String, type: SkinEntry.CostType, amount: Int) {
        guard let i = skins.firstIndex(where: { $0.id == id }) else { return }
        skins[i].costType = type; skins[i].costAmount = amount; save()
    }

    func delete(_ id: String) { skins.removeAll { $0.id == id }; save() }

    var ownedCount: Int { skins.filter(\.owned).count }
    func spent(_ type: SkinEntry.CostType) -> Int {
        skins.filter { $0.owned && $0.costType == type }.map(\.costAmount).reduce(0, +)
    }

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("skins.json")
    }
    private func save() { if let d = try? JSONEncoder().encode(skins) { try? d.write(to: fileURL) } }
    private func load() {
        guard let d = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode([SkinEntry].self, from: d) else { return }
        skins = s
    }
}
