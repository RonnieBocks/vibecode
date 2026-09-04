import SwiftUI

/// App-wide navigation state (so menu commands can switch tabs).
@MainActor
@Observable
final class AppNav {
    var selection: SidebarTab = SidebarTab(rawValue: UserDefaults.standard.string(forKey: "lastTab") ?? "") ?? .brawlers {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: "lastTab") }
    }
}

@main
struct BrawlTrackerApp: App {
    @State private var store = PlayerStore()
    @State private var tierList = TierListStore()
    @State private var mapData = MapDataStore()
    @State private var matchLog = MatchLogStore()
    @State private var rankedSettings = RankedSettings()
    @State private var archive = BattleArchiveStore()
    @State private var seasons = SeasonStore()
    @State private var skins = SkinStore()
    @State private var snapshots = SnapshotStore()
    @State private var nav = AppNav()
    @State private var draftConfig = DraftConfigStore()
    @State private var draftSession = DraftSessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store).environment(tierList).environment(mapData).environment(matchLog)
                .environment(rankedSettings).environment(archive).environment(seasons).environment(skins)
                .environment(snapshots).environment(nav).environment(draftConfig).environment(draftSession)
                .frame(minWidth: 960, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh from API") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandMenu("Go") {
                ForEach(Array(SidebarTab.allCases.enumerated()), id: \.element) { i, tab in
                    Button(tab.rawValue) { nav.selection = tab }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                }
            }
        }
    }
}

enum SidebarTab: String, CaseIterable, Identifiable {
    case brawlers = "My Brawlers"
    case tierList = "Tier List"
    case ranked = "Ranked"
    case maps = "Maps"
    case progression = "Progression"
    case battles = "Battles"
    case wardrobe = "Wardrobe"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .brawlers: return "person.3.fill"
        case .tierList: return "square.stack.3d.up.fill"
        case .ranked: return "trophy.fill"
        case .maps: return "map.fill"
        case .progression: return "chart.line.uptrend.xyaxis"
        case .battles: return "list.bullet.rectangle"
        case .wardrobe: return "tshirt.fill"
        }
    }
}

struct RootView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(SkinStore.self) private var skins
    @Environment(SnapshotStore.self) private var snapshots
    @Environment(MapDataStore.self) private var mapData
    @Environment(TierListStore.self) private var tierList
    @Environment(AppNav.self) private var nav
    @State private var showingSettings = false
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        @Bindable var nav = nav
        NavigationSplitView {
            VStack(spacing: 0) {
                List(SidebarTab.allCases, selection: Binding(get: { Optional(nav.selection) },
                                                             set: { if let t = $0 { nav.selection = t } })) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol).tag(tab)
                }
                .listStyle(.sidebar)
                Divider()
                AccountFooter(player: store.player, usingSample: store.usingSample, lastUpdated: store.lastUpdated)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                        .help("Refresh from the API (⌘R)").disabled(store.status == .loading)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.help("Settings")
                }
            }
        } detail: {
            detail
        }
        .overlay(alignment: .top) { banner }
        .overlay(alignment: .bottom) {
            if let toast = store.toast { ToastView(text: toast).transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .overlay { if store.status == .loading && store.player == nil { loadingOverlay } }
        .task { await store.load() }
        .onChange(of: store.status) { _, newValue in
            if newValue == .needsSetup { showingSettings = true }
        }
        .onChange(of: store.lastUpdated) { _, _ in
            guard !store.usingSample, let player = store.player else { return }
            let added = archive.ingest(store.battles, myTag: AppConfig.playerTag ?? "")
            skins.observe(player)
            snapshots.record(player)
            if added > 0 { store.toast = "Archived \(added) new battle\(added == 1 ? "" : "s")" }
        }
        .onChange(of: store.toast) { _, new in
            toastTask?.cancel()
            guard new != nil else { return }
            toastTask = Task { try? await Task.sleep(for: .seconds(4)); withAnimation { store.toast = nil } }
        }
        .sheet(isPresented: $showingSettings) { SettingsView().environment(store) }
    }

    @ViewBuilder
    private var detail: some View {
        switch nav.selection {
        case .brawlers:
            if let player = store.player {
                VStack(spacing: 0) {
                    if store.usingSample {
                        SetupChecklistView(connected: false,
                                           hasPool: !mapData.rotation.isEmpty,
                                           hasTiers: !(tierList.active?.assignments.isEmpty ?? true)) { showingSettings = true }
                            .padding([.horizontal, .top], 20)
                    }
                    MyBrawlersView(brawlers: player.brawlers)
                }
            } else {
                ContentUnavailableView {
                    Label("No brawlers loaded", systemImage: "person.3")
                } description: {
                    Text(store.errorMessage ?? "Connect your account in Settings.")
                }
            }
        case .tierList: TierListView()
        case .ranked: RankedView()
        case .maps: MapsView()
        case .progression: ProgressionView()
        case .battles: BattlesView()
        case .wardrobe: WardrobeView()
        }
    }

    @ViewBuilder
    private var banner: some View {
        if store.status == .failed, let msg = store.errorMessage {
            BannerView(text: msg, systemImage: "exclamationmark.triangle.fill", tint: .orange) {
                Button("Settings") { showingSettings = true }
                Button("Retry") { Task { await store.refresh() } }
            }
        } else if store.usingSample && store.status != .loading {
            BannerView(text: "Showing bundled sample data — connect your account for live stats.",
                       systemImage: "info.circle.fill", tint: .blue) {
                Button("Connect") { showingSettings = true }
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
            ProgressView("Fetching your account…")
                .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .ignoresSafeArea()
    }
}

struct BannerView<Actions: View>: View {
    let text: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer()
            actions
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct AccountFooter: View {
    let player: Player?
    let usingSample: Bool
    let lastUpdated: Date?

    var body: some View {
        if let player {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if usingSample {
                        Text("SAMPLE").font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.blue.opacity(0.25), in: Capsule())
                    }
                }
                HStack(spacing: 10) {
                    Label("\(player.trophies)", systemImage: "trophy.fill").foregroundStyle(.yellow)
                    if let ranked = player.rankedRankName {
                        Label(ranked.capitalized, systemImage: "rosette").foregroundStyle(.orange)
                    }
                }
                .font(.caption).labelStyle(.titleAndIcon)
                if let lastUpdated {
                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        Text("Updated \(lastUpdated, style: .relative) ago").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }
}
