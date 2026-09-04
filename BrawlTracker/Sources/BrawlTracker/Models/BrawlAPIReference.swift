import Foundation

/// Static reference data from BrawlAPI (api.brawlapi.com) — the full catalog of
/// every brawler's star powers and gadgets (with descriptions), plus class,
/// rarity, and a description. Used to show items a brawler does *not* own yet
/// and richer detail. Cached on disk and refreshed weekly.
struct ReferenceResponse: Codable {
    let list: [ReferenceBrawler]
}

struct ReferenceBrawler: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let brawlerClass: ReferenceNamed?
    let rarity: ReferenceRarity?
    let starPowers: [ReferenceItem]
    let gadgets: [ReferenceItem]

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case brawlerClass = "class"
        case rarity, starPowers, gadgets
    }
}

struct ReferenceNamed: Codable {
    let id: Int?
    let name: String?
}

struct ReferenceRarity: Codable {
    let id: Int?
    let name: String?
    let color: String?
}

struct ReferenceItem: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let imageUrl: String?
}
