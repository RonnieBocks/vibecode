import Foundation

/// Result of a single game within a ranked best-of-3 series.
enum GameResult: String, Codable, CaseIterable {
    case win = "W"
    case loss = "L"
    case none = "X"     // not played (series ended early)
}

/// A completed ranked match: the draft plus the best-of-3 series result.
struct MatchRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var mode: String
    var mapName: String
    var myTeam: [String]      // brawler names, in pick order
    var enemyTeam: [String]
    var bans: [String]
    var series: [GameResult]  // three games
    var wonToss: Bool
    var mySlot: Int

    // Added for match review (optional so older records still decode).
    var winChance: Double?
    var myBrawler: String?
    var picksInOrder: [DraftPickRecord]?
    var mySuggestions: [String]?        // engine's top picks at your turn
    var myPickWasSuggested: Bool?
    var banSuggestions: [String]?       // engine's top bans at your ban
    var myBan: String?

    /// Your post-match notes: free text plus quick tags. Both optional so
    /// matches saved before this existed still decode.
    var notes: String?
    var noteTags: [String]?

    /// The series was cut short by a crash or disconnect, so fewer than the
    /// full three games were played and the series verdict is meaningless.
    /// The games that *were* played are still real and still feed learning —
    /// only the series-level win/loss and the win-chance calibration ignore it.
    var incomplete: Bool?

    var tags: [MatchNoteTag] { (noteTags ?? []).compactMap(MatchNoteTag.init(rawValue:)) }
    var hasNotes: Bool { !(notes ?? "").isEmpty || !(noteTags ?? []).isEmpty }

    var seriesText: String { series.map(\.rawValue).joined(separator: "-") }
    var wins: Int { series.filter { $0 == .win }.count }
    var losses: Int { series.filter { $0 == .loss }.count }
    var seriesWon: Bool { wins > losses }
    var isIncomplete: Bool { incomplete ?? false }
    /// Only complete series say anything about whether the draft won the match.
    var countsForRecord: Bool { !isIncomplete }
    var gamesPlayed: Int { wins + losses }
}

/// One pick in draft order.
struct DraftPickRecord: Codable, Identifiable {
    var globalPick: Int
    var seat: Int
    var brawler: String
    var isMine: Bool
    var isAlly: Bool
    var id: Int { globalPick }
}


/// Quick tags for a finished match. Deliberately about *why* it went the way
/// it did, so draft quality can be told apart from execution when reviewing.
enum MatchNoteTag: String, Codable, CaseIterable, Identifiable {
    case draftGood      = "Draft was good"
    case draftBad       = "Draft was bad"
    case suggestionGood = "Suggestion worked"
    case suggestionBad  = "Suggestion missed"
    case iMisplayed     = "I misplayed"
    case teammateIssue  = "Teammate issue"
    case gotCountered   = "Got countered"
    case tierStale      = "Tier list stale"
    case mapSpecific    = "Map-specific"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .draftGood, .suggestionGood: return "checkmark.circle.fill"
        case .draftBad, .suggestionBad: return "xmark.circle.fill"
        case .iMisplayed: return "person.fill.xmark"
        case .teammateIssue: return "person.2.slash"
        case .gotCountered: return "shield.slash"
        case .tierStale: return "arrow.up.arrow.down.circle"
        case .mapSpecific: return "map"
        }
    }

    /// Tags that say something about the model rather than the play.
    var isModelFeedback: Bool {
        self == .suggestionGood || self == .suggestionBad || self == .tierStale || self == .mapSpecific
    }
}
