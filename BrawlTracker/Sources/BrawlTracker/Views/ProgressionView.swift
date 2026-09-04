import SwiftUI

struct ProgressionView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(SeasonStore.self) private var seasons
    @Environment(SnapshotStore.self) private var snapshots

    @State private var showingStart = false
    @State private var seasonName = ""
    @State private var showingResources = false
    @State private var gold = ""
    @State private var pp = ""
    @State private var gems = ""
    @State private var bling = ""

    private var current: ProgressSnapshot? { store.player.map { .capture($0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let season = seasons.active {
                    activeSeasonView(season)
                } else {
                    ContentUnavailableView {
                        Label("No active season", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("Start a season to snapshot your account now and keep a running tally of everything you gain.")
                    } actions: {
                        Button("Start New Season") { seasonName = ""; showingStart = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 260)
                }
                pastSeasons
            }
            .padding(20)
            .frame(maxWidth: 1000, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Progression")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { seasonName = ""; showingStart = true } label: { Label("New Season", systemImage: "plus") }
                    .disabled(store.player == nil)
            }
        }
        .alert("Start New Season", isPresented: $showingStart) {
            TextField("Name (e.g. Season 48)", text: $seasonName)
            Button("Cancel", role: .cancel) {}
            Button("Start") { if let p = store.player { seasons.startSeason(named: seasonName, player: p) } }
        } message: {
            Text("Snapshots your account right now. Any open season is closed first.")
        }
        .sheet(isPresented: $showingResources) { resourceSheet }
    }

    // MARK: Active season

    private func activeSeasonView(_ season: Season) -> some View {
        let gains = season.gains(current: current)
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(season.name).font(.title2.weight(.bold))
                    Text("Started \(season.start.formatted(date: .abbreviated, time: .omitted)) · \(days(since: season.start)) days")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Log resources") { gold = ""; pp = ""; gems = ""; bling = ""; showingResources = true }
                Button("End season", role: .destructive) { if let p = store.player { seasons.endActive(player: p) } }
            }

            HStack(spacing: 6) {
                Text("GAINED THIS SEASON").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                if gains.rankedElo > 0 && gains.trophies == 0 {
                    Text("· ranked games move Elo, not trophies").font(.caption2).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                gainTile("Ranked Elo", gains.rankedElo, "rosette", .orange)
                gainTile("Trophies", gains.trophies, "trophy.fill", .yellow)
                gainTile("Brawlers", gains.brawlers, "person.3.fill", .blue)
                gainTile("Power 11s", gains.power11, "bolt.fill", .purple)
                gainTile("Exp levels", gains.expLevel, "arrow.up.circle.fill", .cyan)
                gainTile("Gadgets", gains.gadgets, "bolt.circle.fill", .green)
                gainTile("Star powers", gains.starPowers, "star.circle.fill", .yellow)
                gainTile("Gears", gains.gears, "gearshape.circle.fill", .cyan)
                gainTile("Hypercharges", gains.hypercharges, "flame.circle.fill", .pink)
                gainTile("Buffies", gains.buffies, "arrow.up.circle.fill", .mint)
                gainTile("Skins", gains.skins, "tshirt.fill", .indigo)
                gainTile("3v3 wins", gains.wins3v3, "person.2.fill", .green)
                gainTile("Solo wins", gains.soloWins, "person.fill", .green)
                gainTile("Duo wins", gains.duoWins, "person.2", .green)
            }

            valueSection(season, gains: gains)
            resourcesSection(season)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Value of gains — what the season's unlocks are worth in coins / PP

    private func valueOfGains(_ season: Season, gains: ProgressSnapshot) -> (total: ResourceCost, lines: [CostLine]) {
        var lines: [CostLine] = []
        func add(_ label: String, _ n: Int, coins: Int, pp: Int = 0) {
            guard n > 0 else { return }
            lines.append(CostLine(label: "\(label) ×\(n)", cost: ResourceCost(coins: n * coins, powerPoints: n * pp)))
        }
        add("Gadgets", gains.gadgets, coins: UpgradeCosts.gadgetCoins)
        add("Star powers", gains.starPowers, coins: UpgradeCosts.starPowerCoins)
        add("Gears", gains.gears, coins: UpgradeCosts.gearCoins)
        add("Hypercharges", gains.hypercharges, coins: UpgradeCosts.hyperchargeCoins)
        add("Buffies", gains.buffies, coins: UpgradeCosts.buffyCoins, pp: UpgradeCosts.buffyPowerPoints)
        // Level-ups from per-brawler snapshots (season start → now / season end).
        if let startSnap = snapshots.snapshot(onOrAfter: season.start) {
            let endBrawlers: [BrawlerSnap]
            if season.isActive, let p = store.player {
                endBrawlers = p.brawlers.map { BrawlerSnap(id: $0.id, name: $0.name, power: $0.power, trophies: $0.trophies,
                    gadgets: 0, starPowers: 0, gears: 0, hypercharges: 0, buffies: 0) }
            } else if let end = season.end, let endSnap = snapshots.snapshots.last(where: { $0.date <= end }) {
                endBrawlers = endSnap.brawlers
            } else { endBrawlers = [] }
            let startPower = Dictionary(startSnap.brawlers.map { ($0.id, $0.power) }, uniquingKeysWith: { a, _ in a })
            var levels = ResourceCost(); var ups = 0
            for b in endBrawlers {
                let from = startPower[b.id] ?? 1
                if b.power > from { levels = levels + UpgradeCosts.levelCost(from: from, to: b.power); ups += b.power - from }
            }
            if ups > 0 { lines.append(CostLine(label: "Power levels ×\(ups)", cost: levels)) }
        }
        let total = lines.reduce(ResourceCost()) { $0 + $1.cost }
        return (total, lines)
    }

    private func valueSection(_ season: Season, gains: ProgressSnapshot) -> some View {
        let v = valueOfGains(season, gains: gains)
        return VStack(alignment: .leading, spacing: 8) {
            Text("VALUE OF THIS SEASON'S PROGRESS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                resTile("Coins-equivalent", v.total.coins, .yellow)
                resTile("PP-equivalent", v.total.powerPoints, .pink)
            }
            if v.lines.isEmpty {
                Text("Nothing unlocked yet this season.").font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
                    ForEach(v.lines) { line in
                        HStack {
                            Text(line.label).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(line.cost.coins.formatted() + "c" + (line.cost.powerPoints > 0 ? " · \(line.cost.powerPoints.formatted())pp" : ""))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
            if snapshots.snapshot(onOrAfter: season.start) == nil {
                Text("Power-level value will count once a launch snapshot exists after the season start (it's recorded on each live fetch).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func resourcesSection(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RESOURCES (manual — not in the API)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(season.resources.count) entries").font(.caption).foregroundStyle(.secondary)
            }
            if let d = season.resourceDelta {
                HStack(spacing: 12) {
                    resTile("Gold", d.gold, .yellow)
                    resTile("Power Pts", d.powerPoints, .pink)
                    resTile("Gems", d.gems, .green)
                    resTile("Bling", d.bling, .cyan)
                }
            } else if let last = season.resources.last {
                Text("Latest: \(last.gold) gold · \(last.powerPoints) PP · \(last.gems) gems · \(last.bling) bling. Log again later to see the change.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Log your balances at season start and again as you go to track earned/spent currency.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Past seasons

    private var pastSeasons: some View {
        let past = seasons.seasons.filter { !$0.isActive }
        return Group {
            if !past.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAST SEASONS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        GridRow {
                            Text("Season").font(.caption.weight(.bold))
                            Text("Days").font(.caption.weight(.bold))
                            Text("Trophies").font(.caption.weight(.bold))
                            Text("Elo").font(.caption.weight(.bold))
                            Text("Gadg").font(.caption.weight(.bold))
                            Text("SP").font(.caption.weight(.bold))
                            Text("Gears").font(.caption.weight(.bold))
                            Text("Hyper").font(.caption.weight(.bold))
                            Text("Buffy").font(.caption.weight(.bold))
                            Text("Skins").font(.caption.weight(.bold))
                            Text("")
                        }
                        .foregroundStyle(.secondary)
                        ForEach(past) { s in
                            let g = s.gains(current: nil)
                            GridRow {
                                Text(s.name).font(.callout.weight(.semibold))
                                Text("\(days(since: s.start, until: s.end ?? Date()))")
                                signed(g.trophies); signed(g.rankedElo); signed(g.gadgets); signed(g.starPowers)
                                signed(g.gears); signed(g.hypercharges); signed(g.buffies); signed(g.skins)
                                Button { seasons.delete(s.id) } label: { Image(systemName: "trash").foregroundStyle(.secondary) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: Resource sheet

    private var resourceSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log current balances").font(.title3.weight(.bold))
            Text("Enter what you have right now. Differences between entries become your seasonal tally.")
                .font(.callout).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow { Text("Gold"); TextField("0", text: $gold).textFieldStyle(.roundedBorder) }
                GridRow { Text("Power Points"); TextField("0", text: $pp).textFieldStyle(.roundedBorder) }
                GridRow { Text("Gems"); TextField("0", text: $gems).textFieldStyle(.roundedBorder) }
                GridRow { Text("Bling"); TextField("0", text: $bling).textFieldStyle(.roundedBorder) }
            }
            HStack {
                Spacer()
                Button("Cancel") { showingResources = false }
                Button("Save") {
                    seasons.logResources(gold: Int(gold) ?? 0, powerPoints: Int(pp) ?? 0,
                                         gems: Int(gems) ?? 0, bling: Int(bling) ?? 0)
                    showingResources = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(22).frame(width: 380)
    }

    // MARK: helpers

    private func gainTile(_ title: String, _ value: Int, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text((value > 0 ? "+" : "") + "\(value)").font(.title3.weight(.bold))
                .foregroundStyle(value > 0 ? Color.primary : value < 0 ? Color.red : Color.secondary)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func resTile(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text((value > 0 ? "+" : "") + "\(value)").font(.headline).foregroundStyle(value >= 0 ? tint : .red)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func signed(_ v: Int) -> some View {
        Text((v > 0 ? "+" : "") + "\(v)").font(.callout.monospaced())
            .foregroundStyle(v > 0 ? .green : v < 0 ? .red : .secondary)
    }

    private func days(since: Date, until: Date = Date()) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: since, to: until).day ?? 0)
    }
}
