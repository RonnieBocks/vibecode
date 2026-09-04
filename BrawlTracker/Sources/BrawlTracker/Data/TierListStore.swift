import Foundation
import Observation
import SwiftUI

/// A brawler on the tier list (id + display name), enough to render a chip.
struct TierBrawler: Identifiable, Hashable {
    let id: Int
    let name: String
}

/// One saved, named tier list.
struct SavedTierList: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var assignments: [String: [Int]]   // tier label -> ordered brawler ids
}

/// Persisted collection of named drag-and-drop tier lists, with a selected
/// active one. Saved to Application Support. Migrates the old single-list
/// file so an existing tier list is never lost.
@MainActor
@Observable
final class TierListStore {
    struct Tier: Identifiable, Hashable {
        let label: String
        let color: Color
        var id: String { label }
    }

    static let tiers: [Tier] = [
        Tier(label: "S", color: Color(red: 0.95, green: 0.30, blue: 0.35)),
        Tier(label: "A", color: Color(red: 0.98, green: 0.55, blue: 0.25)),
        Tier(label: "B", color: Color(red: 0.98, green: 0.80, blue: 0.25)),
        Tier(label: "C", color: Color(red: 0.45, green: 0.80, blue: 0.35)),
        Tier(label: "D", color: Color(red: 0.40, green: 0.60, blue: 0.90)),
    ]

    private(set) var lists: [SavedTierList] = []
    private(set) var activeID: UUID = UUID()

    /// Snapshot of the last list that was reset, so a mis-click is recoverable.
    struct ClearBackup: Codable {
        var listID: UUID
        var name: String
        var assignments: [String: [Int]]
        var date: Date
    }
    private(set) var lastCleared: ClearBackup?

    init() {
        load()
        lastCleared = JSONStore.load(ClearBackup.self, from: "tierlists.backup.json")
    }

    // MARK: - Active list

    var active: SavedTierList? { lists.first { $0.id == activeID } }
    private var activeIndex: Int? { lists.firstIndex { $0.id == activeID } }
    private var assignments: [String: [Int]] { active?.assignments ?? [:] }

    // MARK: - Queries

    func ids(in label: String) -> [Int] { assignments[label] ?? [] }

    func unranked(from roster: [TierBrawler]) -> [Int] {
        let placed = Set(assignments.values.flatMap { $0 })
        return roster.map(\.id).filter { !placed.contains($0) }
    }

    func tierLabel(of id: Int) -> String? {
        assignments.first(where: { $0.value.contains(id) })?.key
    }

    // MARK: - Assignment mutations (operate on the active list)

    private func mutate(_ block: (inout [String: [Int]]) -> Void) {
        guard let i = activeIndex else { return }
        block(&lists[i].assignments)
        save()
    }

    func move(_ id: Int, to label: String?) {
        mutate { a in
            for key in a.keys { a[key]?.removeAll { $0 == id } }
            if let label { a[label, default: []].append(id) }
        }
    }

    func move(_ id: Int, to label: String, before targetID: Int) {
        guard id != targetID else { return }
        mutate { a in
            for key in a.keys { a[key]?.removeAll { $0 == id } }
            var arr = a[label] ?? []
            if let idx = arr.firstIndex(of: targetID) { arr.insert(id, at: idx) }
            else { arr.append(id) }
            a[label] = arr
        }
    }

    func clearActive() {
        // Keep a backup first — never let one click destroy a season of sorting.
        if let a = active, !a.assignments.isEmpty {
            lastCleared = ClearBackup(listID: a.id, name: a.name, assignments: a.assignments, date: Date())
            JSONStore.save(lastCleared, to: "tierlists.backup.json")
        }
        mutate { $0 = [:] }
    }

    /// Put the last reset list's placements back (recreating the list if it was deleted).
    func restoreLastCleared() {
        guard let b = lastCleared else { return }
        if let i = lists.firstIndex(where: { $0.id == b.listID }) {
            lists[i].assignments = b.assignments
        } else {
            lists.append(SavedTierList(id: b.listID, name: b.name, assignments: b.assignments))
        }
        activeID = b.listID
        save()
    }

    // MARK: - List management

    func select(_ id: UUID) {
        activeID = id
        save()
    }

    func newList(named name: String) {
        let list = SavedTierList(id: UUID(), name: cleanName(name, fallback: "New Tier List"),
                                 assignments: [:])
        lists.append(list)
        activeID = list.id
        save()
    }

    func duplicateActive(named name: String) {
        guard let active else { return }
        let list = SavedTierList(id: UUID(), name: cleanName(name, fallback: active.name + " copy"),
                                 assignments: active.assignments)
        lists.append(list)
        activeID = list.id
        save()
    }

    func renameActive(to name: String) {
        guard let i = activeIndex else { return }
        lists[i].name = cleanName(name, fallback: lists[i].name)
        save()
    }

    func deleteActive() {
        guard lists.count > 1, let i = activeIndex else { return }
        lists.remove(at: i)
        activeID = lists.first!.id
        save()
    }

    private func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var lists: [SavedTierList]
        var activeID: UUID
    }

    private var dir: URL {
        let d = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrawlTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private var fileURL: URL { dir.appendingPathComponent("tierlists.json") }
    private var legacyURL: URL { dir.appendingPathComponent("tierlist.json") }

    private func save() {
        let payload = Persisted(lists: lists, activeID: activeID)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL)
        }
    }

    private func load() {
        // New multi-list file.
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data),
           !decoded.lists.isEmpty {
            lists = decoded.lists
            activeID = decoded.lists.contains(where: { $0.id == decoded.activeID })
                ? decoded.activeID : decoded.lists[0].id
            return
        }
        // Migrate the old single-list file so existing work is preserved.
        if let data = try? Data(contentsOf: legacyURL),
           let old = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            let migrated = SavedTierList(id: UUID(), name: "My Tier List", assignments: old)
            lists = [migrated]
            activeID = migrated.id
            save()
            return
        }
        // Fresh start.
        let first = SavedTierList(id: UUID(), name: "My Tier List", assignments: [:])
        lists = [first]
        activeID = first.id
        save()
    }
}
