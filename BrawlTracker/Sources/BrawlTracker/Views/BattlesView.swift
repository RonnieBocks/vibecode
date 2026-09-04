import SwiftUI

struct BattlesView: View {
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(SeasonStore.self) private var seasons
    @State private var scope: Scope = .all
    @State private var seasonOnly = true

    enum Scope: String, CaseIterable, Identifiable {
        case all = "All", ranked = "Ranked", regular = "Regular"
        var id: String { rawValue }
    }

    /// Battles since the active season started (season = app-wide reset point).
    private var seasonStart: Date? { seasons.active?.start }

    private var records: [BattleRecord] {
        var base = archive.records
        if seasonOnly, let start = seasonStart { base = base.filter { $0.time >= start } }
        switch scope {
        case .all: return base
        case .ranked: return base.filter(\.isRanked)
        case .regular: return base.filter { !$0.isRanked }
        }
    }

    var body: some View {
        Group {
            if archive.records.isEmpty {
                ContentUnavailableView {
                    Label("No battles archived yet", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Battles are pulled from the API on every launch (last ~25 each time) and archived permanently. Play, relaunch, and trends will build up here.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryTiles
                        Text("Per-game results for every battle the API returned, including games you didn't run through the draft assistant. The Ranked tab's record counts logged series only, so the two differ.")
                            .font(.caption).foregroundStyle(.secondary)
                        recentForm
                        HStack(alignment: .top, spacing: 16) {
                            statTable("By Brawler", lines: BattleStats.group(records) { $0.myBrawler }, portrait: true)
                            statTable("By Mode", lines: BattleStats.group(records) { BattleStats.prettyMode($0.mode) }, portrait: false)
                        }
                        statTable("By Map", lines: BattleStats.group(records) { $0.map }, portrait: false)
                        recentList
                    }
                    .padding(20)
                    .frame(maxWidth: 1100, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Battles")
        .toolbar {
            ToolbarItemGroup {
                if let start = seasonStart {
                    Toggle(isOn: $seasonOnly) {
                        Label("This season", systemImage: "calendar")
                    }
                    .toggleStyle(.button)
                    .help("Only battles since \(start.formatted(date: .abbreviated, time: .omitted)) — resets when you start a new season")
                }
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("\(records.count) battles").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var summaryTiles: some View {
        let wr = BattleStats.winRate(records)
        let ranked = records.filter(\.isRanked)
        let net = records.filter { !$0.isRanked }.map(\.trophyChange).reduce(0, +)
        let stars = records.filter(\.starPlayer).count
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            DetailStat(title: "Battles", value: "\(records.count)", symbol: "list.bullet", tint: .blue)
            DetailStat(title: "Game win rate", value: pct(wr), symbol: "percent", tint: wr >= 0.5 ? .green : .orange)
            DetailStat(title: "Ranked WR", value: ranked.isEmpty ? "—" : pct(BattleStats.winRate(ranked)),
                       symbol: "trophy.fill", tint: .yellow)
            DetailStat(title: "Star player", value: "\(stars)", symbol: "star.fill", tint: .yellow)
            DetailStat(title: "Net trophies", value: (net >= 0 ? "+" : "") + "\(net)", symbol: "chart.line.uptrend.xyaxis",
                       tint: net >= 0 ? .green : .red)
        }
    }

    private var recentForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent form").font(.headline)
            HStack(spacing: 4) {
                ForEach(records.prefix(25)) { r in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(r.outcome == .win ? Color.green : r.outcome == .loss ? Color.red : Color.gray)
                        .frame(width: 14, height: 22)
                        .help("\(BattleStats.prettyMode(r.mode)) · \(r.map) · \(r.myBrawler ?? "?") · \(r.outcome.rawValue)")
                }
            }
        }
    }

    private func statTable(_ title: String, lines: [StatLine], portrait: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(lines.prefix(12)) { line in
                HStack(spacing: 10) {
                    if portrait { MiniBrawler(name: line.name, size: 28) }
                    Text(line.name.capitalized).font(.callout).lineLimit(1).frame(width: 110, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule().fill(line.winRate >= 0.5 ? Color.green : Color.orange)
                                .frame(width: max(4, geo.size.width * line.winRate))
                        }
                    }
                    .frame(height: 8)
                    Text(pct(line.winRate)).font(.caption.monospaced()).frame(width: 44, alignment: .trailing)
                    Text("\(line.games)g").font(.caption).foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent battles").font(.headline)
            ForEach(records.prefix(30)) { r in
                HStack(spacing: 10) {
                    Circle().fill(r.outcome == .win ? Color.green : r.outcome == .loss ? Color.red : Color.gray)
                        .frame(width: 8, height: 8)
                    if let b = r.myBrawler { MiniBrawler(name: b, size: 26) }
                    Text(r.myBrawler?.capitalized ?? "—").font(.callout).frame(width: 100, alignment: .leading)
                    Text(BattleStats.prettyMode(r.mode)).font(.callout).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                    Text(r.map).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if r.isRanked { Tag(text: "Ranked", color: .purple) }
                    if r.starPlayer { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                    Text(r.trophyChange == 0 ? "" : (r.trophyChange > 0 ? "+\(r.trophyChange)" : "\(r.trophyChange)"))
                        .font(.caption.monospaced()).foregroundStyle(r.trophyChange >= 0 ? .green : .red).frame(width: 36)
                    Text(r.time.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func pct(_ v: Double) -> String { String(format: "%.0f%%", v * 100) }
}
