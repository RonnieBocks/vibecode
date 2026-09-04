import Foundation

/// Top-level `/players/{tag}` response from the official Brawl Stars API.
/// Field names and shapes are taken verbatim from a real account pull
/// (see Resources/sample_player.json), including a few fields that aren't in
/// the public docs but are confirmed present: `buffies` and the `ranked*` set.
struct Player: Codable {
    let tag: String
    let name: String
    let nameColor: String?
    let icon: PlayerIcon?

    let trophies: Int
    let highestTrophies: Int
    let totalPrestigeLevel: Int?
    let expLevel: Int?
    let expPoints: Int?

    let soloVictories: Int?
    let duoVictories: Int?
    let threeVsThreeVictories: Int?
    let isQualifiedFromChampionshipChallenge: Bool?
    let bestRoboRumbleTime: Int?
    let bestTimeAsBigBrawler: Int?

    let rankedSeasonId: Int?
    let rankedRank: Int?
    let rankedRankName: String?
    let rankedElo: Int?
    let highestSeasonRankedRank: Int?
    let highestSeasonRankedRankName: String?
    let highestSeasonRankedElo: Int?
    let highestAllTimeRankedRank: Int?
    let highestAllTimeRankedRankName: String?
    let highestAllTimeRankedElo: Int?

    let club: Club?
    let brawlers: [Brawler]

    enum CodingKeys: String, CodingKey {
        case tag, name, nameColor, icon
        case trophies, highestTrophies, totalPrestigeLevel, expLevel, expPoints
        case soloVictories, duoVictories
        case threeVsThreeVictories = "3vs3Victories"
        case isQualifiedFromChampionshipChallenge, bestRoboRumbleTime, bestTimeAsBigBrawler
        case rankedSeasonId, rankedRank, rankedRankName, rankedElo
        case highestSeasonRankedRank, highestSeasonRankedRankName, highestSeasonRankedElo
        case highestAllTimeRankedRank, highestAllTimeRankedRankName, highestAllTimeRankedElo
        case club, brawlers
    }
}

struct PlayerIcon: Codable {
    let id: Int
}

struct Club: Codable {
    let tag: String?
    let name: String?
}

/// One brawler as returned inside a player payload. Note the API reports what
/// the account *owns* (unlocked) — there is no "currently equipped" flag, so
/// these lists are the full owned set, not a single active loadout.
struct Brawler: Codable, Identifiable {
    let id: Int
    let name: String
    let power: Int
    let rank: Int
    let trophies: Int
    let highestTrophies: Int
    let prestigeLevel: Int?
    let currentWinStreak: Int?
    let maxWinStreak: Int?
    let skin: NamedItem?

    let gadgets: [NamedItem]
    let starPowers: [NamedItem]
    let gears: [Gear]
    let hyperCharges: [NamedItem]
    let buffies: Buffies?

    // Convenience
    var hasHypercharge: Bool { !hyperCharges.isEmpty }
    var isMaxPower: Bool { power >= 11 }

    /// "Ranked Eligible": fully kitted so the brawler is at no loadout
    /// disadvantage — at least one gadget, one star power, two gears, and a
    /// hypercharge unlocked.
    var isRankedEligible: Bool {
        !gadgets.isEmpty && !starPowers.isEmpty && gears.count >= 2 && !hyperCharges.isEmpty
    }
}

/// id + name pair used for gadgets, star powers, hypercharges, skins.
struct NamedItem: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

/// Gears additionally carry a level.
struct Gear: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let level: Int?
}

/// New-ish game feature; the API exposes which categories have an active buffy.
struct Buffies: Codable {
    let gadget: Bool
    let starPower: Bool
    let hyperCharge: Bool
}
