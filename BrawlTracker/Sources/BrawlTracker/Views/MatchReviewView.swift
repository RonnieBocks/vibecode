import SwiftUI

/// Post-match review: bans, draft, result, lessons, and the plan you had.
struct MatchReviewView: View {
    let match: MatchRecord
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(MatchLogStore.self) private var matchLog
    @Environment(\.dismiss) private var dismiss

    @State private var notes = ""
    @State private var tags: Set<MatchNoteTag> = []
    @State private var savedNotes = false

    private var learning: DraftLearning { DraftLearning(archive: archive.records, matches: matchLog.matches) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: match.seriesWon ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(match.seriesWon ? .green : .red).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(match.mode) · \(match.mapName)").font(.title3.weight(.bold))
                    Text("\(match.date.formatted(date: .abbreviated, time: .shortened)) · \(match.wonToss ? "first pick" : "second pick") · you were pick \(match.mySlot)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                SeriesPills(series: match.series)
                if let wc = match.winChance { Tag(text: "Predicted \(Int((wc * 100).rounded()))%", color: .yellow) }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                Button("") { dismiss() }.keyboardShortcut(.cancelAction).hidden().frame(width: 0, height: 0)
            }
            .padding(14).background(.background.secondary)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    compsAndBans
                    ForEach(MatchAnalyzer.analyze(match, learning: learning)) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            ForEach(section.bullets) { b in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: b.kind == .good ? "checkmark.circle.fill" : b.kind == .warn ? "exclamationmark.triangle.fill" : "info.circle")
                                        .foregroundStyle(b.kind == .good ? .green : b.kind == .warn ? .orange : .secondary)
                                        .frame(width: 18)
                                    Text(b.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { matchLog.matches.first { $0.id == match.id }?.isIncomplete ?? false },
                            set: { matchLog.setIncomplete(match.id, $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Series cut short (crash or disconnect)")
                                Text("Keeps the games you played in every brawler's record, but drops the series result from your W–L and from the win-chance accuracy check.")
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .toggleStyle(.checkbox)
                        Divider()
                        MatchNotesEditor(notes: $notes, tags: $tags, compact: true)
                        HStack {
                            if savedNotes {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(.caption).foregroundStyle(.green)
                            }
                            Spacer()
                            Button("Save notes") {
                                matchLog.updateNotes(match.id, notes: notes, tags: Array(tags))
                                savedNotes = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

                    GamePlanView(plan: MatchTips.plan(mode: match.mode, map: match.mapName, myBrawler: match.myBrawler,
                                                      myTeam: match.myTeam, enemy: match.enemyTeam, learning: learning),
                                 title: "THE PLAN YOU HAD")
                }
                .padding(18)
            }
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 640)
        .onAppear {
            notes = match.notes ?? ""
            tags = Set(match.tags)
        }
        .onChange(of: notes) { _, _ in savedNotes = false }
        .onChange(of: tags) { _, _ in savedNotes = false }
    }

    private var compsAndBans: some View {
        HStack(alignment: .top, spacing: 16) {
            teamBox("YOUR TEAM", names: match.myTeam, tint: .blue, highlight: match.myBrawler)
            teamBox("ENEMY", names: match.enemyTeam, tint: .red, highlight: nil)
            VStack(alignment: .leading, spacing: 6) {
                Text("BANS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(match.bans, id: \.self) { name in
                        VStack(spacing: 2) {
                            ZStack {
                                MiniBrawler(name: name, size: 34)
                                Image(systemName: "nosign").foregroundStyle(.red).font(.caption)
                            }
                            if let mine = match.myBan, BrawlerArt.normalize(mine) == BrawlerArt.normalize(name) {
                                Text("you").font(.system(size: 8)).foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func teamBox(_ title: String, names: [String], tint: Color, highlight: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(tint)
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                HStack(spacing: 8) {
                    MiniBrawler(name: name, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name.capitalized).font(.callout.weight(.semibold))
                        Text(DraftPlaybook.draftClass(for: name).rawValue).font(.caption2).foregroundStyle(.secondary)
                    }
                    if let h = highlight, BrawlerArt.normalize(h) == BrawlerArt.normalize(name) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct SeriesPills: View {
    let series: [GameResult]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(series.enumerated()), id: \.offset) { _, g in
                Text(g.rawValue).font(.caption.weight(.black)).foregroundStyle(.white).frame(width: 18, height: 18)
                    .background(g == .win ? Color.green : g == .loss ? Color.red : Color.secondary.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

/// Tips grouped by category.
struct MatchTipsView: View {
    let tips: [MatchTip]
    var title: String = "GAME PLAN"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(.yellow)
            ForEach(MatchTip.Category.allCases, id: \.self) { cat in
                let items = tips.filter { $0.category == cat }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cat.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(items) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: icon(cat)).foregroundStyle(color(cat)).frame(width: 16)
                                Text(tip.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.yellow.opacity(0.35), lineWidth: 1))
    }

    private func icon(_ c: MatchTip.Category) -> String {
        switch c { case .role: return "person.fill"; case .threats: return "exclamationmark.triangle.fill"
        case .plan: return "map.fill"; case .history: return "clock.arrow.circlepath"; case .mode: return "flag.fill" }
    }
    private func color(_ c: MatchTip.Category) -> Color {
        switch c { case .role: return .blue; case .threats: return .orange; case .plan: return .green
        case .history: return .purple; case .mode: return .secondary }
    }
}
