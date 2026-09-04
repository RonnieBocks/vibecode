import SwiftUI
import Observation

/// One ban/pick action, for undo.
struct DraftHistoryEntry: Codable, Hashable {
    var isBan: Bool
    var seat: Int
}

@MainActor
@Observable
final class DraftSession {
    enum Phase: String, Codable { case setup, toss, seat, bans, picks, summary }

    var phase: Phase = .setup
    var mode: String?
    var map: GameMap?
    var wonToss: Bool?

    /// Seats 0,1,2 = your team (left); 3,4,5 = enemy (right). Outermost seats
    /// (0 and 5) pick first, the inner two (2 and 3) pick last.
    var mySeat: Int?
    var activeBanSeat: Int?
    var seatBans: [Int: Int] = [:]
    var seatPicks: [Int: Int] = [:]
    var series: [GameResult] = [.none, .none, .none]
    var notes: String = ""
    var noteTags: Set<MatchNoteTag> = []
    /// Series cut short by a crash/disconnect — games played still count, the
    /// series verdict doesn't.
    var incomplete: Bool = false
    /// Seats acted on, in order — for ⌘Z.
    var history: [DraftHistoryEntry] = []
    /// What the engine recommended at your ban / pick (for the match review).
    var banSuggestionSnapshot: [String] = []
    var pickSuggestionSnapshot: [String] = []
    var myPickWasSuggested: Bool?

    func undoLast() {
        guard let last = history.popLast() else { return }
        if last.isBan { seatBans[last.seat] = nil; activeBanSeat = last.seat; phase = .bans }
        else { seatPicks[last.seat] = nil; if phase == .summary { phase = .picks } }
    }

    static let myTeamSeats = [0, 1, 2]
    static let enemySeats = [3, 4, 5]

    func isAllySeat(_ seat: Int) -> Bool { seat < 3 }

    var seatToGlobal: [Int: Int] {
        (wonToss ?? true)
            ? [0: 1, 1: 4, 2: 5, 5: 2, 4: 3, 3: 6]
            : [5: 1, 0: 2, 1: 3, 4: 4, 3: 5, 2: 6]
    }
    func globalPick(_ seat: Int) -> Int { seatToGlobal[seat] ?? 99 }

    var currentPickSeat: Int? {
        (0...5).filter { seatPicks[$0] == nil }.min { globalPick($0) < globalPick($1) }
    }

    var bannedIDs: Set<Int> { Set(seatBans.values) }
    var pickedIDs: Set<Int> { Set(seatPicks.values) }

    func advanceBan() { activeBanSeat = (0...5).first { seatBans[$0] == nil } }
}

struct RankedView: View {
    /// The in-progress draft lives at app level so switching tabs (which tears
    /// this view down) doesn't discard it.
    @Environment(DraftSessionStore.self) private var sessions
    @State private var showModel = false
    @State private var reviewing: MatchRecord?
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(MatchLogStore.self) private var matchLog
    @Environment(DraftConfigStore.self) private var configStore
    @Environment(PlayerStore.self) private var store

    var body: some View {
        Group {
            if let session = sessions.session {
                NewMatchView(session: session) { sessions.end() }
            } else {
                startScreen
            }
        }
        .navigationTitle("Ranked")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showModel = true } label: { Label("Draft Model", systemImage: "slider.horizontal.3") }
                    .help("How suggestions are computed — every weight and rule is editable")
            }
        }
        .sheet(isPresented: $showModel) { DraftModelView().environment(configStore).environment(store).environment(archive).environment(matchLog) }
        .sheet(item: $reviewing) { MatchReviewView(match: $0).environment(archive).environment(matchLog) }
    }

    private var startScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill").font(.system(size: 44)).foregroundStyle(.yellow)
                    Text("Ranked Draft Assistant").font(.title.weight(.bold))
                    if !matchLog.matches.isEmpty {
                        VStack(spacing: 2) {
                            Text("\(matchLog.seriesWon)–\(matchLog.seriesLost) series").font(.headline).foregroundStyle(.secondary)
                            if matchLog.incompleteCount > 0 {
                                Text("+\(matchLog.incompleteCount) cut short").font(.caption).foregroundStyle(.orange)
                                    .help("Crashed or disconnected series — the games played still count toward brawler records")
                            }
                            Text("logged drafts only — the Battles tab counts every archived game")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Button { sessions.start() } label: {
                        Label("New Match", systemImage: "plus.circle.fill").font(.headline).padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                }
                .padding(.top, 30)

                if !matchLog.matches.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MATCH LOG").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text("Tap a match to review it.").font(.caption2).foregroundStyle(.secondary)
                        ForEach(matchLog.matches) { match in
                            MatchLogRow(match: match) { matchLog.delete(match.id) }
                                .contentShape(Rectangle())
                                .onTapGesture { reviewing = match }
                        }
                    }
                    .frame(maxWidth: 640)
                }
            }
            .frame(maxWidth: .infinity).padding(20)
        }
    }
}

struct MatchLogRow: View {
    let match: MatchRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: match.isIncomplete ? "exclamationmark.triangle.fill"
                                                 : match.seriesWon ? "checkmark.seal.fill" : "xmark.seal.fill")
                .foregroundStyle(match.isIncomplete ? .orange : match.seriesWon ? .green : .red)
                .help(match.isIncomplete ? "Series cut short — games played still count, the result doesn't" : "")
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.mode) · \(match.mapName)").font(.callout.weight(.semibold)).lineLimit(1)
                HStack(spacing: 6) { ForEach(match.myTeam, id: \.self) { MiniBrawler(name: $0, size: 24) } }
            }
            Spacer()
            HStack(spacing: 3) {
                ForEach(Array(match.series.enumerated()), id: \.offset) { _, g in
                    Text(g.rawValue).font(.caption.weight(.black)).foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(g == .win ? Color.green : g == .loss ? Color.red : Color.secondary.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
            }
            if match.isIncomplete {
                Text("CUT SHORT").font(.system(size: 8, weight: .bold)).foregroundStyle(.orange)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(.orange.opacity(0.18), in: Capsule())
            }
            if match.hasNotes {
                Image(systemName: "square.and.pencil").font(.caption)
                    .foregroundStyle(.secondary).help("Has notes")
            }
            Button { onDelete() } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain)
        }
        .padding(10).background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Walkthrough

struct NewMatchView: View {
    @Bindable var session: DraftSession
    var onExit: () -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(TierListStore.self) private var tierList
    @Environment(MapDataStore.self) private var mapData
    @Environment(MatchLogStore.self) private var matchLog
    @Environment(RankedSettings.self) private var rankedSettings
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(DraftSessionStore.self) private var sessions

    /// Learned from every archived battle + logged ranked series (recency-weighted).
    /// Cached: rebuilding it per tile per render was thousands of rebuilds a frame.
    @State private var learning = DraftLearning(archive: [], matches: [])
    private func rebuildLearning() {
        learning = DraftLearning(archive: archive.records, matches: matchLog.matches)
    }

    @State private var search = ""
    @State private var roleFilter: DraftClass? = nil
    @State private var eligibleOnly = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            switch session.phase {
            case .setup, .toss, .seat, .summary:
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        stepHeader
                        switch session.phase {
                        case .setup: setupPhase
                        case .toss: tossPhase
                        case .seat: seatPhase
                        case .summary: summaryPhase
                        default: EmptyView()
                        }
                    }
                    .padding(22).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            case .bans, .picks:
                draftBoard.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .task { await mapData.loadIfNeeded() }
        .onAppear { rebuildLearning() }
        .onDisappear { sessions.save() }
        .onChange(of: session.phase) { _, _ in sessions.save() }
        .onChange(of: session.seatPicks) { _, _ in sessions.save() }
        .onChange(of: session.seatBans) { _, _ in sessions.save() }
        .onChange(of: archive.records.count) { _, _ in rebuildLearning() }
        .onChange(of: matchLog.matches.count) { _, _ in rebuildLearning() }
    }

    private var stepHeader: some View {
        HStack {
            Button { onExit() } label: { Label("Exit", systemImage: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
            if let mode = session.mode {
                Text(mode).font(.headline)
                if let map = session.map { Text("· \(map.name)").foregroundStyle(.secondary) }
            }
            Spacer()
            if let won = session.wonToss { Tag(text: won ? "First pick" : "Second pick", color: won ? .green : .orange) }
        }
    }

    // MARK: Setup / toss / seat

    private var setupPhase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose mode & map").font(.title2.weight(.bold))
            if mapData.rotationMaps.isEmpty {
                Text("Your active map pool is empty. Add maps in the Maps tab to set the ranked rotation first.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(mapData.rotationModes) { mode in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(mode.name).font(.headline)
                            Tag(text: DraftPlaybook.meta(forMode: mode.name).rawValue,
                                color: DraftPlaybook.meta(forMode: mode.name) == .aggro ? .coralish : .blueish)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                            ForEach(mapsForMode(mode.id)) { map in
                                MapPickButton(map: map) { session.mode = mode.name; session.map = map; session.phase = .toss }
                            }
                        }
                    }
                }
            }
        }
    }

    private var tossPhase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Coin toss").font(.title2.weight(.bold))
            Text("Did you win the coin toss (first pick)?").foregroundStyle(.secondary)
            HStack(spacing: 12) {
                bigChoice("Won — first pick", "checkmark.circle.fill", .green) { session.wonToss = true; session.phase = .seat }
                bigChoice("Lost — second pick", "arrow.uturn.down.circle.fill", .orange) { session.wonToss = false; session.phase = .seat }
            }
        }
    }

    private var seatPhase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your position").font(.title2.weight(.bold))
            Text("You're on the blue team (left). First pick sits on the outside, last pick on the inside. Tap your seat.")
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 6) {
                ForEach(DraftSession.myTeamSeats, id: \.self) { seat in
                    Button {
                        session.mySeat = seat; session.activeBanSeat = seat; session.phase = .bans
                        searchFocused = true
                    } label: { seatChoice(seat, selectable: true) }
                    .buttonStyle(.plain)
                }
                Text("VS").font(.headline).foregroundStyle(.secondary).padding(.horizontal, 6)
                ForEach(DraftSession.enemySeats, id: \.self) { seat in seatChoice(seat, selectable: false) }
            }
        }
    }

    private func seatChoice(_ seat: Int, selectable: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Pick \(session.globalPick(seat))").font(.headline)
            Text(selectable ? "You?" : "Enemy").font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 62)
        .background((selectable ? Color.blue : Color.red).opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selectable ? Color.blue : Color.red, lineWidth: 1))
        .opacity(selectable ? 1 : 0.5)
    }

    // MARK: Summary + series

    private var summaryPhase: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Draft complete").font(.title2.weight(.bold))
                Spacer()
                winChanceBadge
            }
            if !winEstimate.factors.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(winEstimate.factors, id: \.self) { Text("• " + $0).font(.caption).foregroundStyle(.secondary) }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                banColumn(seats: DraftSession.myTeamSeats, title: "BANS", tint: .blue)
                playerRow
                banColumn(seats: DraftSession.enemySeats, title: "BANS", tint: .red)
            }
            GamePlanView(plan: MatchTips.plan(
                mode: session.mode ?? "", map: session.map?.name,
                myBrawler: session.mySeat.flatMap { session.seatPicks[$0] }.map { nameFor($0) },
                myTeam: DraftSession.myTeamSeats.compactMap { session.seatPicks[$0] }.map { nameFor($0) },
                enemy: DraftSession.enemySeats.compactMap { session.seatPicks[$0] }.map { nameFor($0) },
                learning: learning))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Series result").font(.headline)
                    Spacer()
                    Text(session.series.map(\.rawValue).joined(separator: "-")).font(.title3.weight(.black).monospaced())
                }
                Text("Tap each game: W = win, L = loss, X = not played.").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) { ForEach(0..<3, id: \.self) { gameResultControl(index: $0) } }
                Divider().padding(.top, 4)
                Toggle(isOn: $session.incomplete) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Series cut short (crash or disconnect)")
                        Text("The games you played still count toward every brawler's record — only the series win/loss and the win-chance accuracy check skip it.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(14).background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            MatchNotesEditor(notes: $session.notes, tags: $session.noteTags)
                .padding(14)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Save Match") { saveMatch() }.buttonStyle(.borderedProminent)
                Button("Back to draft") { session.phase = .picks }
                Button("Discard") { onExit() }
            }
        }
    }

    private func gameResultControl(index: Int) -> some View {
        VStack(spacing: 6) {
            Text("Game \(index + 1)").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(GameResult.allCases, id: \.self) { result in
                    Button { session.series[index] = result } label: {
                        Text(result.rawValue).font(.headline.weight(.black))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(session.series[index] == result ? .white : .secondary)
                            .background(session.series[index] == result ? tint(result) : Color.secondary.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tint(_ r: GameResult) -> Color {
        switch r { case .win: return .green; case .loss: return .red; case .none: return .gray }
    }

    // MARK: - Draft board

    private var draftBoard: some View {
        let ids = suggestedIDs
        let tint = recHeading.tint
        return ScrollView(.vertical) {
          VStack(spacing: 0) {
            boardTopBar
            turnBanner
            recommendedRow
            pickerBar
            brawlerStrip(suggested: ids, tint: tint)
            Divider()
            HStack(alignment: .top, spacing: 18) {
                if session.phase == .picks { banColumn(seats: DraftSession.myTeamSeats, title: "BANS", tint: .blue) }
                playerRow
                if session.phase == .picks { banColumn(seats: DraftSession.enemySeats, title: "BANS", tint: .red) }
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            if session.phase == .picks { checklistCard.padding(.horizontal, 16).padding(.bottom, 12) }
            if session.phase == .bans {
                Button("Start Drafting") { session.phase = .picks; searchFocused = true }
                    .buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom, 14)
            }
          }
        }
    }

    private var boardTopBar: some View {
        HStack(spacing: 12) {
            Button { onExit() } label: { Image(systemName: "xmark").padding(6) }.buttonStyle(.plain)
            if let mode = session.mode {
                VStack(alignment: .leading, spacing: 0) {
                    Text(mode).font(.headline)
                    if let map = session.map { Text(map.name).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            VStack(spacing: 4) {
                winChanceBadge
                HStack(spacing: 6) {
                    ForEach(1...6, id: \.self) { g in
                        Circle().fill(session.seatPicks.values.count >= g ? Color.yellow : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            Spacer()
            Button { session.undoLast() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(session.history.isEmpty)
                .help("Undo last ban/pick (⌘Z)")
            if let won = session.wonToss { Tag(text: won ? "First pick" : "Second pick", color: won ? .green : .orange) }
        }
        .padding(.horizontal, 12).padding(.vertical, 8).background(.background.secondary)
    }

    private var turnBanner: some View {
        HStack(spacing: 8) {
            Text(turnTitle).font(.headline)
            Spacer()
            if session.phase == .bans {
                Text("\(session.seatBans.count)/6 banned").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    private var turnTitle: String {
        if session.phase == .bans {
            guard let seat = session.activeBanSeat else { return "All bans logged — Start Drafting" }
            if seat == session.mySeat { return "Ban a Brawler — your ban" }
            return "Ban a Brawler — \(session.isAllySeat(seat) ? "teammate" : "enemy") (seat \(seat + 1))"
        }
        guard let seat = session.currentPickSeat else { return "Draft complete" }
        if seat == session.mySeat { return "YOUR PICK" }
        return session.isAllySeat(seat) ? "Teammate is picking" : "Enemy is picking"
    }

    // MARK: Recommendations

    private var myTurn: Bool {
        switch session.phase {
        case .bans: return session.activeBanSeat == session.mySeat
        case .picks: return session.currentPickSeat == session.mySeat
        default: return false
        }
    }

    /// The seat currently being logged, and whose side it is.
    private var activeSeat: Int? {
        session.phase == .bans ? session.activeBanSeat : session.currentPickSeat
    }
    private var currentPerspective: DraftPerspective? {
        guard let seat = activeSeat else { return nil }
        if seat == session.mySeat { return .you }
        return session.isAllySeat(seat) ? .teammate : .enemy
    }

    /// The next seat on your side still to pick (yours or a teammate's).
    private var nextOwnSeat: Int? {
        (0...5).filter { session.isAllySeat($0) && session.seatPicks[$0] == nil }
               .min { session.globalPick($0) < session.globalPick($1) }
    }

    /// The seat the recommendation row is actually about. While an opponent
    /// picks we look ahead to your side's next pick instead of guessing theirs.
    private var adviceSeat: (seat: Int, perspective: DraftPerspective, isPreview: Bool)? {
        guard session.phase == .picks else { return nil }
        guard let current = session.currentPickSeat else { return nil }
        if session.isAllySeat(current) {
            return (current, current == session.mySeat ? .you : .teammate, false)
        }
        guard let next = nextOwnSeat else { return nil }
        return (next, next == session.mySeat ? .you : .teammate, true)
    }

    /// Picks to call out to a teammate whose seat hasn't picked yet, titled by
    /// the role their slot needs to fill.
    private func seatAdvice(_ seat: Int, limit: Int = 4)
        -> (suggestions: [DraftSuggestion], role: String, color: Color)? {
        guard session.phase == .picks, session.isAllySeat(seat),
              seat != session.mySeat, session.seatPicks[seat] == nil else { return nil }
        let a = DraftEngine.pickAdvice(baseContext(), globalPick: session.globalPick(seat),
                                       perspective: .teammate, limit: limit)
        guard !a.suggestions.isEmpty else { return nil }
        let role = a.targetClasses.isEmpty ? "COUNTER"
                 : a.targetClasses.map { $0.rawValue.uppercased() }.joined(separator: " / ")
        return (a.suggestions, role, a.targetClasses.first?.color ?? .secondary)
    }

    private var advice: PickAdvice? {
        guard let a = adviceSeat else { return nil }
        return DraftEngine.pickAdvice(baseContext(), globalPick: session.globalPick(a.seat), perspective: a.perspective)
    }

    private var suggestions: [DraftSuggestion] {
        if session.phase == .bans {
            guard let p = currentPerspective, p != .enemy else { return [] }
            return DraftEngine.banSuggestions(baseContext(), limit: 6)
        }
        return advice?.suggestions ?? []
    }

    /// Heading + tint for the recommendation row, based on whose turn it is.
    private var recHeading: (title: String, tint: Color) {
        if session.phase == .bans {
            guard let p = currentPerspective, let seat = activeSeat else { return ("", .yellow) }
            return p == .you ? ("RECOMMENDED BANS — YOUR BAN", .yellow)
                             : ("RECOMMENDED BANS — CALL IT OUT (seat \(seat + 1))", .blue)
        }
        guard let a = adviceSeat else { return ("", .yellow) }
        let pick = session.globalPick(a.seat)
        switch (a.perspective, a.isPreview) {
        case (.you, false): return ("RECOMMENDED FOR YOU", .yellow)
        case (.teammate, false): return ("RECOMMEND TO YOUR TEAMMATE (pick \(pick))", .blue)
        case (.you, true): return ("COMING UP — YOUR PICK \(pick)", .yellow)
        case (.teammate, true): return ("COMING UP — TEAMMATE PICK \(pick)", .blue)
        default: return ("", .yellow)
        }
    }

    private var suggestedIDs: Set<Int> {
        adviceSeat?.isPreview == true ? [] : Set(suggestions.map(\.id))
    }

    @ViewBuilder
    private var recommendedRow: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(recHeading.title)
                        .font(.caption.weight(.bold)).foregroundStyle(recHeading.tint)
                    if adviceSeat?.isPreview == true {
                        Text("preview while the enemy picks — may shift once their pick is in")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let advice {
                        Text(advice.guidance).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        if !advice.targetClasses.isEmpty {
                            HStack(spacing: 4) { ForEach(advice.targetClasses) { Tag(text: $0.rawValue, color: $0.color) } }
                        }
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions) { s in
                            // Previews aren't tappable: the current turn belongs
                            // to an opponent, so a tap would log THEIR pick.
                            RecTile(suggestion: s, tint: recHeading.tint,
                                    action: adviceSeat?.isPreview == true ? nil : { handleTap(s.id) })
                        }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
    }

    // MARK: Fast picker

    private var pickerBar: some View {
        HStack(spacing: 8) {
            TextField("Type a brawler, press Return to select", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .focused($searchFocused)
                .onSubmit { if let first = filteredRoster.first { handleTap(first.id) } }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DraftClass.allCases.filter { $0 != .unknown }) { cls in
                        Button(cls.rawValue) { roleFilter = roleFilter == cls ? nil : cls }
                            .buttonStyle(.bordered)
                            .tint(roleFilter == cls ? cls.color : .secondary)
                            .controlSize(.small)
                    }
                }
            }
            Toggle("Eligible", isOn: $eligibleOnly).toggleStyle(.button).controlSize(.small)
            Text("\(filteredRoster.count)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
    }

    private var filteredRoster: [TierBrawler] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        var list = roster.filter { b in
            (roleFilter == nil || DraftPlaybook.draftClass(for: b.name) == roleFilter)
            && (!eligibleOnly || eligibleIDs.contains(b.id))
            && (q.isEmpty || b.name.lowercased().contains(q))
        }
        if !q.isEmpty {
            list.sort { a, b in
                let ap = a.name.lowercased().hasPrefix(q), bp = b.name.lowercased().hasPrefix(q)
                if ap != bp { return ap }
                return a.name < b.name
            }
        }
        return list
    }

    private func brawlerStrip(suggested: Set<Int>, tint: Color) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHGrid(rows: [GridItem(.fixed(96), spacing: 12), GridItem(.fixed(96), spacing: 12)], spacing: 12) {
                ForEach(filteredRoster) { b in tile(for: b, suggested: suggested, tint: tint).frame(width: 136) }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(height: 232)
    }

    @ViewBuilder
    private func tile(for b: TierBrawler, suggested: Set<Int>, tint: Color) -> some View {
        let id = b.id
        let banned = session.bannedIDs.contains(id)
        let pickedSeat = session.seatPicks.first(where: { $0.value == id })?.key
        let team: DraftTile.Team = pickedSeat.map { session.isAllySeat($0) ? .blue : .red } ?? .none
        let disabled = session.phase == .picks && (banned || pickedSeat != nil)
        DraftTile(name: b.name, banned: banned, team: team,
                  isMine: pickedSeat == session.mySeat,
                  suggested: suggested.contains(id),
                  suggestTint: tint,
                  eligible: eligibleIDs.contains(id),
                  disabled: disabled) { handleTap(id) }
    }

    private func handleTap(_ id: Int) {
        switch session.phase {
        case .bans:
            guard let seat = session.activeBanSeat else { return }
            if seat == session.mySeat { session.banSuggestionSnapshot = suggestions.map { $0.brawler.name } }
            session.seatBans[seat] = id
            session.history.append(DraftHistoryEntry(isBan: true, seat: seat))
            session.advanceBan()
        case .picks:
            if session.bannedIDs.contains(id) || session.pickedIDs.contains(id) { return }
            guard let seat = session.currentPickSeat else { return }
            if seat == session.mySeat {
                session.pickSuggestionSnapshot = suggestions.map { $0.brawler.name }
                session.myPickWasSuggested = suggestedIDs.contains(id)
            }
            session.seatPicks[seat] = id
            session.history.append(DraftHistoryEntry(isBan: false, seat: seat))
            if session.currentPickSeat == nil { session.phase = .summary }
        default: return
        }
        search = ""
        searchFocused = true
    }

    // MARK: Win chance

    private var winEstimate: WinEstimate {
        let meta = DraftPlaybook.meta(forMode: session.mode ?? "")
        func picks(_ seats: [Int], mine: Bool) -> [WinProbability.Pick] {
            seats.compactMap { seat -> WinProbability.Pick? in
                guard let id = session.seatPicks[seat] else { return nil }
                let name = nameFor(id)
                let personal = (mine && seat == session.mySeat)
                    ? learning.stat(brawler: name, mode: session.mode ?? "", map: session.map?.name)?.rate : nil
                return WinProbability.Pick(cls: DraftPlaybook.draftClass(for: name), tier: tierScore(id), personal: personal)
            }
        }
        return WinProbability.estimate(meta: meta,
                                       mine: picks(DraftSession.myTeamSeats, mine: true),
                                       enemy: picks(DraftSession.enemySeats, mine: false),
                                       wonToss: session.wonToss ?? true,
                                       baseline: learning.baseline(mode: session.mode ?? "", map: session.map?.name),
                                       loggedMatches: matchLog.completed.count,
                                       calibration: matchLog.calibration.map { ($0.bias, $0.samples) })
    }

    private var winChanceBadge: some View {
        let est = winEstimate
        let pct = Int((est.probability * 100).rounded())
        let tint: Color = est.probability >= 0.55 ? .green : est.probability <= 0.45 ? .red : .yellow
        return HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(tint)
            Text("Win chance").font(.caption).foregroundStyle(.secondary)
            Text("\(pct)%").font(.headline.monospacedDigit()).foregroundStyle(tint)
            if est.confidence < 0.999 {
                Image(systemName: "questionmark.circle").font(.caption2).foregroundStyle(.secondary)
                    .help("Low confidence: held near even until more matches are logged")
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .help(est.factors.isEmpty ? "Based on role fit, tier and your history" : est.factors.joined(separator: "\n"))
    }

    // MARK: Comp checklist

    private var checklist: DraftChecklistResult {
        let own = DraftSession.myTeamSeats.map {
            DraftChecklist.OwnPick(seat: $0, globalPick: session.globalPick($0),
                                   brawler: session.seatPicks[$0].map { nameFor($0) })
        }
        return DraftChecklist.build(mode: session.mode ?? "", own: own,
                                    enemyClasses: classes(for: DraftSession.enemySeats))
    }

    private var checklistCard: some View {
        let c = checklist
        return HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("COMP CHECKLIST — \(c.meta.rawValue.uppercased())")
                    .font(.caption.weight(.bold)).foregroundStyle(.yellow)
                ForEach(c.items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: item.status == .done ? "checkmark.circle.fill"
                                          : item.status == .pending ? "circle" : "exclamationmark.circle.fill")
                            .foregroundStyle(item.status == .done ? .green : item.status == .pending ? .blue : .orange)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.role).font(.callout.weight(.semibold))
                                    .foregroundStyle(item.status == .done ? .secondary : .primary)
                                    .strikethrough(item.status == .done)
                                if let f = item.filledBy {
                                    Text("— \(f.brawler.capitalized) (\(f.seat == session.mySeat ? "you" : "seat \(f.seat + 1)"))")
                                        .font(.callout).foregroundStyle(.secondary)
                                } else if let seat = item.assignedSeat {
                                    Text("→ \(seat == session.mySeat ? "YOU" : "seat \(seat + 1)") (pick \(session.globalPick(seat)))")
                                        .font(.callout.weight(.semibold)).foregroundStyle(.blue)
                                } else if item.status == .unfillable {
                                    Text("no seats left").font(.callout).foregroundStyle(.orange)
                                }
                            }
                            Text(item.why).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if !c.warnings.isEmpty {
                    Text("WATCH").font(.caption.weight(.bold)).foregroundStyle(.orange)
                    ForEach(c.warnings, id: \.self) { w in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                            Text(w).font(.caption).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("BEST PRACTICE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                ForEach(c.practices, id: \.self) { p in
                    Text("• " + p).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Player row + ban columns

    private var playerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(DraftSession.myTeamSeats, id: \.self) { seatCell($0) }
            Text("VS").font(.headline).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.top, 22)
            ForEach(DraftSession.enemySeats, id: \.self) { seatCell($0) }
        }
        .frame(maxWidth: .infinity)
    }

    private func banColumn(seats: [Int], title: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            ForEach(seats, id: \.self) { seat in
                ZStack {
                    if let id = session.seatBans[seat] {
                        MiniBrawler(name: nameFor(id), size: 66)
                        RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4)).frame(width: 66, height: 54)
                        Image(systemName: "nosign").font(.title2).foregroundStyle(.red)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.2)).frame(width: 66, height: 54)
                    }
                }
                .help(session.seatBans[seat].map { "Banned by seat \(seat + 1): \(nameFor($0).capitalized)" } ?? "No ban")
            }
        }
        .frame(width: 82)
    }

    private func seatCell(_ seat: Int) -> some View {
        let isMy = seat == session.mySeat
        let ally = session.isAllySeat(seat)
        let banId = session.seatBans[seat]
        let pickId = session.seatPicks[seat]
        let active = (session.phase == .bans && session.activeBanSeat == seat)
                  || (session.phase == .picks && session.currentPickSeat == seat)
        let showId = session.phase == .bans ? banId : pickId
        let hasSel = showId != nil

        return VStack(spacing: 6) {
            Text(isMy ? "YOU" : "Pick \(session.globalPick(seat))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isMy ? .blue : ally ? .blue.opacity(0.7) : .red.opacity(0.8))
            ZStack {
                if let showId {
                    MiniBrawler(name: nameFor(showId), size: 92)
                    if session.phase == .bans {
                        RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.4)).frame(width: 92, height: 75)
                        Image(systemName: "nosign").font(.title).foregroundStyle(.red)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.22)).frame(width: 92, height: 75)
                        .overlay(Image(systemName: session.phase == .bans ? "nosign" : "questionmark")
                            .font(.title2).foregroundStyle(.secondary))
                }
                if active {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.yellow, lineWidth: 3.5).frame(width: 95, height: 78)
                }
                if hasSel {
                    Image(systemName: "xmark.circle.fill").font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.6)).offset(x: 43, y: -34)
                }
            }
            Text(isMy ? "you" : "seat \(seat + 1)").font(.system(size: 11)).foregroundStyle(.secondary)

            if let sa = seatAdvice(seat) {
                VStack(spacing: 7) {
                    Text(sa.role)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(sa.color)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.6)
                    ForEach(sa.suggestions) { s in
                        MiniBrawler(name: s.brawler.name, size: 68)
                            .help("\(s.brawler.name.capitalized) — \(s.reason)")
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(width: seatWidth)
        .contentShape(Rectangle())
        .onTapGesture { seatTapped(seat) }
    }

    /// Wider while teammate suggestion columns are on screen.
    private var seatWidth: CGFloat {
        session.phase == .picks && DraftSession.myTeamSeats.contains(where: { seatAdvice($0) != nil })
            ? 118 : 100
    }

    private func seatTapped(_ seat: Int) {
        switch session.phase {
        case .bans:
            if session.activeBanSeat == seat && session.seatBans[seat] != nil { session.seatBans[seat] = nil }
            else { session.activeBanSeat = seat }
        case .picks:
            if session.seatPicks[seat] != nil { session.seatPicks[seat] = nil }
        default: break
        }
        searchFocused = true
    }

    // MARK: Data helpers

    private var roster: [TierBrawler] {
        store.reference.values.map { TierBrawler(id: $0.id, name: $0.name) }
            .filter { !rankedSettings.isHidden($0.name) }
            .sorted { $0.name < $1.name }
    }
    private var rosterByID: [Int: TierBrawler] { Dictionary(roster.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }
    private func nameFor(_ id: Int) -> String { rosterByID[id]?.name ?? "#\(id)" }

    private var eligibleIDs: Set<Int> { Set((store.player?.brawlers ?? []).filter(\.isRankedEligible).map(\.id)) }

    private func tierScore(_ id: Int) -> Int {
        switch tierList.tierLabel(of: id) {
        case "S": return 5; case "A": return 4; case "B": return 3; case "C": return 2; case "D": return 1; default: return 0
        }
    }

    private func baseContext() -> DraftContext {
        DraftContext(mode: session.mode ?? "", roster: roster, tierScore: tierScore,
                     tierLabel: { tierList.tierLabel(of: $0) }, eligibleIDs: eligibleIDs,
                     banned: session.bannedIDs, picked: session.pickedIDs,
                     myTeamClasses: classes(for: DraftSession.myTeamSeats),
                     enemyClasses: classes(for: DraftSession.enemySeats),
                     enemyNames: DraftSession.enemySeats.compactMap { session.seatPicks[$0] }.map { nameFor($0) },
                     personal: { [learning, mode = session.mode ?? "", map = session.map?.name] id in
                         learning.stat(brawler: self.nameFor(id), mode: mode, map: map) },
                     threat: { [learning] id in learning.threat(enemy: self.nameFor(id)) },
                     observed: { [learning, mode = session.mode ?? "", map = session.map?.name] id in
                         learning.observedRate(brawler: self.nameFor(id), mode: mode, map: map) },
                     myGlobalPick: session.mySeat.map { session.globalPick($0) })
    }

    private func classes(for seats: [Int]) -> [DraftClass] {
        seats.compactMap { session.seatPicks[$0] }.map { DraftPlaybook.draftClass(for: nameFor($0)) }
    }

    private func mapsForMode(_ modeID: Int) -> [GameMap] { mapData.rotationMaps.filter { $0.gameMode?.id == modeID } }

    private func saveMatch() {
        let myOrder = DraftSession.myTeamSeats.sorted { session.globalPick($0) < session.globalPick($1) }
        let enemyOrder = DraftSession.enemySeats.sorted { session.globalPick($0) < session.globalPick($1) }
        let myNames: [String] = myOrder.compactMap { session.seatPicks[$0] }.map { nameFor($0) }
        let enemyNames: [String] = enemyOrder.compactMap { session.seatPicks[$0] }.map { nameFor($0) }
        let banNames: [String] = (0...5).compactMap { session.seatBans[$0] }.map { nameFor($0) }
        let picks: [DraftPickRecord] = (0...5)
            .sorted { session.globalPick($0) < session.globalPick($1) }
            .compactMap { seat -> DraftPickRecord? in
                guard let id = session.seatPicks[seat] else { return nil }
                return DraftPickRecord(globalPick: session.globalPick(seat), seat: seat, brawler: nameFor(id),
                                       isMine: seat == session.mySeat, isAlly: session.isAllySeat(seat))
            }
        let myBrawler: String? = session.mySeat.flatMap { session.seatPicks[$0] }.map { nameFor($0) }
        let myBan: String? = session.mySeat.flatMap { session.seatBans[$0] }.map { nameFor($0) }

        var record = MatchRecord(
            id: UUID(), date: Date(), mode: session.mode ?? "", mapName: session.map?.name ?? "",
            myTeam: myNames, enemyTeam: enemyNames, bans: banNames,
            series: session.series, wonToss: session.wonToss ?? true,
            mySlot: session.globalPick(session.mySeat ?? 0))
        record.winChance = winEstimate.probability
        record.incomplete = session.incomplete ? true : nil
        record.myBrawler = myBrawler
        record.picksInOrder = picks
        record.mySuggestions = session.pickSuggestionSnapshot
        record.myPickWasSuggested = session.myPickWasSuggested
        record.banSuggestions = session.banSuggestionSnapshot
        record.myBan = myBan
        record.notes = session.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.noteTags = session.noteTags.map(\.rawValue)
        matchLog.add(record)
        onExit()
    }

    private func bigChoice(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(color)
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Recommendation tile

struct RecTile: View {
    let suggestion: DraftSuggestion
    var tint: Color = .yellow
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .top, spacing: 8) {
                MiniBrawler(name: suggestion.brawler.name, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(suggestion.brawler.name.capitalized).font(.callout.weight(.bold))
                        Tag(text: suggestion.draftClass.rawValue, color: suggestion.draftClass.color)
                    }
                    Text(suggestion.reason).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Text("\(suggestion.score)").font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(tint)
            }
            .padding(8)
            .frame(width: 260, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.6), lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.8 : 1)
        .help(suggestion.components.map { "\($0.label): \($0.value >= 0 ? "+" : "")\($0.value)" }.joined(separator: "\n")
              + "\n= \(suggestion.score)")
    }
}

// MARK: - Tile

struct DraftTile: View {
    enum Team { case none, blue, red }

    let name: String
    let banned: Bool
    let team: Team
    let isMine: Bool
    let suggested: Bool
    var suggestTint: Color = .yellow
    let eligible: Bool
    let disabled: Bool
    let onTap: () -> Void

    private var picked: Bool { team != .none }
    private var borderColor: Color {
        if banned { return .red }
        switch team {
        case .blue: return .blue
        case .red: return .red
        case .none: return suggested ? suggestTint : .white.opacity(0.08)
        }
    }
    private var borderWidth: CGFloat { (suggested && team == .none && !banned) || picked || banned ? 2.5 : 1 }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                ZStack {
                    BrawlerRarityTable.rarity(for: name).color
                    if let img = BrawlerArt.image(named: name) {
                        Image(nsImage: img).resizable().interpolation(.high).scaledToFill()
                    } else {
                        Text(BrawlerArt.initials(name)).font(.headline.weight(.heavy)).foregroundStyle(.white)
                    }
                }
                .frame(height: 92).frame(maxWidth: .infinity).clipped()

                Text(name.uppercased()).font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity).padding(.vertical, 3).background(.black.opacity(0.55))

                if banned {
                    Color.black.opacity(0.55)
                    VStack(spacing: 2) {
                        Image(systemName: "nosign").font(.title).foregroundStyle(.red)
                        Text("BANNED").font(.system(size: 10, weight: .black)).foregroundStyle(.red)
                    }
                } else if picked {
                    Color.black.opacity(0.5)
                    Text(isMine ? "YOU" : "PICKED").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((team == .blue ? Color.blue : Color.red), in: Capsule())
                }
            }
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(borderColor, lineWidth: borderWidth))
            .overlay(alignment: .topTrailing) {
                if eligible && !banned && !picked {
                    Circle().fill(.green).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1)).padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Reusable

struct MiniBrawler: View {
    let name: String
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            BrawlerRarityTable.rarity(for: name).color
            if let img = BrawlerArt.image(named: name) {
                Image(nsImage: img).resizable().interpolation(.high).scaledToFill()
            } else {
                Text(BrawlerArt.initials(name)).font(.system(size: size * 0.34, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size * 0.82)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct MapPickButton: View {
    let map: GameMap
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                MapImage(url: map.imageUrl).frame(height: 90).frame(maxWidth: .infinity).clipped()
                Text(map.name).font(.callout.weight(.semibold)).lineLimit(1)
                    .padding(.vertical, 6).frame(maxWidth: .infinity).background(.background.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    static var coralish: Color { Color(red: 0.85, green: 0.35, blue: 0.35) }
    static var blueish: Color { Color(red: 0.35, green: 0.45, blue: 0.85) }
}
