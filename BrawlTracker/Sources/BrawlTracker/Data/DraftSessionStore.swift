import Foundation
import Observation

/// Owns the in-progress ranked draft at app level, so switching tabs — which
/// tears the Ranked view down — never discards it. Also written to disk, so a
/// quit or crash mid-draft can be resumed.
@MainActor
@Observable
final class DraftSessionStore {
    private(set) var session: DraftSession?

    init() { session = Self.load() }

    func start() {
        session = DraftSession()
        save()
    }

    /// Finish or discard the current draft.
    func end() {
        session = nil
        try? FileManager.default.removeItem(at: JSONStore.url(Self.file))
    }

    func save() {
        guard let s = session else { return }
        JSONStore.save(Snapshot(s), to: Self.file)
    }

    // MARK: - Persistence

    private static let file = "draft_session.json"

    /// A plain mirror of the session: @Observable classes can't synthesise
    /// Codable, so the state is copied in and out explicitly.
    @MainActor
    private struct Snapshot: Codable {
        var phase: DraftSession.Phase
        var mode: String?
        var map: GameMap?
        var wonToss: Bool?
        var mySeat: Int?
        var activeBanSeat: Int?
        var seatBans: [Int: Int]
        var seatPicks: [Int: Int]
        var series: [GameResult]
        var notes: String
        var noteTags: [MatchNoteTag]
        var incomplete: Bool?
        var history: [DraftHistoryEntry]
        var banSuggestionSnapshot: [String]
        var pickSuggestionSnapshot: [String]
        var myPickWasSuggested: Bool?

        init(_ s: DraftSession) {
            phase = s.phase; mode = s.mode; map = s.map; wonToss = s.wonToss
            mySeat = s.mySeat; activeBanSeat = s.activeBanSeat
            seatBans = s.seatBans; seatPicks = s.seatPicks
            series = s.series; notes = s.notes; noteTags = Array(s.noteTags)
            incomplete = s.incomplete
            history = s.history
            banSuggestionSnapshot = s.banSuggestionSnapshot
            pickSuggestionSnapshot = s.pickSuggestionSnapshot
            myPickWasSuggested = s.myPickWasSuggested
        }

        func restored() -> DraftSession {
            let s = DraftSession()
            s.phase = phase; s.mode = mode; s.map = map; s.wonToss = wonToss
            s.mySeat = mySeat; s.activeBanSeat = activeBanSeat
            s.seatBans = seatBans; s.seatPicks = seatPicks
            s.series = series; s.notes = notes; s.noteTags = Set(noteTags)
            s.incomplete = incomplete ?? false
            s.history = history
            s.banSuggestionSnapshot = banSuggestionSnapshot
            s.pickSuggestionSnapshot = pickSuggestionSnapshot
            s.myPickWasSuggested = myPickWasSuggested
            return s
        }
    }

    @MainActor
    private static func load() -> DraftSession? {
        guard let snap = JSONStore.load(Snapshot.self, from: file) else { return nil }
        // A draft that never got past mode selection isn't worth resuming.
        guard snap.phase != .setup else { return nil }
        return snap.restored()
    }
}
