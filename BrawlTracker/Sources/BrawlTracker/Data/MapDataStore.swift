import Foundation
import Observation

/// Loads BrawlAPI maps + game modes with a 7-day on-disk cache (same pattern as
/// the reference data). Exposed as an observable store for the Maps tab.
@MainActor
@Observable
final class MapDataStore {
    var maps: [GameMap] = []
    var modes: [GameMode] = []
    var isLoading = false
    var loaded = false

    /// A saved, named map pool (one per season's rotation).
    struct MapPool: Identifiable, Codable, Hashable {
        var id: UUID
        var name: String
        var mapIDs: [Int]
    }

    private(set) var pools: [MapPool] = []
    private(set) var activePoolID: UUID = UUID()

    private let mapsURL = URL(string: "https://api.brawlapi.com/v1/maps")!
    private let modesURL = URL(string: "https://api.brawlapi.com/v1/gamemodes")!
    private let maxAge: TimeInterval = 7 * 24 * 3600

    init() { loadPools() }

    // MARK: - Active pool membership

    var activePool: MapPool? { pools.first { $0.id == activePoolID } }
    private var activePoolIndex: Int? { pools.firstIndex { $0.id == activePoolID } }

    /// Map ids in the active pool (set for quick membership checks).
    var rotation: Set<Int> { Set(activePool?.mapIDs ?? []) }

    func isInRotation(_ id: Int) -> Bool { activePool?.mapIDs.contains(id) ?? false }

    func toggleRotation(_ id: Int) {
        guard let i = activePoolIndex else { return }
        if let idx = pools[i].mapIDs.firstIndex(of: id) { pools[i].mapIDs.remove(at: idx) }
        else { pools[i].mapIDs.append(id) }
        savePools()
    }

    func clearRotation() {
        guard let i = activePoolIndex else { return }
        pools[i].mapIDs = []
        savePools()
    }

    /// The active pool's maps, sorted by mode then name.
    var rotationMaps: [GameMap] {
        maps.filter { rotation.contains($0.id) }
            .sorted { ($0.gameMode?.name ?? "", $0.name) < ($1.gameMode?.name ?? "", $1.name) }
    }

    /// Distinct game modes represented in the active pool.
    var rotationModes: [GameMode] {
        let ids = Set(rotationMaps.compactMap { $0.gameMode?.id })
        return modes.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    // MARK: - Live rotation autofill (BrawlAPI /v1/events)

    struct EventsResponse: Codable { let active: [EventEntry]?; let upcoming: [EventEntry]? }
    struct EventEntry: Codable { let slot: EventSlot?; let map: GameMap? }
    struct EventSlot: Codable { let id: Int?; let name: String?; let hash: String? }

    struct AutofillResult { let found: Int; let added: Int; let rankedOnly: Bool }

    /// Pulls the current event rotation and adds its maps to the active pool.
    /// If any slot is labelled ranked/power-league, only those are used.
    func autofillFromEvents(includeUpcoming: Bool = false) async -> AutofillResult {
        var req = URLRequest(url: URL(string: "https://api.brawlapi.com/v1/events")!)
        req.setValue("BrawlTracker/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let events = try? JSONDecoder().decode(EventsResponse.self, from: data) else {
            return AutofillResult(found: 0, added: 0, rankedOnly: false)
        }
        var entries = events.active ?? []
        if includeUpcoming { entries += events.upcoming ?? [] }
        let ranked = entries.filter { ($0.slot?.name ?? "").lowercased().contains("rank") || ($0.slot?.name ?? "").lowercased().contains("league") }
        let chosen = ranked.isEmpty ? entries : ranked
        let ids = chosen.compactMap { $0.map?.id }
        guard !ids.isEmpty, let i = activePoolIndex else {
            return AutofillResult(found: ids.count, added: 0, rankedOnly: !ranked.isEmpty)
        }
        var added = 0
        for id in ids where !pools[i].mapIDs.contains(id) { pools[i].mapIDs.append(id); added += 1 }
        // Make sure any new maps are in the catalog too.
        for e in chosen { if let m = e.map, !maps.contains(where: { $0.id == m.id }) { maps.append(m) } }
        savePools()
        return AutofillResult(found: ids.count, added: added, rankedOnly: !ranked.isEmpty)
    }

    // MARK: - Pool management

    func selectPool(_ id: UUID) { activePoolID = id; savePools() }

    func newPool(named name: String) {
        let pool = MapPool(id: UUID(), name: cleanName(name, fallback: "New Pool"), mapIDs: [])
        pools.append(pool); activePoolID = pool.id; savePools()
    }

    func duplicateActivePool(named name: String) {
        guard let active = activePool else { return }
        let pool = MapPool(id: UUID(), name: cleanName(name, fallback: active.name + " copy"),
                           mapIDs: active.mapIDs)
        pools.append(pool); activePoolID = pool.id; savePools()
    }

    func renameActivePool(to name: String) {
        guard let i = activePoolIndex else { return }
        pools[i].name = cleanName(name, fallback: pools[i].name); savePools()
    }

    func deleteActivePool() {
        guard pools.count > 1, let i = activePoolIndex else { return }
        pools.remove(at: i); activePoolID = pools.first!.id; savePools()
    }

    private func cleanName(_ name: String, fallback: String) -> String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    /// Loads once (from cache if fresh, else network). Safe to call repeatedly.
    func loadIfNeeded() async {
        guard !loaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let mapsList = cachedList("maps_cache.json", url: mapsURL,
                                        decode: { try JSONDecoder().decode(MapsResponse.self, from: $0).list })
        async let modesList = cachedList("gamemodes_cache.json", url: modesURL,
                                         decode: { try JSONDecoder().decode(GameModesResponse.self, from: $0).list })
        maps = await mapsList
        modes = await modesList
        loaded = !maps.isEmpty
    }

    // MARK: - Cached fetch

    private var dir: URL {
        let d = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Generic: use fresh cache, else fetch + write cache, else stale cache, else [].
    private func cachedList<T>(_ file: String, url: URL,
                               decode: @escaping (Data) throws -> [T]) async -> [T] {
        let cacheURL = dir.appendingPathComponent(file)

        if let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < maxAge,
           let data = try? Data(contentsOf: cacheURL),
           let list = try? decode(data) {
            return list
        }

        var request = URLRequest(url: url)
        request.setValue("BrawlTracker/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 25
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let list = try? decode(data) {
            try? data.write(to: cacheURL)
            return list
        }

        if let data = try? Data(contentsOf: cacheURL), let list = try? decode(data) {
            return list
        }
        return []
    }

    // MARK: - Pool persistence

    private struct PersistedPools: Codable {
        var pools: [MapPool]
        var activeID: UUID
    }

    private var poolsURL: URL { dir.appendingPathComponent("map_pools.json") }
    private var legacyRotationURL: URL { dir.appendingPathComponent("rotation.json") }

    private func savePools() {
        let payload = PersistedPools(pools: pools, activeID: activePoolID)
        if let data = try? JSONEncoder().encode(payload) { try? data.write(to: poolsURL) }
    }

    private func loadPools() {
        if let data = try? Data(contentsOf: poolsURL),
           let decoded = try? JSONDecoder().decode(PersistedPools.self, from: data),
           !decoded.pools.isEmpty {
            pools = decoded.pools
            activePoolID = decoded.pools.contains { $0.id == decoded.activeID }
                ? decoded.activeID : decoded.pools[0].id
            return
        }
        // Migrate the old single rotation.json into a first named pool.
        if let data = try? Data(contentsOf: legacyRotationURL),
           let ids = try? JSONDecoder().decode([Int].self, from: data) {
            let pool = MapPool(id: UUID(), name: "Current Rotation", mapIDs: ids)
            pools = [pool]; activePoolID = pool.id; savePools(); return
        }
        let first = MapPool(id: UUID(), name: "Current Rotation", mapIDs: [])
        pools = [first]; activePoolID = first.id; savePools()
    }
}
