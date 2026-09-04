import Foundation

struct WinEstimate {
    let probability: Double
    let factors: [String]
    /// 0…1 — how much the model trusts itself, from how many matches you've logged.
    var confidence: Double = 1
}

/// Live win-chance estimate for the draft. Transparent, heuristic model:
/// each pick contributes tier quality, playbook role fit for the meta, and
/// (for your own brawler) your personal win rate; team-level bonuses reward
/// role coverage and punish stacking; your historical baseline on this
/// mode/map anchors the number; first pick is a small edge.
enum WinProbability {
    struct Pick {
        let cls: DraftClass
        let tier: Int            // 0…5
        let personal: Double?    // smoothed personal win rate, my picks only
    }

    static func estimate(meta: DraftMeta, mine: [Pick], enemy: [Pick], wonToss: Bool,
                         baseline: (rate: Double, games: Double)?, loggedMatches: Int = 0,
                         calibration: (bias: Double, samples: Int)? = nil) -> WinEstimate {
        let w = DraftPlaybook.config.weights
        var factors: [String] = []

        func teamStrength(_ picks: [Pick], isMine: Bool) -> Double {
            let order = DraftPlaybook.dominantClasses(for: meta)
            var total = 0.0
            for p in picks {
                let roleFit = order.firstIndex(of: p.cls).map { Double(order.count - $0) / Double(order.count) } ?? 0.3
                var s = w.wpTier * (Double(p.tier) / 5.0) + w.wpRole * roleFit
                if isMine, let pr = p.personal { s += w.wpPersonal * ((pr - 0.5) * 2) }
                total += s
            }
            total += Double(3 - picks.count) * (w.wpTier + w.wpRole) * 0.5   // unpicked slots = neutral
            let classes = picks.map(\.cls)
            if meta == .aggro, classes.contains(.antiTank) { total += w.wpAntiTankBonus }
            if classes.contains(.antiTank), classes.contains(.spaceMaker) { total += w.wpAntiTankSpaceMakerBonus }
            if meta == .passive, classes.contains(.control) || classes.contains(.sniper) { total += w.wpPassiveRangeBonus }
            if let stacked = Dictionary(grouping: classes, by: { $0 }).values.first(where: { $0.count >= 3 }) {
                total -= w.wpStackPenalty; if isMine { factors.append("Three \(stacked[0].rawValue)s — stacked comp") }
            }
            if meta == .aggro, picks.count >= 2, !classes.contains(.antiTank) {
                total -= w.wpNoAntiTankPenalty; if isMine { factors.append("No anti-tank yet in an aggro mode") }
            }
            return total
        }

        let m = teamStrength(mine, isMine: true), e = teamStrength(enemy, isMine: false)
        let diff = m - e
        let draftP = 1 / (1 + exp(-w.wpSigmoidK * diff))

        var base = 0.5
        if let baseline {
            let conf = min(1, baseline.games / max(1, w.wpBaselineConfidenceGames))
            base = 0.5 + (baseline.rate - 0.5) * conf
            factors.append("Your history here: \(Int(baseline.rate * 100))% (\(Int(baseline.games.rounded()))g)")
        }
        let picksMade = mine.count + enemy.count
        let draftWeight = w.wpBaseDraftWeight + (1 - w.wpBaseDraftWeight) * (Double(picksMade) / 6.0)   // the draft matters more as it fills in
        var p = draftWeight * draftP + (1 - draftWeight) * base
        p += wonToss ? w.wpTossEdge : -w.wpTossEdge
        if diff > 0.15 { factors.append("Your comp is ahead on role fit / quality") }
        else if diff < -0.15 { factors.append("Enemy comp is ahead on role fit / quality") }
        if mine.contains(where: { ($0.personal ?? 0.5) >= 0.6 }) { factors.append("You're on a brawler you win with") }
        // Shrink toward 50% until enough matches exist to justify confidence,
        // then clamp. Without this the model turned role theory into 95% calls.
        let confidence = min(1, Double(loggedMatches) / max(1, w.wpShrinkMatches))
        p = 0.5 + (p - 0.5) * confidence
        // Remove the over/under-confidence measured on your own completed
        // matches, ramped in as the sample grows so a handful of games can't
        // swing it. This is what stops the model sitting at 58% while you win 50%.
        if let cal = calibration, cal.samples >= 5 {
            let ramp = min(1, Double(cal.samples) / max(1, w.wpCalibrationMinMatches))
            let correction = cal.bias * ramp * w.wpCalibrationStrength
            if abs(correction) >= 0.005 {
                p -= correction
                let pts = Int((abs(correction) * 100).rounded())
                factors.append("Calibrated \(correction > 0 ? "down" : "up") \(pts)pt\(pts == 1 ? "" : "s") — it has run \(correction > 0 ? "hot" : "cold") over your last \(cal.samples) matches")
            }
        }
        p = min(w.wpClampMax, max(w.wpClampMin, p))
        if confidence < 0.999 {
            factors.append("Held near even: only \(loggedMatches) logged match\(loggedMatches == 1 ? "" : "es") of \(Int(w.wpShrinkMatches)) for full confidence")
        }
        return WinEstimate(probability: p, factors: factors, confidence: confidence)
    }
}
