import Foundation
import Observation

/// Persisted log of completed ranked matches (newest first).
@MainActor
@Observable
final class MatchLogStore {
    private(set) var matches: [MatchRecord] = []

    init() { load() }

    func add(_ record: MatchRecord) {
        matches.insert(record, at: 0)
        save()
    }

    /// Notes can be edited any time after the match is saved.
    func updateNotes(_ id: UUID, notes: String, tags: [MatchNoteTag]) {
        guard let i = matches.firstIndex(where: { $0.id == id }) else { return }
        matches[i].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        matches[i].noteTags = tags.map(\.rawValue)
        save()
    }

    /// Matches you annotated, newest first — the review set.
    var annotated: [MatchRecord] { matches.filter(\.hasNotes) }

    func delete(_ id: UUID) {
        matches.removeAll { $0.id == id }
        save()
    }

    /// Mark a series as cut short (crash/disconnect). The games played stay in
    /// the learning data; only the series verdict and calibration drop it.
    func setIncomplete(_ id: UUID, _ value: Bool) {
        guard let i = matches.firstIndex(where: { $0.id == id }) else { return }
        matches[i].incomplete = value
        save()
    }

    var completed: [MatchRecord] { matches.filter(\.countsForRecord) }
    var seriesWon: Int { completed.filter(\.seriesWon).count }
    var seriesLost: Int { completed.filter { !$0.seriesWon }.count }
    var incompleteCount: Int { matches.filter(\.isIncomplete).count }

    // MARK: - Win-chance calibration

    /// How far the win-chance model has run over (positive) or under (negative)
    /// the truth, measured on your own completed matches. Fed back into the
    /// estimator so it corrects itself as more matches land.
    var calibration: (bias: Double, samples: Int, brier: Double)? {
        let scored = completed.compactMap { m -> (Double, Double)? in
            guard let p = m.winChance, m.gamesPlayed > 0 else { return nil }
            return (p, m.seriesWon ? 1 : 0)
        }
        guard scored.count >= 5 else { return nil }
        let n = Double(scored.count)
        let bias = scored.reduce(0) { $0 + $1.0 - $1.1 } / n
        let brier = scored.reduce(0) { $0 + pow($1.0 - $1.1, 2) } / n
        return (bias, scored.count, brier)
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("matches.json")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(matches) {
            try? data.write(to: fileURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MatchRecord].self, from: data) else { return }
        matches = decoded
    }
}
