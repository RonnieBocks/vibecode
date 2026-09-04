import Foundation
import Observation

/// Persists the editable draft model and publishes it to the engine.
@MainActor
@Observable
final class DraftConfigStore {
    var config: DraftConfig {
        didSet {
            DraftPlaybook.config = config
            JSONStore.save(config, to: "draft_config.json")
        }
    }

    init() {
        var loaded = JSONStore.load(DraftConfig.self, from: "draft_config.json") ?? .defaults
        let migrated = Self.migrate(&loaded)
        config = loaded
        DraftPlaybook.config = loaded
        if migrated { JSONStore.save(loaded, to: "draft_config.json") }
    }

    /// Applies improved defaults to values the user never customised, so a
    /// calibration fix reaches existing installs without discarding tweaks.
    private static func migrate(_ c: inout DraftConfig) -> Bool {
        guard c.version < 2 else { return false }
        // v1 → v2: win chance was overconfident and personal results were too weak
        // to affect ranking (validated against logged matches).
        if c.weights.wpSigmoidK == 2.4 { c.weights.wpSigmoidK = 1.2 }
        if c.weights.pickPersonalMax == 250 { c.weights.pickPersonalMax = 700 }
        c.version = 2
        return true
    }

    var isDefault: Bool { config == .defaults }
    func resetWeights() { config.weights = DraftWeights() }
    func resetPlaybook() { config.playbook = .defaults }
    func resetAll() { config = .defaults }

    // Playbook editing helpers
    func setMeta(_ mode: String, _ meta: DraftMeta) { config.playbook.modeMeta[DraftPlaybook.normalizeMode(mode)] = meta.rawValue }
    func moveDominant(meta: DraftMeta, from: Int, by delta: Int) {
        var arr = meta == .aggro ? config.playbook.dominantAggro : config.playbook.dominantPassive
        let to = from + delta
        guard arr.indices.contains(from), arr.indices.contains(to) else { return }
        arr.swapAt(from, to)
        if meta == .aggro { config.playbook.dominantAggro = arr } else { config.playbook.dominantPassive = arr }
    }
    func toggleTarget(meta: DraftMeta, slot: Int, cls: DraftClass) {
        var arr = meta == .aggro ? config.playbook.targetsAggro : config.playbook.targetsPassive
        guard arr.indices.contains(slot) else { return }
        if let i = arr[slot].firstIndex(of: cls) { arr[slot].remove(at: i) } else { arr[slot].append(cls) }
        if meta == .aggro { config.playbook.targetsAggro = arr } else { config.playbook.targetsPassive = arr }
    }
    func setCallouts(_ mode: String, _ names: [String]) { config.playbook.callouts[DraftPlaybook.normalizeMode(mode)] = names }
    func setClassOverride(_ brawler: String, _ cls: DraftClass?) {
        let k = BrawlerArt.normalize(brawler)
        if let cls, cls != DraftPlaybook.baseClass(for: brawler) { config.playbook.classOverrides[k] = cls }
        else { config.playbook.classOverrides.removeValue(forKey: k) }
    }
}
