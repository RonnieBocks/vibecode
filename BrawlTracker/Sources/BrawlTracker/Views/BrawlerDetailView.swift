import SwiftUI

struct BrawlerDetailView: View {
    let brawler: Brawler
    @Environment(PlayerStore.self) private var store
    @Environment(RankedSettings.self) private var rankedSettings
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(MatchLogStore.self) private var matchLog
    @Environment(\.dismiss) private var dismiss

    private var personal: PersonalStat? {
        DraftLearning(archive: archive.records, matches: matchLog.matches)
            .stat(brawler: brawler.name, mode: "", map: nil, minGames: 1)
    }

    private var reference: ReferenceBrawler? { store.reference[brawler.id] }

    private var ownedStarPowerIDs: Set<Int> { Set(brawler.starPowers.map(\.id)) }
    private var ownedGadgetIDs: Set<Int> { Set(brawler.gadgets.map(\.id)) }

    private var starBuffy: Bool { brawler.buffies?.starPower ?? false }
    private var gadgetBuffy: Bool { brawler.buffies?.gadget ?? false }
    private var hyperBuffy: Bool { brawler.buffies?.hyperCharge ?? false }

    /// The six standard gears (id, title, bundled icon).
    static let standardGears: [(id: Int, title: String, icon: String)] = [
        (62000000, "Speed", "gear_speed"),
        (62000004, "Shield", "gear_shield"),
        (62000002, "Damage", "gear_damage"),
        (62000001, "Health", "gear_health"),
        (62000017, "Gadget Cooldown", "gear_gadget"),
        (62000003, "Vision", "gear_vision"),
    ]

    private var ownedGearByID: [Int: Gear] {
        Dictionary(brawler.gears.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
    /// Owned gears that aren't one of the six standard ones (mythic/hyper gears).
    private var extraGears: [Gear] {
        let standard = Set(Self.standardGears.map(\.id))
        return brawler.gears.filter { !standard.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Toggle(isOn: Binding(get: { rankedSettings.isHidden(brawler.name) },
                                     set: { _ in rankedSettings.toggleHidden(brawler.name) })) {
                    Label("Hide from Ranked assistant", systemImage: "eye.slash")
                }
                .toggleStyle(.switch)

                statsGrid
                costSection

                starPowerSection
                gadgetSection
                gearSection
                hyperSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 640)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                BrawlerPortraitView(brawler: brawler, height: 200, alignment: .center, fitWhole: true)
                PowerBadge(power: brawler.power)
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(brawler.name.capitalized)
                    .font(.largeTitle.weight(.bold))

                HStack(spacing: 8) {
                    if let rarity = reference?.rarity?.name {
                        Tag(text: rarity, color: Color(hex: reference?.rarity?.color) ?? .purple)
                    }
                    if let cls = reference?.brawlerClass?.name, cls.count < 24 {
                        Tag(text: cls, color: .secondary)
                    }
                    if let skin = brawler.skin {
                        Label(skin.name.capitalized, systemImage: "tshirt")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let desc = reference?.description, !desc.isEmpty {
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            DetailStat(title: personal.map { "Your WR (\(Int($0.games.rounded()))g)" } ?? "Your WR",
                       value: personal.map { "\(Int($0.rate * 100))%" } ?? "—",
                       symbol: "percent", tint: (personal?.rate ?? 0.5) >= 0.5 ? .green : .orange)
            DetailStat(title: "Trophies", value: "\(brawler.trophies)", symbol: "trophy.fill", tint: .yellow)
            DetailStat(title: "Highest", value: "\(brawler.highestTrophies)", symbol: "crown.fill", tint: .orange)
            DetailStat(title: "Rank", value: "\(brawler.rank)", symbol: "rosette", tint: .red)
            DetailStat(title: "Prestige", value: "\(brawler.prestigeLevel ?? 0)", symbol: "sparkles", tint: .purple)
            DetailStat(title: "Win Streak", value: "\(brawler.currentWinStreak ?? 0)", symbol: "flame", tint: .pink)
            DetailStat(title: "Max Streak", value: "\(brawler.maxWinStreak ?? 0)", symbol: "chart.line.uptrend.xyaxis", tint: .green)
        }
    }

    // MARK: - Resource cost breakdown

    private var costSection: some View {
        let spent = UpgradeCosts.spent(on: brawler)
        let eligible = UpgradeCosts.toRankedEligible(brawler)
        let maxed = UpgradeCosts.toMax(brawler, reference: reference)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                UIIcon(name: "trophy", size: 20, fallbackSymbol: "dollarsign.circle.fill", fallbackTint: .yellow)
                Text("Resources").font(.headline)
                Spacer()
                Text("Levels + gadget 1k · star power 2k · gear 1k · hyper 5k · buffy 1k + 2k PP")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            VStack(spacing: 10) {
                CostTile(title: "Spent so far", cost: spent, lines: UpgradeCosts.spentLines(on: brawler), tint: .green, doneText: nil)
                CostTile(title: "To Ranked-Eligible", cost: eligible, lines: UpgradeCosts.eligibleLines(brawler), tint: .yellow, doneText: "Ranked-Eligible ✓")
                CostTile(title: "To fully max", cost: maxed, lines: UpgradeCosts.maxLines(brawler, reference: reference), tint: .purple, doneText: "Maxed ✓")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Item sections (owned + not owned via reference)

    @ViewBuilder
    private var starPowerSection: some View {
        section("Star Powers", icon: starBuffy ? "starpower_buffy" : "starpower",
                fallback: "star.circle.fill", tint: .yellow, buffy: starBuffy) {
            if let ref = reference, !ref.starPowers.isEmpty {
                ForEach(ref.starPowers) { item in
                    ItemRow(name: item.name, description: item.description,
                            owned: ownedStarPowerIDs.contains(item.id), iconURL: item.imageUrl)
                }
            } else {
                fallbackList(brawler.starPowers.map(\.name))
            }
        }
    }

    @ViewBuilder
    private var gadgetSection: some View {
        section("Gadgets", icon: gadgetBuffy ? "gadget_buffy" : "gadget",
                fallback: "bolt.circle.fill", tint: .green, buffy: gadgetBuffy) {
            if let ref = reference, !ref.gadgets.isEmpty {
                ForEach(ref.gadgets) { item in
                    ItemRow(name: item.name, description: item.description,
                            owned: ownedGadgetIDs.contains(item.id), iconURL: item.imageUrl)
                }
            } else {
                fallbackList(brawler.gadgets.map(\.name))
            }
        }
    }

    private var gearSection: some View {
        section("Gears", icon: "gear", fallback: "gearshape.circle.fill", tint: .cyan) {
            ForEach(Self.standardGears, id: \.id) { g in
                GearRow(title: g.title, icon: g.icon,
                        level: ownedGearByID[g.id]?.level,
                        owned: ownedGearByID[g.id] != nil)
            }
            ForEach(extraGears) { gear in
                GearRow(title: gear.name.capitalized, icon: "gear",
                        level: gear.level, owned: true)
            }
        }
    }

    private var hyperSection: some View {
        section("Hypercharge", icon: hyperBuffy ? "hypercharge_buffy" : "hypercharge",
                fallback: "flame.circle.fill", tint: .pink, buffy: hyperBuffy) {
            if brawler.hyperCharges.isEmpty {
                Text(brawler.hasHypercharge ? "Owned" : "Not released / not owned")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(brawler.hyperCharges) { hc in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(hc.name.capitalized)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fallbackList(_ names: [String]) -> some View {
        if names.isEmpty {
            Text("None owned").foregroundStyle(.secondary)
        } else {
            ForEach(names, id: \.self) { name in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(name.capitalized)
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, icon: String, fallback: String,
                                        tint: Color, buffy: Bool = false,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                UIIcon(name: icon, size: 22, fallbackSymbol: fallback, fallbackTint: tint)
                Text(title).font(.headline)
                if buffy {
                    Label("Buffy", systemImage: "arrow.up.circle.fill")
                        .font(.caption).foregroundStyle(.cyan)
                        .labelStyle(.titleAndIcon)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// One gear row: full-color icon + level when owned, greyed + lock when not.
struct GearRow: View {
    let title: String
    let icon: String
    let level: Int?
    let owned: Bool

    var body: some View {
        HStack(spacing: 10) {
            UIIcon(name: icon, size: 22, fallbackSymbol: "gearshape.fill",
                   fallbackTint: owned ? .cyan : .secondary)
                .grayscale(owned ? 0 : 1)
                .opacity(owned ? 1 : 0.4)
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(owned ? .primary : .secondary)
            Spacer()
            if owned {
                if let level { Text("Lv \(level)").foregroundStyle(.secondary) }
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
        .opacity(owned ? 1 : 0.85)
    }
}

/// One star power / gadget row: full-color when owned, dimmed + lock when not.
struct ItemRow: View {
    let name: String
    let description: String?
    let owned: Bool
    var iconURL: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let iconURL, let url = URL(string: iconURL) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFit() }
                    else { Color.clear }
                }
                .frame(width: 30, height: 30)
                .grayscale(owned ? 0 : 1).opacity(owned ? 1 : 0.5)
            }
            Image(systemName: owned ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(owned ? .green : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized)
                    .fontWeight(.semibold)
                    .foregroundStyle(owned ? .primary : .secondary)
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if !owned {
                Text("Not owned").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .opacity(owned ? 1 : 0.75)
    }
}

struct Tag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color, in: Capsule())
    }
}

struct DetailStat: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.title3.weight(.bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension Color {
    /// Init from a "#rrggbb" hex string (BrawlAPI rarity colors).
    init?(hex: String?) {
        guard var hex else { return nil }
        hex = hex.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255)
    }
}

struct CostTile: View {
    let title: String
    let cost: ResourceCost
    let lines: [CostLine]
    let tint: Color
    let doneText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                if cost.isZero, let doneText {
                    Label(doneText, systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill").foregroundStyle(.yellow)
                        Text(cost.coins.formatted()).font(.title3.weight(.bold).monospacedDigit())
                        Text("coins").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.circle.fill").foregroundStyle(.pink)
                        Text(cost.powerPoints.formatted()).font(.title3.weight(.bold).monospacedDigit())
                        Text("PP").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 170, alignment: .leading)

            if !lines.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 5) {
                    ForEach(lines) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(line.label).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 6)
                            Text(line.cost.coins.formatted() + "c").font(.caption.monospacedDigit())
                            if line.cost.powerPoints > 0 {
                                Text("· " + line.cost.powerPoints.formatted() + "pp").font(.caption.monospacedDigit()).foregroundStyle(.pink)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }
}
