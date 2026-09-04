import Foundation

/// `/v1/maps` from BrawlAPI — every map with its game mode, environment, and a
/// map image (hosted on brawlify's CDN).
struct MapsResponse: Codable {
    let list: [GameMap]
}

struct GameMap: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let hash: String?
    let imageUrl: String?
    let disabled: Bool?
    let isNew: Bool?
    let gameMode: MapGameMode?
    let environment: MapEnvironment?

    enum CodingKeys: String, CodingKey {
        case id, name, hash, imageUrl, disabled
        case isNew = "new"
        case gameMode, environment
    }
}

struct MapGameMode: Codable, Hashable {
    let id: Int?
    let name: String?
    let color: String?
    let bgColor: String?
    let imageUrl: String?
}

struct MapEnvironment: Codable, Hashable {
    let id: Int?
    let name: String?
}

/// `/v1/gamemodes` from BrawlAPI — the catalog of game modes.
struct GameModesResponse: Codable {
    let list: [GameMode]
}

struct GameMode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String?
    let bgColor: String?
    let imageUrl: String?
    let shortDescription: String?
    let description: String?
    let scHash: String?
}
