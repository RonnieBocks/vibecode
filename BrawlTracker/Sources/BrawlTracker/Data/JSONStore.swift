import Foundation

/// Shared on-disk persistence for every store: one folder in Application
/// Support, JSON in/out, no boilerplate.
enum JSONStore {
    static var directory: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(_ file: String) -> URL { directory.appendingPathComponent(file) }

    static func save<T: Encodable>(_ value: T, to file: String) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) { try? data.write(to: url(file), options: .atomic) }
    }

    static func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        guard let data = try? Data(contentsOf: url(file)) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let v = try? dec.decode(T.self, from: data) { return v }
        // Fallback for files written before ISO-8601 dates were used.
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Every data file, for backup/export.
    static let allFiles = ["tierlists.json", "map_pools.json", "matches.json", "battles.json",
                           "seasons.json", "skins.json", "ranked_settings.json", "snapshots.json"]
}
