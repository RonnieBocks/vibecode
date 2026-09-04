import SwiftUI

/// Loading-screen briefing. One surface, one hierarchy, color only as accent.
struct GamePlanView: View {
    let plan: GamePlan
    var title: String = "GAME PLAN"

    private var tempoColor: Color { plan.meta == .aggro ? .coralish : plan.meta == .passive ? .blueish : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                you
                    .frame(width: 300, alignment: .topLeading)
                    .padding(18)
                Divider()
                matchups
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(18)
            }
            Divider()
            planRow
                .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Header — tempo, rule, mode, history

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary).kerning(1)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(plan.tempo)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(tempoColor)
                Text(plan.tempoLine).font(.title3.weight(.semibold))
                Spacer(minLength: 12)
                if let h = plan.history {
                    let good = plan.historyGood ?? true
                    HStack(spacing: 5) {
                        Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(h)
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(good ? .green : .orange)
                    .lineLimit(1).fixedSize()
                }
            }
            HStack(spacing: 6) {
                Text(plan.modeName).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                if let m = plan.modeLine {
                    Text("·").foregroundStyle(.secondary)
                    Text(m).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Left — you

    private var you: some View {
        HStack(alignment: .top, spacing: 14) {
            if let b = plan.myBrawler {
                MiniBrawler(name: b, size: 84)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("YOU").font(.caption2.weight(.bold)).foregroundStyle(.blue).kerning(1)
                Text(plan.myBrawler?.capitalized ?? "—").font(.title3.weight(.bold))
                Text(plan.myClass.rawValue.uppercased())
                    .font(.caption2.weight(.bold)).kerning(0.5)
                    .foregroundStyle(plan.myClass.color)
                    .lineLimit(1).fixedSize()
                Text(plan.job)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: Right — matchups (kill first / respect), grouped by class

    private var matchups: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Text("KILL FIRST").font(.caption2.weight(.bold)).foregroundStyle(.green).kerning(1)
                    .frame(width: 78, alignment: .leading).padding(.top, 2)
                if plan.targets.isEmpty {
                    Text("No soft targets — win through the team plan").font(.callout).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        ForEach(plan.targets, id: \.self) { portrait($0) }
                    }
                }
            }
            HStack(alignment: .top, spacing: 14) {
                Text("RESPECT").font(.caption2.weight(.bold)).foregroundStyle(.orange).kerning(1)
                    .frame(width: 78, alignment: .leading).padding(.top, 2)
                if plan.threats.isEmpty {
                    Text("Nothing on their side counters you").font(.callout).foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(threatGroups, id: \.tip) { group in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) { ForEach(group.names, id: \.self) { portrait($0) } }
                                Text(group.tip).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: CGFloat(group.names.count) * 66, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Threats that share a class (and therefore a counter-tip) are shown together.
    private var threatGroups: [(tip: String, names: [String])] {
        var order: [String] = [], map: [String: [String]] = [:]
        for t in plan.threats {
            if map[t.tip] == nil { order.append(t.tip) }
            map[t.tip, default: []].append(t.name)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    private func portrait(_ name: String) -> some View {
        VStack(spacing: 4) {
            MiniBrawler(name: name, size: 58)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15), lineWidth: 1))
            Text(name.capitalized).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(width: 58)
    }

    // MARK: Bottom — plan

    private var planRow: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(plan.plan.enumerated()), id: \.offset) { _, p in
                HStack(spacing: 6) {
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(tempoColor)
                    Text(p).font(.callout.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.12), in: Capsule())
            }
        }
    }
}
