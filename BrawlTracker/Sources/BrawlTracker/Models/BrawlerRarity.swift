import SwiftUI

/// Brawler rarity and its card-background color, matched to noff.gg's palette.
/// The player API does not expose rarity, so this table is bundled; lookups
/// use the same name-normalization as artwork (see BrawlerArt.normalize).
enum Rarity: String, CaseIterable {
    case common, rare, superRare, epic, mythic, legendary, ultraLegendary, unknown

    var label: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .superRare: return "Super Rare"
        case .epic: return "Epic"
        case .mythic: return "Mythic"
        case .legendary: return "Legendary"
        case .ultraLegendary: return "Ultra Legendary"
        case .unknown: return "Unknown"
        }
    }

    /// Base card-background color (noff.gg palette).
    var color: Color {
        switch self {
        case .common: return Color(red: 148/255, green: 215/255, blue: 244/255)
        case .rare: return Color(red: 46/255, green: 221/255, blue: 28/255)
        case .superRare: return Color(red: 22/255, green: 147/255, blue: 255/255)
        case .epic: return Color(red: 177/255, green: 22/255, blue: 237/255)
        case .mythic: return Color(red: 239/255, green: 65/255, blue: 64/255)
        case .legendary: return Color(red: 248/255, green: 200/255, blue: 32/255)
        case .ultraLegendary: return Color(red: 38/255, green: 44/255, blue: 60/255)
        case .unknown: return Color(white: 0.35)
        }
    }
}

enum BrawlerRarityTable {
    static let byName: [String: Rarity] = [
        "8bit": .superRare,
        "alli": .mythic,
        "amber": .legendary,
        "angelo": .epic,
        "ash": .epic,
        "barley": .rare,
        "bea": .epic,
        "belle": .epic,
        "berry": .epic,
        "bibi": .epic,
        "bo": .epic,
        "bolt": .epic,
        "bonnie": .epic,
        "brock": .rare,
        "bull": .rare,
        "buster": .mythic,
        "buzz": .mythic,
        "byron": .mythic,
        "carl": .superRare,
        "charlie": .mythic,
        "chester": .legendary,
        "chuck": .mythic,
        "clancy": .mythic,
        "colette": .epic,
        "colt": .rare,
        "cordelius": .legendary,
        "crow": .legendary,
        "damian": .mythic,
        "darryl": .superRare,
        "doug": .mythic,
        "draco": .legendary,
        "dynamike": .superRare,
        "edgar": .epic,
        "elprimo": .rare,
        "emz": .epic,
        "eve": .mythic,
        "fang": .mythic,
        "finx": .mythic,
        "frank": .epic,
        "gale": .epic,
        "gene": .mythic,
        "gigi": .mythic,
        "glowy": .mythic,
        "gray": .mythic,
        "griff": .epic,
        "grom": .epic,
        "gus": .superRare,
        "hank": .epic,
        "jacky": .superRare,
        "jaeyong": .mythic,
        "janet": .mythic,
        "jessie": .superRare,
        "juju": .mythic,
        "kaze": .ultraLegendary,
        "kenji": .legendary,
        "kit": .legendary,
        "larrylawrie": .epic,
        "leon": .legendary,
        "lily": .mythic,
        "lola": .epic,
        "lou": .mythic,
        "lumi": .mythic,
        "maisie": .epic,
        "mandy": .epic,
        "max": .mythic,
        "meeple": .epic,
        "meg": .legendary,
        "melodie": .mythic,
        "mico": .mythic,
        "mina": .mythic,
        "moe": .mythic,
        "mortis": .mythic,
        "mrp": .mythic,
        "najia": .mythic,
        "nani": .epic,
        "nita": .rare,
        "nori": .legendary,
        "ollie": .mythic,
        "otis": .mythic,
        "pam": .epic,
        "pearl": .epic,
        "penny": .superRare,
        "pierce": .legendary,
        "piper": .epic,
        "poco": .rare,
        "rico": .superRare,
        "rosa": .rare,
        "rt": .mythic,
        "ruffs": .mythic,
        "sam": .epic,
        "sandy": .legendary,
        "shade": .epic,
        "shelly": .common,
        "sirius": .ultraLegendary,
        "spike": .legendary,
        "sprout": .mythic,
        "squeak": .mythic,
        "starrnova": .mythic,
        "stu": .epic,
        "surge": .legendary,
        "tara": .mythic,
        "tick": .superRare,
        "trunk": .epic,
        "wendy": .mythic,
        "willow": .mythic,
        "ziggy": .mythic
    ]

    static func rarity(for name: String) -> Rarity {
        byName[BrawlerArt.normalize(name)] ?? .unknown
    }
}
