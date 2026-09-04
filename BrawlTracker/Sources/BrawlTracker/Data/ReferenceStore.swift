import Foundation

/// Loads BrawlAPI reference data with a 7-day on-disk cache, so the third-party
/// endpoint is hit at most weekly rather than every launch. Failure is
/// non-fatal: a stale cache (or empty) is returned so the app keeps working.
enum ReferenceStore {
    private static let url = URL(string: "https://api.brawlapi.com/v1/brawlers")!
    private static let maxAge: TimeInterval = 7 * 24 * 3600

    private static var cacheURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("brawlapi_cache.json")
    }

    /// Returns brawler id -> reference entry. Uses fresh cache, else fetches,
    /// else falls back to any stale cache, else empty.
    static func load() async -> [Int: ReferenceBrawler] {
        if let cached = readCache(), isFresh(cacheURL) {
            return index(cached)
        }
        if let fetched = await fetch() {
            writeCache(fetched)
            return index(fetched)
        }
        if let stale = readCache() {
            return index(stale)
        }
        return [:]
    }

    // MARK: - Helpers

    private static func index(_ list: [ReferenceBrawler]) -> [Int: ReferenceBrawler] {
        Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private static func isFresh(_ url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else { return false }
        return Date().timeIntervalSince(modified) < maxAge
    }

    private static func readCache() -> [ReferenceBrawler]? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(ReferenceResponse.self, from: data).list
    }

    private static func writeCache(_ list: [ReferenceBrawler]) {
        let payload = ReferenceResponse(list: list)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: cacheURL)
        }
    }

    private static func fetch() async -> [ReferenceBrawler]? {
        var request = URLRequest(url: url)
        request.setValue("BrawlTracker/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ReferenceResponse.self, from: data) else {
            return nil
        }
        return decoded.list
    }
}
