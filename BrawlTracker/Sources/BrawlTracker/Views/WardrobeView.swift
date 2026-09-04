import SwiftUI

struct WardrobeView: View {
    @Environment(SkinStore.self) private var skins
    @Environment(PlayerStore.self) private var store

    @State private var search = ""
    @State private var showAdd = false
    @State private var addBrawler = ""
    @State private var addName = ""
    @State private var addType: SkinEntry.CostType = .bling
    @State private var addAmount = ""
    @State private var addOwned = true

    private var brawlerNames: [String] {
        let fromRef = store.reference.values.map(\.name)
        let fromPlayer = store.player?.brawlers.map(\.name) ?? []
        return Array(Set(fromRef + fromPlayer)).sorted()
    }

    private var grouped: [(brawler: String, skins: [SkinEntry])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = skins.skins.filter {
            q.isEmpty || $0.name.lowercased().contains(q) || $0.brawler.lowercased().contains(q)
        }
        let dict = Dictionary(grouping: filtered, by: { $0.brawler.capitalized })
        return dict.keys.sorted().map { ($0, dict[$0]!.sorted { $0.name < $1.name }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary
                Text("The official API only reveals each brawler's currently-equipped skin, so owned skins are collected as they're seen. Add others by hand with their cost.")
                    .font(.caption).foregroundStyle(.secondary)
                if grouped.isEmpty {
                    ContentUnavailableView {
                        Label("No skins tracked yet", systemImage: "tshirt")
                    } description: {
                        Text("Equip skins in-game and refresh, or add them manually.")
                    }
                    .frame(minHeight: 220)
                } else {
                    ForEach(grouped, id: \.brawler) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                MiniBrawler(name: group.brawler, size: 30)
                                Text(group.brawler).font(.headline)
                                Text("\(group.skins.filter(\.owned).count)/\(group.skins.count) owned")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(group.skins) { skin in skinRow(skin) }
                        }
                        .padding(12)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Wardrobe")
        .searchable(text: $search, prompt: "Search skins")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { resetAdd(); showAdd = true } label: { Label("Add Skin", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { addSheet }
        .onAppear { skins.observe(store.player) }
    }

    private var summary: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            DetailStat(title: "Skins owned", value: "\(skins.ownedCount)", symbol: "tshirt.fill", tint: .indigo)
            DetailStat(title: "Bling spent", value: "\(skins.spent(.bling))", symbol: "sparkles", tint: .cyan)
            DetailStat(title: "Gems spent", value: "\(skins.spent(.gems))", symbol: "diamond.fill", tint: .green)
            DetailStat(title: "Coins spent", value: "\(skins.spent(.coins))", symbol: "dollarsign.circle.fill", tint: .yellow)
        }
    }

    private func skinRow(_ skin: SkinEntry) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { skin.owned }, set: { _ in skins.toggleOwned(skin.id) }))
                .toggleStyle(.checkbox).labelsHidden()
            Text(skin.name.capitalized).font(.callout).foregroundStyle(skin.owned ? .primary : .secondary)
            if skin.fromAPI { Tag(text: "Seen in-game", color: .blue) }
            Spacer()
            Text(skin.costType == .free ? "Free" : "\(skin.costAmount) \(skin.costType.rawValue)")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
            Button {
                addBrawler = skin.brawler; addName = skin.name; addType = skin.costType
                addAmount = skin.costAmount == 0 ? "" : "\(skin.costAmount)"; addOwned = skin.owned
                showAdd = true
            } label: { Image(systemName: "pencil") }.buttonStyle(.plain).foregroundStyle(.secondary)
            Button { skins.delete(skin.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Skin").font(.title3.weight(.bold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Brawler")
                    Picker("", selection: $addBrawler) {
                        Text("Choose…").tag("")
                        ForEach(brawlerNames, id: \.self) { Text($0.capitalized).tag($0) }
                    }.labelsHidden()
                }
                GridRow { Text("Skin name"); TextField("e.g. Bunny Penny", text: $addName).textFieldStyle(.roundedBorder) }
                GridRow {
                    Text("Cost")
                    HStack {
                        Picker("", selection: $addType) {
                            ForEach(SkinEntry.CostType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 100)
                        TextField("Amount", text: $addAmount).textFieldStyle(.roundedBorder).disabled(addType == .free)
                    }
                }
                GridRow { Text("Owned"); Toggle("", isOn: $addOwned).labelsHidden() }
            }
            HStack {
                Spacer()
                Button("Cancel") { showAdd = false }
                Button("Save") {
                    skins.add(brawler: addBrawler, name: addName.trimmingCharacters(in: .whitespaces),
                              owned: addOwned, costType: addType, amount: Int(addAmount) ?? 0)
                    showAdd = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(addBrawler.isEmpty || addName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22).frame(width: 420)
    }

    private func resetAdd() { addBrawler = ""; addName = ""; addType = .bling; addAmount = ""; addOwned = true }
}
