import Foundation

/// The competitive environment for a stretch of time.
///
/// Entirely separate from the progression `Season` in `SeasonStore`, which
/// tracks trophies and resources and is not touched by this layer. This type
/// exists from the start so dynamic data is never architected as permanently
/// global: a tier list, a map pool and a mode rotation all belong to a season,
/// even while the app still reads them from global stores.
///
/// Every reference is optional, so a season can be created before any of its
/// parts exist. Nothing is wired into the UI yet.
struct RankedSeason: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var startedAt: Date?
    var endedAt: Date?

    /// `BalanceState.version` in force. Patches land more often than seasons,
    /// so this moves within a season's lifetime.
    var balanceVersion: String?
    /// `SavedTierList.id` in `tierlists.json`.
    var tierListID: UUID?
    /// `MapDataStore.MapPool.id` in `map_pools.json`.
    var mapPoolID: UUID?
    /// BrawlAPI game-mode ids in the ranked rotation.
    var modeRotation: [Int]
    var notes: String?

    init(id: UUID = UUID(), name: String, startedAt: Date? = nil, endedAt: Date? = nil,
         balanceVersion: String? = nil, tierListID: UUID? = nil, mapPoolID: UUID? = nil,
         modeRotation: [Int] = [], notes: String? = nil) {
        self.id = id; self.name = name
        self.startedAt = startedAt; self.endedAt = endedAt
        self.balanceVersion = balanceVersion
        self.tierListID = tierListID; self.mapPoolID = mapPoolID
        self.modeRotation = modeRotation; self.notes = notes
    }

    var isActive: Bool { endedAt == nil }

    /// Which parts are still unset — a season is usable while incomplete, and
    /// this is what a later setup screen would prompt for.
    var unresolvedReferences: [String] {
        var missing: [String] = []
        if balanceVersion == nil { missing.append("balance version") }
        if tierListID == nil { missing.append("tier list") }
        if mapPoolID == nil { missing.append("map pool") }
        if modeRotation.isEmpty { missing.append("mode rotation") }
        return missing
    }

    var isFullyConfigured: Bool { unresolvedReferences.isEmpty }

    enum CodingKeys: String, CodingKey {
        case id, name, startedAt, endedAt, balanceVersion, tierListID, mapPoolID, modeRotation, notes
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        id = d.get(.id, UUID())
        name = d.get(.name, "Untitled season")
        startedAt = d.optional(.startedAt)
        endedAt = d.optional(.endedAt)
        balanceVersion = d.optional(.balanceVersion)
        tierListID = d.optional(.tierListID)
        mapPoolID = d.optional(.mapPoolID)
        modeRotation = d.get(.modeRotation, [])
        notes = d.optional(.notes)
    }
}

/// Marks data that belongs to a ranked season rather than to the app globally.
///
/// A marker only in Phase 0 — its job is to make season ownership explicit at
/// the type level as new dynamic data is added, so nothing is born global by
/// accident.
protocol SeasonScoped {
    var seasonID: UUID? { get }
}
