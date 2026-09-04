import Foundation
import Observation

/// Per-brawler ranked settings — which brawlers to hide from the Ranked draft
/// assistant (promo / non-draftable brawlers). Seeded once with the defaults.
@MainActor
@Observable
final class RankedSettings {
    private(set) var hiddenNames: Set<String> = []

    private static let defaults = ["Buzz Lightyear", "Cosmo", "Vince"]

    init() { load() }

    func isHidden(_ name: String) -> Bool { hiddenNames.contains(BrawlerArt.normalize(name)) }

    func toggleHidden(_ name: String) {
        let key = BrawlerArt.normalize(name)
        if hiddenNames.contains(key) { hiddenNames.remove(key) } else { hiddenNames.insert(key) }
        save()
    }

    // MARK: - Persistence

    private struct Persisted: Codable { var hidden: [String]; var seeded: Bool }

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ranked_settings.json")
    }

    private func save() {
        let payload = Persisted(hidden: Array(hiddenNames), seeded: true)
        if let data = try? JSONEncoder().encode(payload) { try? data.write(to: fileURL) }
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data), decoded.seeded {
            hiddenNames = Set(decoded.hidden)
            return
        }
        hiddenNames = Set(Self.defaults.map { BrawlerArt.normalize($0) })
        save()
    }
}
