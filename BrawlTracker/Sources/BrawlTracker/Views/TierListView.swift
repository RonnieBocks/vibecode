import SwiftUI

struct TierListView: View {
    @Environment(PlayerStore.self) private var store
    @Environment(TierListStore.self) private var tierList

    private enum Naming: Identifiable { case new, rename, duplicate
        var id: Int { hashValue } }
    @State private var naming: Naming?
    @State private var nameField = ""
    @State private var confirmReset = false

    /// Full roster (all brawlers) from the BrawlAPI reference, falling back to
    /// the owned roster if the reference hasn't loaded.
    private var roster: [TierBrawler] {
        let source: [TierBrawler]
        if !store.reference.isEmpty {
            source = store.reference.values.map { TierBrawler(id: $0.id, name: $0.name) }
        } else if let player = store.player {
            source = player.brawlers.map { TierBrawler(id: $0.id, name: $0.name) }
        } else {
            source = []
        }
        return source.sorted { $0.name < $1.name }
    }

    private var byID: [Int: TierBrawler] {
        Dictionary(roster.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(TierListStore.tiers) { tier in
                    TierRow(tier: tier,
                            brawlers: tierList.ids(in: tier.label).compactMap { byID[$0] },
                            onAppend: { id in tierList.move(id, to: tier.label) },
                            onInsertBefore: { id, target in
                                tierList.move(id, to: tier.label, before: target)
                            })
                }

                UnrankedPool(brawlers: tierList.unranked(from: roster).compactMap { byID[$0] }) { id in
                    tierList.move(id, to: nil)
                }
            }
            .padding(16)
        }
        .navigationTitle(tierList.active?.name ?? "Tier List")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Tier List", selection: Binding(
                        get: { tierList.activeID },
                        set: { tierList.select($0) })) {
                        ForEach(tierList.lists) { Text($0.name).tag($0.id) }
                    }
                    Divider()
                    Button("New Tier List…") { nameField = ""; naming = .new }
                    Button("Duplicate…") {
                        nameField = (tierList.active?.name ?? "Tier List") + " copy"; naming = .duplicate
                    }
                    Button("Rename…") { nameField = tierList.active?.name ?? ""; naming = .rename }
                    Button("Delete", role: .destructive) { tierList.deleteActive() }
                        .disabled(tierList.lists.count <= 1)
                    if let b = tierList.lastCleared {
                        Divider()
                        Button("Restore last reset (\(b.name), \(b.date.formatted(date: .abbreviated, time: .shortened)))") {
                            tierList.restoreLastCleared()
                        }
                    }
                } label: {
                    Label(tierList.active?.name ?? "Tier List", systemImage: "square.stack.3d.up.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .help("Move all brawlers in this list back to Unranked")
            }
        }
        .confirmationDialog("Reset “\(tierList.active?.name ?? "this list")”?", isPresented: $confirmReset,
                            titleVisibility: .visible) {
            Button("Reset — move everyone to Unranked", role: .destructive) { tierList.clearActive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A backup is kept, and you can bring it back from the list menu with “Restore last reset”.")
        }
        .alert(namingTitle, isPresented: Binding(get: { naming != nil },
                                                 set: { if !$0 { naming = nil } })) {
            TextField("Name", text: $nameField)
            Button("Cancel", role: .cancel) { naming = nil }
            Button("Save") { commitNaming() }
        }
    }

    private var namingTitle: String {
        switch naming {
        case .new: return "New Tier List"
        case .duplicate: return "Duplicate Tier List"
        case .rename: return "Rename Tier List"
        case .none: return ""
        }
    }

    private func commitNaming() {
        switch naming {
        case .new: tierList.newList(named: nameField)
        case .duplicate: tierList.duplicateActive(named: nameField)
        case .rename: tierList.renameActive(to: nameField)
        case .none: break
        }
        naming = nil
    }
}

private struct TierRow: View {
    let tier: TierListStore.Tier
    let brawlers: [TierBrawler]
    let onAppend: (Int) -> Void
    let onInsertBefore: (Int, Int) -> Void

    @State private var targeted = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(tier.label)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 52)
                .frame(maxHeight: .infinity)
                .background(tier.color)

            FlowLayout(spacing: 6) {
                ForEach(brawlers) { brawler in
                    ReorderableChip(brawler: brawler) { draggedID in
                        onInsertBefore(draggedID, brawler.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(6)
            .background(targeted ? Color.white.opacity(0.08) : Color.black.opacity(0.12))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // Row-level drop = append to end (dropping into empty space).
        .dropDestination(for: String.self) { items, _ in
            for s in items { if let id = Int(s) { onAppend(id) } }
            return true
        } isTargeted: { targeted = $0 }
    }
}

/// A chip that is both draggable and a drop target: dropping onto it inserts
/// the dragged brawler immediately before it. Shows an insertion bar when
/// targeted.
private struct ReorderableChip: View {
    let brawler: TierBrawler
    let onInsertBefore: (Int) -> Void
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 2) {
            Capsule()
                .fill(targeted ? Color.white : Color.clear)
                .frame(width: 3, height: 40)
            TierChip(brawler: brawler)
        }
        .dropDestination(for: String.self) { items, _ in
            for s in items { if let id = Int(s) { onInsertBefore(id) } }
            return true
        } isTargeted: { targeted = $0 }
    }
}

private struct UnrankedPool: View {
    let brawlers: [TierBrawler]
    let onDrop: (Int) -> Void
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UNRANKED — \(brawlers.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(brawlers) { TierChip(brawler: $0) }
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(6)
            .background(targeted ? Color.white.opacity(0.08) : Color.black.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 4)
        .dropDestination(for: String.self) { items, _ in
            for s in items { if let id = Int(s) { onDrop(id) } }
            return true
        } isTargeted: { targeted = $0 }
    }
}

struct TierChip: View {
    let brawler: TierBrawler
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            BrawlerRarityTable.rarity(for: brawler.name).color
            if let image = BrawlerArt.image(named: brawler.name) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFill()
            } else {
                Text(BrawlerArt.initials(brawler.name))
                    .font(.system(size: size * 0.32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size * 0.86)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .help(brawler.name.capitalized)
        .draggable("\(brawler.id)")
    }
}

/// Simple wrapping flow layout.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let width = maxWidth == .infinity ? x : maxWidth
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
