import SwiftUI

/// The draft model, explained with live numbers — and every one of them editable.
struct DraftModelView: View {
    @Environment(DraftConfigStore.self) private var configStore
    @Environment(PlayerStore.self) private var store
    @Environment(BattleArchiveStore.self) private var archive
    @Environment(MatchLogStore.self) private var matchLog
    @Environment(\.dismiss) private var dismiss

    @State private var section: Section = .overview
    @State private var classSearch = ""

    enum Section: String, CaseIterable, Identifiable {
        case overview = "How it works", picks = "Pick scoring", bans = "Ban scoring", learning = "Learning",
             winChance = "Win chance", playbook = "Playbook rules", classes = "Brawler classes"
        var id: String { rawValue }
    }

    var body: some View {
        @Bindable var cfg = configStore
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3").foregroundStyle(.yellow)
                Text("Draft Model").font(.title3.weight(.bold))
                Text("every rule and weight the assistant uses").font(.callout).foregroundStyle(.secondary)
                Spacer()
                if !configStore.isDefault {
                    Button("Reset all to defaults", role: .destructive) { configStore.resetAll() }
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                Button("") { dismiss() }.keyboardShortcut(.cancelAction).hidden().frame(width: 0, height: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.background.secondary)
            Divider()
            splitContent
        }
        .frame(minWidth: 980, minHeight: 680)
    }

    private var splitContent: some View {
        @Bindable var cfg = configStore
        return NavigationSplitView {
            List(Section.allCases, selection: Binding(get: { Optional(section) }, set: { if let s = $0 { section = s } })) {
                Text($0.rawValue).tag($0)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch section {
                    case .overview: overview
                    case .picks: pickWeights($cfg)
                    case .bans: banWeights($cfg)
                    case .learning: learningWeights($cfg)
                    case .winChance: winChanceWeights($cfg)
                    case .playbook: playbookRules
                    case .classes: classEditor
                    }
                }
                .padding(22)
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Overview (the in-depth explanation with live numbers)

    private var w: DraftWeights { configStore.config.weights }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How suggestions are made").font(.title2.weight(.bold))
            Text("Everything below is computed from four inputs you control: the **playbook rules** (roles per meta and per pick slot), your **tier list**, your **Ranked-Eligible** roster, and your **own results** (archived battles + logged ranked series). No hidden data; every number shown here is the live value and is editable in the other sections.")
            step(1, "Classify the situation",
                 "The map's mode becomes a meta — Aggro (Brawl Ball, Gem Grab, Hot Zone, Heist) or Passive (Bounty, Knockout) — and your global pick number becomes a slot: 1st, 2–3, 4–5 or Last. Each meta has a dominant-class order (most valuable role first) and each slot has target classes. Every brawler has one of seven draft classes.")
            step(2, "Ban suggestions — deny the strongest role picks",
                 "score = role rank × \(fmt(w.banRole))  +  tier × \(fmt(w.banTier))  +  \(fmt(w.banCallout)) if the playbook names it for this mode  +  up to \(fmt(w.banThreatMax)) if you historically lose to it. Role rank is 7 for the meta's top class down to 1, so role dominates tier by design (an S-tier support scores less than a C-tier anti-tank in an aggro mode). A brawler that's also one of your own top 3 picks loses \(fmt(w.banOwnPickPenalty)) — the engine won't tell you to deny yourself.")
            step(3, "Pick suggestions — role for the slot, then eligibility, then tier",
                 "Only your Ranked-Eligible brawlers are considered (ineligible ones appear only if nothing eligible is left, at −\(fmt(w.pickIneligiblePenalty))). score = \(fmt(w.pickRoleMatch)) if the class is a target for this slot (otherwise role rank × \(fmt(w.pickOffRolePerWeight)))  +  tier × \(fmt(w.pickTier))  +  \(fmt(w.pickEligibleBonus)) eligible  +  \(fmt(w.pickCallout)) playbook pick  −  \(fmt(w.pickStackOne)) if your team already has one of that class  −  \(fmt(w.pickStackTwo)) if it has two  ±  up to \(fmt(w.pickPersonalMax)) from your own win rate.")
            step(4, "Matchups and the comp you already have",
                 "Every candidate is checked against the enemy picks on the board using the class matchup table: +\(fmt(w.pickCounterBonus)) for each enemy brawler its class beats, −\(fmt(w.pickCounteredPenalty)) for each enemy brawler that beats it — so it steers you away from walking into a counter. On your own side, the meta's top role (anti-tank in aggro, control in passive) is never optional: if the comp still lacks it, it leads the targets regardless of the slot. If everything the slot wants is already covered by teammates, the engine swaps to whatever the comp is missing. The live checklist under the seats shows the same logic: it grades the comp you have in any order, and points each unmet role at the next seat to pick.")
            step(5, "Counter slots read the enemy comp",
                 "When a slot has no fixed target (Last, and 4–5 in passive), the engine looks at what the enemy is missing: no anti-tank → tank / space maker; no space maker → thrower / sniper / control; two+ ranged → space maker; and it insists on an anti-tank for your side in aggro if you still lack one.")
            step(6, "Learning from your games",
                 "Each archived battle and each logged ranked game is a data point for (brawler, mode, map) with a recency weight of 0.5^(age ÷ \(fmt(w.halfLifeDays)) days); ranked games count ×\(fmt(w.rankedGameWeight)). Win rates are smoothed as (wins + \(fmt(w.smoothPseudoWins))) ÷ (games + \(fmt(w.smoothPseudoGames))) and only used after \(fmt(w.minGames)) games. The most specific stat wins: this map → this mode → overall. Enemy brawlers you lose to become ban threats. Nothing is stored as a trained model — it's rebuilt from raw games every time, so a new season, pool or tier list needs no reset; recent games simply dominate.")
            step(7, "Win chance",
                 "Each pick contributes \(fmt(w.wpTier)) × tier/5 + \(fmt(w.wpRole)) × role fit (+ \(fmt(w.wpPersonal)) × your personal edge for your own brawler). Team bonuses: +\(fmt(w.wpAntiTankBonus)) anti-tank in aggro, +\(fmt(w.wpAntiTankSpaceMakerBonus)) anti-tank + space maker, +\(fmt(w.wpPassiveRangeBonus)) control/sniper in passive; −\(fmt(w.wpStackPenalty)) for three of a class, −\(fmt(w.wpNoAntiTankPenalty)) for no anti-tank in aggro. The difference between teams goes through a sigmoid (k = \(fmt(w.wpSigmoidK))), blended with your historical baseline on that mode/map (the draft counts \(Int(w.wpBaseDraftWeight * 100))% before any picks, 100% after all six), ±\(fmt(w.wpTossEdge)) for the coin toss, clamped 5–95%.")
            Text("Tip: hover any recommendation card in a draft to see its exact score breakdown.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func step(_ n: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline.monospacedDigit()).foregroundStyle(.yellow).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(.init(body)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v) }

    // MARK: - Weight editors

    private func pickWeights(_ cfg: Bindable<DraftConfigStore>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Pick scoring", "Applied on your turn. Higher = more influence. Role match should stay far above tier so the playbook's structure wins.") {
                configStore.config.weights = {
                    var d = DraftWeights(); let c = configStore.config.weights
                    d.banRole = c.banRole; d.banTier = c.banTier; d.banCallout = c.banCallout; d.banThreatMax = c.banThreatMax
                    d.banOwnPickPenalty = c.banOwnPickPenalty; d.unknownRoleWeight = c.unknownRoleWeight
                    d.wpCalibrationStrength = c.wpCalibrationStrength; d.wpCalibrationMinMatches = c.wpCalibrationMinMatches
                    d.threatConfidenceGames = c.threatConfidenceGames; d.halfLifeDays = c.halfLifeDays; d.rankedGameWeight = c.rankedGameWeight
                    d.smoothPseudoWins = c.smoothPseudoWins; d.smoothPseudoGames = c.smoothPseudoGames; d.minGames = c.minGames
                    d.wpTier = c.wpTier; d.wpRole = c.wpRole; d.wpPersonal = c.wpPersonal; d.wpSigmoidK = c.wpSigmoidK; d.wpTossEdge = c.wpTossEdge
                    d.wpAntiTankBonus = c.wpAntiTankBonus; d.wpAntiTankSpaceMakerBonus = c.wpAntiTankSpaceMakerBonus; d.wpPassiveRangeBonus = c.wpPassiveRangeBonus
                    d.wpStackPenalty = c.wpStackPenalty; d.wpNoAntiTankPenalty = c.wpNoAntiTankPenalty; d.wpBaseDraftWeight = c.wpBaseDraftWeight; d.wpBaselineConfidenceGames = c.wpBaselineConfidenceGames
                    return d
                }()
            }
            WeightRow("Role match", "Class is a target for this slot", cfg.config.weights.pickRoleMatch, 0...3000)
            WeightRow("Off-role per rank", "× dominant-class rank (7…1) when not a target", cfg.config.weights.pickOffRolePerWeight, 0...300)
            WeightRow("Tier", "× tier score (S=5 … D=1)", cfg.config.weights.pickTier, 0...500)
            WeightRow("Eligible bonus", "Ranked-Eligible brawler", cfg.config.weights.pickEligibleBonus, 0...2000)
            WeightRow("Ineligible penalty", "Subtracted when not eligible", cfg.config.weights.pickIneligiblePenalty, 0...10000)
            WeightRow("Playbook callout", "Named for this mode in the playbook", cfg.config.weights.pickCallout, 0...1000)
            WeightRow("Stack: one already", "Team has one of this class", cfg.config.weights.pickStackOne, 0...2000)
            WeightRow("Stack: two already", "Would be the third", cfg.config.weights.pickStackTwo, 0...10000)
            WeightRow("Counters an enemy pick", "Per enemy brawler this class beats", cfg.config.weights.pickCounterBonus, 0...800)
            WeightRow("Countered by an enemy pick", "Per enemy brawler whose class beats this one", cfg.config.weights.pickCounteredPenalty, 0...1200)
            WeightRow("Your results (max ±)", "Cap from your personal win rate", cfg.config.weights.pickPersonalMax, 0...1500)
            WeightRow("Personal confidence games", "Games for full personal weight", cfg.config.weights.personalConfidenceGames, 1...30)
        }
    }

    private func banWeights(_ cfg: Bindable<DraftConfigStore>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Ban scoring", "Which brawlers to deny. Role rank (7…1 for this meta) × role weight is the backbone.") { configStore.resetWeights() }
            WeightRow("Role", "× dominant-class rank", cfg.config.weights.banRole, 0...3000)
            WeightRow("Tier", "× tier score", cfg.config.weights.banTier, 0...500)
            WeightRow("Playbook must-ban", "Named for this mode", cfg.config.weights.banCallout, 0...1000)
            WeightRow("Threat (max +)", "Brawlers you historically lose to", cfg.config.weights.banThreatMax, 0...1500)
            WeightRow("Threat confidence games", "Games for full threat weight", cfg.config.weights.threatConfidenceGames, 1...30)
            WeightRow("Don't-ban-my-pick veto", "Pushed down if it's also one of your top 3 picks", cfg.config.weights.banOwnPickPenalty, 0...15000)
            WeightRow("Unclassified role rank", "Role rank used for brawlers with no draft class", cfg.config.weights.unknownRoleWeight, 0...7)
        }
    }

    private func learningWeights(_ cfg: Bindable<DraftConfigStore>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Learning", "How your battles and logged series turn into stats. Shorter half-life = follows the meta faster but noisier.") { configStore.resetWeights() }
            WeightRow("Half-life (days)", "A game this old counts half", cfg.config.weights.halfLifeDays, 7...365)
            WeightRow("Ranked game weight", "Logged ranked games vs regular battles", cfg.config.weights.rankedGameWeight, 0.5...4, step: 0.1)
            WeightRow("Prior wins", "Bayesian smoothing: (wins + this)", cfg.config.weights.smoothPseudoWins, 0...10, step: 0.5)
            WeightRow("Prior games", "… ÷ (games + this)", cfg.config.weights.smoothPseudoGames, 1...20, step: 0.5)
            WeightRow("Minimum games", "Before a personal stat is used at all", cfg.config.weights.minGames, 1...20)
            WeightRow("Observed record (max ±)", "Used when you have no personal history with a brawler", cfg.config.weights.pickObservedMax, 0...1000)
            WeightRow("Observed confidence games", "Games for full observed weight", cfg.config.weights.observedConfidenceGames, 1...40)
            coveragePanel
        }
    }

    /// Shows how balanced the collected data actually is.
    private var coveragePanel: some View {
        let cov = DraftLearning(archive: archive.records, matches: matchLog.matches).coverage()
        return VStack(alignment: .leading, spacing: 8) {
            Text("DATA BALANCE").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text("Every brawler in every archived game is recorded from its own side's result, so opponents and teammates build records too — not just the brawlers you play.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                DetailStat(title: "Brawlers seen", value: "\(cov.brawlersSeen)", symbol: "person.3.fill", tint: .blue)
                DetailStat(title: "Enough data", value: "\(cov.withEnoughData)", symbol: "checkmark.seal.fill", tint: .green)
                DetailStat(title: "Your games", value: String(Int(cov.yourGames.rounded())), symbol: "person.fill", tint: .yellow)
                DetailStat(title: "All appearances", value: String(Int(cov.observedGames.rounded())), symbol: "chart.bar.fill", tint: .purple)
            }
            if !cov.topYours.isEmpty {
                Text("Most games by you: " + cov.topYours.map { "\($0.0.capitalized) \(Int($0.1.rounded()))" }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if archive.records.contains(where: { $0.opponents == nil }) {
                Text("Battles archived before this update kept no team list, so their opponents can't be counted. New fetches include them.")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(12).background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func winChanceWeights(_ cfg: Bindable<DraftConfigStore>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Win chance", "The live probability shown during the draft. Per-pick weights should roughly sum to 1.") { configStore.resetWeights() }
            WeightRow("Tier weight", "× tier/5 per pick", cfg.config.weights.wpTier, 0...1, step: 0.05)
            WeightRow("Role weight", "× role fit per pick", cfg.config.weights.wpRole, 0...1, step: 0.05)
            WeightRow("Personal weight", "× your edge, your brawler only", cfg.config.weights.wpPersonal, 0...1, step: 0.05)
            WeightRow("Anti-tank bonus (aggro)", "", cfg.config.weights.wpAntiTankBonus, 0...0.5, step: 0.01)
            WeightRow("Anti-tank + space maker", "", cfg.config.weights.wpAntiTankSpaceMakerBonus, 0...0.5, step: 0.01)
            WeightRow("Control/sniper bonus (passive)", "", cfg.config.weights.wpPassiveRangeBonus, 0...0.5, step: 0.01)
            WeightRow("Stack penalty", "Three of one class", cfg.config.weights.wpStackPenalty, 0...1, step: 0.05)
            WeightRow("No anti-tank penalty (aggro)", "", cfg.config.weights.wpNoAntiTankPenalty, 0...0.5, step: 0.01)
            WeightRow("Sigmoid steepness (k)", "Higher = more decisive", cfg.config.weights.wpSigmoidK, 0.5...6, step: 0.1)
            WeightRow("Coin-toss edge", "± for first pick", cfg.config.weights.wpTossEdge, 0...0.1, step: 0.005)
            WeightRow("Draft weight before picks", "Rest comes from your baseline", cfg.config.weights.wpBaseDraftWeight, 0...1, step: 0.05)
            WeightRow("Baseline confidence games", "", cfg.config.weights.wpBaselineConfidenceGames, 1...50)
            WeightRow("Self-correction strength", "How much of the measured bias to remove (1 = all of it)",
                      cfg.config.weights.wpCalibrationStrength, 0...1, step: 0.05)
            WeightRow("Self-correction ramp", "Completed matches before correcting at full strength",
                      cfg.config.weights.wpCalibrationMinMatches, 5...60)
            calibrationReadout
        }
    }

    /// Live scoreboard for the win-chance model, measured on completed matches.
    @ViewBuilder
    private var calibrationReadout: some View {
        if let cal = matchLog.calibration {
            let pts = Int((abs(cal.bias) * 100).rounded())
            VStack(alignment: .leading, spacing: 6) {
                Text("HOW IT'S ACTUALLY DOING").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(cal.bias > 0
                     ? "Running hot by \(pts) point\(pts == 1 ? "" : "s") over \(cal.samples) completed matches — every estimate is now pulled down to compensate."
                     : "Running cold by \(pts) point\(pts == 1 ? "" : "s") over \(cal.samples) completed matches — every estimate is now nudged up to compensate.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Text(String(format: "Brier score %.3f — %@ than calling every match a coin flip (0.250). Lower is better.",
                            cal.brier, cal.brier < 0.25 ? "better" : "worse"))
                    .font(.caption).foregroundStyle(cal.brier < 0.25 ? .green : .orange)
                if matchLog.incompleteCount > 0 {
                    Text("\(matchLog.incompleteCount) match\(matchLog.incompleteCount == 1 ? "" : "es") marked cut short and excluded here — the games played still count toward every brawler's record.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func header(_ title: String, _ subtitle: String, reset: @escaping () -> Void) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.weight(.bold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset section") { reset() }
        }
    }

    // MARK: - Playbook rules

    private var playbookRules: some View {
        let pb = configStore.config.playbook
        let modes = Array(Set(pb.modeMeta.keys).union(["brawlball", "gemgrab", "hotzone", "heist", "bounty", "knockout"])).sorted()
        return VStack(alignment: .leading, spacing: 16) {
            header("Playbook rules", "The structural rules: which meta each mode is, the role order per meta, target roles per slot, and mode callouts.") { configStore.resetPlaybook() }

            Text("MODE → META").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            ForEach(modes, id: \.self) { mode in
                HStack {
                    Text(prettyMode(mode)).frame(width: 140, alignment: .leading)
                    Picker("", selection: Binding(get: { DraftPlaybook.meta(forMode: mode) },
                                                  set: { configStore.setMeta(mode, $0) })) {
                        Text("Aggro").tag(DraftMeta.aggro); Text("Passive").tag(DraftMeta.passive)
                    }
                    .labelsHidden().frame(width: 140)
                    Spacer()
                    TextField("Callouts (comma-separated)", text: Binding(
                        get: { (pb.callouts[mode] ?? []).joined(separator: ", ") },
                        set: { configStore.setCallouts(mode, $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }) }))
                    .textFieldStyle(.roundedBorder)
                }
            }

            ForEach([DraftMeta.aggro, .passive], id: \.self) { meta in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(meta.rawValue.uppercased()) — ROLE ORDER (most valuable first)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    let order = DraftPlaybook.dominantClasses(for: meta)
                    ForEach(Array(order.enumerated()), id: \.element) { i, cls in
                        HStack(spacing: 8) {
                            Text("\(order.count - i)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 18)
                            Tag(text: cls.rawValue, color: cls.color)
                            Spacer()
                            Button { configStore.moveDominant(meta: meta, from: i, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.plain).disabled(i == 0)
                            Button { configStore.moveDominant(meta: meta, from: i, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.plain).disabled(i == order.count - 1)
                        }
                    }
                    Text("\(meta.rawValue.uppercased()) — TARGET ROLES PER SLOT (empty = counter logic)").font(.caption.weight(.bold)).foregroundStyle(.secondary).padding(.top, 6)
                    ForEach(Array(["1st", "2–3", "4–5", "Last"].enumerated()), id: \.offset) { slot, label in
                        HStack(alignment: .top, spacing: 8) {
                            Text(label).font(.callout.weight(.semibold)).frame(width: 40, alignment: .leading)
                            FlowLayout(spacing: 6) {
                                ForEach(DraftClass.allCases.filter { $0 != .unknown }) { cls in
                                    let on = DraftPlaybook.targetClasses(meta: meta, slotIndex: slot).contains(cls)
                                    Button(cls.rawValue) { configStore.toggleTarget(meta: meta, slot: slot, cls: cls) }
                                        .buttonStyle(.bordered).tint(on ? cls.color : .secondary).controlSize(.small)
                                }
                            }
                        }
                    }
                }
                .padding(12).background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func prettyMode(_ key: String) -> String {
        ["brawlball": "Brawl Ball", "gemgrab": "Gem Grab", "hotzone": "Hot Zone", "heist": "Heist",
         "bounty": "Bounty", "knockout": "Knockout"][key] ?? key.capitalized
    }

    // MARK: - Brawler classes

    /// Brawlers the playbook has no class for — they'd otherwise be quietly
    /// under-scored in every draft with no sign anything was wrong.
    private var unclassified: [String] {
        store.reference.values.map(\.name).sorted()
            .filter { DraftPlaybook.draftClass(for: $0) == .unknown }
    }

    private var classEditor: some View {
        let names = store.reference.values.map(\.name).sorted()
        let q = classSearch.lowercased()
        let shown = names.filter { q.isEmpty || $0.lowercased().contains(q) }
        return VStack(alignment: .leading, spacing: 10) {
            header("Brawler classes", "Which draft class each brawler plays as. Overrides are marked; reset restores the playbook roster.") {
                configStore.config.playbook.classOverrides = [:]
            }
            if !unclassified.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(unclassified.count) brawler\(unclassified.count == 1 ? "" : "s") not classified yet",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold)).foregroundStyle(.orange)
                    Text("New brawlers arrive without a draft class. Until you set one they're scored on tier and your own results alone, so the engine under-rates them. Set a class to bring them fully into pick and ban advice.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ForEach(unclassified, id: \.self) { name in
                        HStack(spacing: 8) {
                            MiniBrawler(name: name, size: 30)
                            Text(name.capitalized).font(.callout)
                            Spacer()
                            Picker("", selection: Binding(get: { DraftPlaybook.draftClass(for: name) },
                                                          set: { configStore.setClassOverride(name, $0) })) {
                                ForEach(DraftClass.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .labelsHidden().frame(width: 130)
                        }
                    }
                }
                .padding(12)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.35)))
            }
            TextField("Search brawlers", text: $classSearch).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 8)], spacing: 8) {
                ForEach(shown, id: \.self) { name in
                    HStack(spacing: 8) {
                        MiniBrawler(name: name, size: 30)
                        Text(name.capitalized).font(.callout).lineLimit(1)
                        Spacer()
                        Picker("", selection: Binding(get: { DraftPlaybook.draftClass(for: name) },
                                                      set: { configStore.setClassOverride(name, $0) })) {
                            ForEach(DraftClass.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                        if configStore.config.playbook.classOverrides[BrawlerArt.normalize(name)] != nil {
                            Image(systemName: "pencil.circle.fill").foregroundStyle(.yellow).help("Overridden")
                        }
                    }
                    .padding(6).background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

/// Slider + numeric field for one weight.
struct WeightRow: View {
    let label: String
    let help: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    init(_ label: String, _ help: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, step: Double = 1) {
        self.label = label; self.help = help; self._value = value; self.range = range; self.step = step
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.callout.weight(.semibold))
                if !help.isEmpty { Text(help).font(.caption2).foregroundStyle(.secondary) }
            }
            .frame(width: 230, alignment: .leading)
            Slider(value: $value, in: range, step: step)
            TextField("", value: $value, format: .number.precision(.fractionLength(step < 1 ? 2 : 0)))
                .textFieldStyle(.roundedBorder).frame(width: 78).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}
