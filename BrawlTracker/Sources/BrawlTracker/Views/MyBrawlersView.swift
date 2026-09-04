import SwiftUI

enum BrawlerSort: String, CaseIterable, Identifiable {
    case trophies = "Trophies"
    case highestTrophies = "Highest Trophies"
    case power = "Power"
    case rank = "Rank"
    case name = "Name"
    case currentWinStreak = "Win Streak"
    case prestige = "Prestige"
    case eligibleFirst = "Ranked-Eligible first"
    case closestToEligible = "Closest to eligible"
    case invested = "Coins invested"
    var id: String { rawValue }
}

struct MyBrawlersView: View {
    let brawlers: [Brawler]
    @Environment(PlayerStore.self) private var store
    @Environment(RankedSettings.self) private var rankedSettings
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(MatchLogStore.self) private var matchLog

    @State private var search = ""
    @State private var sort: BrawlerSort = .trophies
    @State private var descending = true
    @State private var onlyMaxPower = false
    @State private var onlyHypercharge = false
    @State private var onlyRankedEligible = false
    @State private var selected: Brawler?

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                collectionHeader
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredSorted) { brawler in
                        BrawlerCard(brawler: brawler)
                            .onTapGesture { selected = brawler }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("My Brawlers")
        .searchable(text: $search, prompt: "Search brawlers")
        .toolbar {
            ToolbarItemGroup {
                Text("\(filteredSorted.count) of \(brawlers.count)").font(.callout).foregroundStyle(.secondary)
                Menu {
                    Picker("Sort by", selection: $sort) { ForEach(BrawlerSort.allCases) { Text($0.rawValue).tag($0) } }
                    Divider()
                    Toggle("Descending", isOn: $descending)
                } label: { Label("Sort: \(sort.rawValue)", systemImage: "arrow.up.arrow.down") }
                Menu {
                    Toggle("Ranked Eligible only", isOn: $onlyRankedEligible)
                    Toggle("Power 11 only", isOn: $onlyMaxPower)
                    Toggle("Has Hypercharge", isOn: $onlyHypercharge)
                    Divider()
                    Button("Clear filters") { onlyMaxPower = false; onlyHypercharge = false; onlyRankedEligible = false }
                        .disabled(!filtersActive)
                } label: {
                    Label("Filter", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $selected) {
            BrawlerDetailView(brawler: $0)
                .environment(store).environment(rankedSettings).environment(archive).environment(matchLog)
        }
    }

    // MARK: Collection header

    private var collectionHeader: some View {
        let eligible = brawlers.filter(\.isRankedEligible).count
        let maxed = brawlers.filter { $0.power >= 11 }.count
        let invested = brawlers.reduce(ResourceCost()) { $0 + UpgradeCosts.spent(on: $1) }
        let toEligibleAll = brawlers.reduce(ResourceCost()) { $0 + UpgradeCosts.toRankedEligible($1) }
        return HStack(spacing: 12) {
            HeaderStat(value: "\(brawlers.count)", label: "Brawlers", symbol: "person.3.fill", tint: .blue)
            HeaderStat(value: "\(eligible)", label: "Ranked-Eligible", symbol: "checkmark.seal.fill", tint: .green)
            HeaderStat(value: "\(maxed)", label: "Power 11", symbol: "bolt.fill", tint: .purple)
            HeaderStat(value: invested.coins.formatted(), label: "Coins invested", symbol: "dollarsign.circle.fill", tint: .yellow)
            HeaderStat(value: invested.powerPoints.formatted(), label: "PP invested", symbol: "bolt.circle.fill", tint: .pink)
            HeaderStat(value: toEligibleAll.coins.formatted(), label: "Coins to all-eligible", symbol: "target", tint: .orange)
        }
    }

    private var filtersActive: Bool { onlyMaxPower || onlyHypercharge || onlyRankedEligible }

    private var filteredSorted: [Brawler] {
        var result = brawlers
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { result = result.filter { $0.name.lowercased().contains(q) } }
        if onlyRankedEligible { result = result.filter(\.isRankedEligible) }
        if onlyMaxPower { result = result.filter(\.isMaxPower) }
        if onlyHypercharge { result = result.filter(\.hasHypercharge) }

        result.sort { a, b in
            let ordered: Bool
            switch sort {
            case .trophies: ordered = a.trophies < b.trophies
            case .highestTrophies: ordered = a.highestTrophies < b.highestTrophies
            case .power: ordered = a.power < b.power
            case .rank: ordered = a.rank < b.rank
            case .name: ordered = a.name < b.name
            case .currentWinStreak: ordered = (a.currentWinStreak ?? 0) < (b.currentWinStreak ?? 0)
            case .prestige: ordered = (a.prestigeLevel ?? 0) < (b.prestigeLevel ?? 0)
            case .eligibleFirst:
                if a.isRankedEligible != b.isRankedEligible { ordered = !a.isRankedEligible }
                else { ordered = a.trophies < b.trophies }
            case .closestToEligible:
                // "descending" here means cheapest first, which is what you want.
                let ca = UpgradeCosts.toRankedEligible(a).coins, cb = UpgradeCosts.toRankedEligible(b).coins
                let ea = ca == 0 ? Int.max : ca, eb = cb == 0 ? Int.max : cb
                ordered = ea > eb
            case .invested: ordered = UpgradeCosts.spent(on: a).coins < UpgradeCosts.spent(on: b).coins
            }
            return descending ? !ordered : ordered
        }
        return result
    }
}

struct HeaderStat: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: symbol).foregroundStyle(tint).font(.caption)
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(value).font(.title3.weight(.bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
