import Foundation

/// `/brawlers` response: the catalog of every brawler and the full set of star
/// powers / gadgets each one *can* have (used to show "not yet owned" items).
struct BrawlerCatalog: Codable {
    let items: [CatalogBrawler]
}

struct CatalogBrawler: Codable, Identifiable {
    let id: Int
    let name: String
    let starPowers: [NamedItem]
    let gadgets: [NamedItem]
}
