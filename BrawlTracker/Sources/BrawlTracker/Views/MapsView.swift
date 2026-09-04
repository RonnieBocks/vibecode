import SwiftUI

struct MapsView: View {
    @Environment(MapDataStore.self) private var mapData

    @State private var selectedMap: GameMap?
    @State private var showAddSheet = false

    private enum Naming: Identifiable { case new, rename, duplicate
        var id: Int { hashValue } }
    @State private var naming: Naming?
    @State private var nameField = ""
    @State private var autofillMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        Group {
            if mapData.maps.isEmpty && mapData.isLoading {
                ProgressView("Loading maps…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mapData.maps.isEmpty {
                ContentUnavailableView {
                    Label("No map data", systemImage: "map")
                } description: {
                    Text("Couldn't load maps from BrawlAPI. Check your connection and try again.")
                }
            } else {
                content
            }
        }
        .navigationTitle(mapData.activePool?.name ?? "Maps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        let r = await mapData.autofillFromEvents()
                        autofillMessage = r.found == 0
                            ? "The live rotation feed is empty right now — nothing to import. Try again once Brawlify publishes the next rotation."
                            : "Found \(r.found) \(r.rankedOnly ? "ranked " : "")rotation map\(r.found == 1 ? "" : "s"); added \(r.added) new to “\(mapData.activePool?.name ?? "pool")”."
                    }
                } label: { Label("Autofill rotation", systemImage: "arrow.down.circle") }
                .help("Import the live event rotation into this pool (ranked slots preferred when present)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: {
                    Label("Add Maps", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Pool", selection: Binding(get: { mapData.activePoolID },
                                                      set: { mapData.selectPool($0) })) {
                        ForEach(mapData.pools) { Text($0.name).tag($0.id) }
                    }
                    Divider()
                    Button("New Pool…") { nameField = ""; naming = .new }
                    Button("Duplicate…") {
                        nameField = (mapData.activePool?.name ?? "Pool") + " copy"; naming = .duplicate
                    }
                    Button("Rename…") { nameField = mapData.activePool?.name ?? ""; naming = .rename }
                    Button("Delete", role: .destructive) { mapData.deleteActivePool() }
                        .disabled(mapData.pools.count <= 1)
                } label: {
                    Label(mapData.activePool?.name ?? "Pool", systemImage: "square.stack.3d.up.fill")
                }
            }
        }
        .task { await mapData.loadIfNeeded() }
        .sheet(item: $selectedMap) { MapDetailView(map: $0, mode: modeFor($0)) }
        .sheet(isPresented: $showAddSheet) { AddMapsSheet().environment(mapData) }
        .alert("Autofill rotation", isPresented: Binding(get: { autofillMessage != nil },
                                                          set: { if !$0 { autofillMessage = nil } })) {
            Button("OK") { autofillMessage = nil }
        } message: { Text(autofillMessage ?? "") }
        .alert(namingTitle, isPresented: Binding(get: { naming != nil },
                                                 set: { if !$0 { naming = nil } })) {
            TextField("Season / pool name", text: $nameField)
            Button("Cancel", role: .cancel) { naming = nil }
            Button("Save") { commitNaming() }
        }
    }

    @ViewBuilder
    private var content: some View {
        let poolMaps = mapData.rotationMaps
        ScrollView {
            VStack(spacing: 12) {
                if !mapData.rotationModes.isEmpty {
                    RotationSummary(name: mapData.activePool?.name ?? "Pool",
                                    count: poolMaps.count,
                                    modes: mapData.rotationModes.map(\.name)) {
                        mapData.clearRotation()
                    }
                }
                if poolMaps.isEmpty {
                    ContentUnavailableView {
                        Label("This pool is empty", systemImage: "map")
                    } description: {
                        Text("Add maps from the full catalog to build this season's rotation.")
                    } actions: {
                        Button("Add Maps") { showAddSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 300)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(poolMaps) { map in
                            MapCard(map: map, inRotation: true,
                                    onToggleRotation: { mapData.toggleRotation(map.id) })
                                .onTapGesture { selectedMap = map }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func modeFor(_ map: GameMap) -> GameMode? {
        guard let id = map.gameMode?.id else { return nil }
        return mapData.modes.first { $0.id == id }
    }

    private var namingTitle: String {
        switch naming {
        case .new: return "New Map Pool"
        case .duplicate: return "Duplicate Pool"
        case .rename: return "Rename Pool"
        case .none: return ""
        }
    }

    private func commitNaming() {
        switch naming {
        case .new: mapData.newPool(named: nameField)
        case .duplicate: mapData.duplicateActivePool(named: nameField)
        case .rename: mapData.renameActivePool(to: nameField)
        case .none: break
        }
        naming = nil
    }
}

/// Full-catalog browser for adding/removing maps to the active pool.
struct AddMapsSheet: View {
    @Environment(MapDataStore.self) private var mapData
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var selectedModeID: Int? = nil
    @State private var inPoolOnly = false

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Add to \(mapData.activePool?.name ?? "pool")").font(.headline)
                Spacer()
                Text("\(mapData.rotation.count) selected").foregroundStyle(.secondary)
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)

            HStack(spacing: 10) {
                TextField("Search maps", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Menu {
                    Picker("Game Mode", selection: $selectedModeID) {
                        Text("All Modes").tag(Int?.none)
                        ForEach(mapData.modes) { Text($0.name).tag(Int?.some($0.id)) }
                    }
                } label: {
                    Label(selectedModeName, systemImage: "line.3.horizontal.decrease.circle")
                }
                Toggle("Selected only", isOn: $inPoolOnly).toggleStyle(.button)
                Spacer()
                Text("\(filtered.count) maps").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { map in
                        MapCard(map: map, inRotation: mapData.isInRotation(map.id),
                                onToggleRotation: { mapData.toggleRotation(map.id) })
                            .onTapGesture { mapData.toggleRotation(map.id) }
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
    }

    private var selectedModeName: String {
        guard let id = selectedModeID, let m = mapData.modes.first(where: { $0.id == id }) else { return "All Modes" }
        return m.name
    }

    private var filtered: [GameMap] {
        var result = mapData.maps
        if inPoolOnly { result = result.filter { mapData.isInRotation($0.id) } }
        if let id = selectedModeID { result = result.filter { $0.gameMode?.id == id } }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { result = result.filter { $0.name.lowercased().contains(q) } }
        return result.sorted { a, b in
            let aOff = a.disabled ?? false, bOff = b.disabled ?? false
            if aOff != bOff { return !aOff }
            return (a.gameMode?.name ?? "", a.name) < (b.gameMode?.name ?? "", b.name)
        }
    }
}

struct MapCard: View {
    let map: GameMap
    var inRotation: Bool = false
    var onToggleRotation: () -> Void = {}

    private var modeColor: Color { Color(hex: map.gameMode?.color) ?? .gray }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    modeColor.opacity(0.25)
                    MapImage(url: map.imageUrl)
                }
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .clipped()

                Button(action: onToggleRotation) {
                    Image(systemName: inRotation ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(inRotation ? .yellow : .white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .help(inRotation ? "Remove from this pool" : "Add to this pool")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(map.name).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    if let mode = map.gameMode?.name { Tag(text: mode, color: modeColor) }
                    if map.isNew == true { Tag(text: "New", color: .green) }
                    if map.disabled == true { Tag(text: "Retired", color: .secondary) }
                    Spacer()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(inRotation ? Color.yellow : .white.opacity(0.06),
                          lineWidth: inRotation ? 2 : 1))
        .opacity((map.disabled ?? false) ? 0.6 : 1)
        .contentShape(Rectangle())
    }
}

struct RotationSummary: View {
    let name: String
    let count: Int
    let modes: [String]
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) — \(count) map\(count == 1 ? "" : "s")")
                    .font(.callout.weight(.semibold))
                Text(modes.isEmpty ? "No modes yet" : modes.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Clear", role: .destructive, action: onClear)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.yellow.opacity(0.4), lineWidth: 1))
    }
}

/// Remote map image with a graceful placeholder (brawlify CDN).
struct MapImage: View {
    let url: String?

    var body: some View {
        AsyncImage(url: url.flatMap { URL(string: $0) }) { phase in
            switch phase {
            case .success(let image):
                image.resizable().interpolation(.high).scaledToFill()
            case .empty:
                ProgressView().controlSize(.small)
            case .failure:
                Image(systemName: "map").font(.largeTitle).foregroundStyle(.secondary)
            @unknown default:
                Color.clear
            }
        }
    }
}

struct MapDetailView: View {
    let map: GameMap
    let mode: GameMode?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MapImage(url: map.imageUrl)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(map.name).font(.largeTitle.weight(.bold))

                HStack(spacing: 8) {
                    if let name = map.gameMode?.name {
                        Tag(text: name, color: Color(hex: map.gameMode?.color) ?? .gray)
                    }
                    if let env = map.environment?.name { Tag(text: env, color: .secondary) }
                }

                if let desc = mode?.description ?? mode?.shortDescription, !desc.isEmpty {
                    Text(desc).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }
}
