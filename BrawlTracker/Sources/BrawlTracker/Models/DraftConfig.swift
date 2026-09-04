import Foundation

/// Every tunable number the draft assistant uses. Decoding is
/// migration-tolerant: missing keys fall back to defaults, so adding a weight
/// never discards a saved config.
struct DraftWeights: Codable, Equatable {
    // Picks (your turn)
    var pickRoleMatch = 1000.0          // brawler's class is a target class for this slot
    var pickOffRolePerWeight = 40.0     // off-role: dominant-class weight (7…1) × this
    var pickTier = 100.0                // × tier score (S=5 … D=1, unranked 0)
    var pickEligibleBonus = 500.0       // Ranked-Eligible brawler
    var pickIneligiblePenalty = 5000.0  // not eligible (only shown if nothing eligible remains)
    var pickCallout = 150.0             // named in the playbook for this mode
    var pickStackOne = 350.0            // team already has one of this class
    var pickStackTwo = 3000.0           // team already has two (never stack a third)
    var pickPersonalMax = 700.0         // ± cap from your own win rate with the brawler
    var personalConfidenceGames = 6.0   // games needed for full personal weight
    var pickObservedMax = 200.0         // ± cap from the brawler's record in games you've seen
    var observedConfidenceGames = 10.0  // games needed for full observed weight
    var pickCounterBonus = 150.0        // per enemy pick this brawler's class beats
    var pickCounteredPenalty = 250.0    // per enemy pick whose class beats this brawler

    // Bans
    var banRole = 1000.0
    var banTier = 100.0
    var banCallout = 300.0
    var banThreatMax = 400.0
    var threatConfidenceGames = 6.0
    var banOwnPickPenalty = 8000.0      // don't ban a brawler you'd want to pick yourself.
                                        // Must clear the top role score (7 × banRole)
                                        // so the veto actually demotes rather than ties.
    var unknownRoleWeight = 2.0         // role rank for brawlers with no draft class yet

    // Learning
    var halfLifeDays = 60.0
    var rankedGameWeight = 1.5
    var smoothPseudoWins = 2.0
    var smoothPseudoGames = 4.0
    var minGames = 3.0

    // Win chance
    var wpTier = 0.40
    var wpRole = 0.40
    var wpPersonal = 0.20
    var wpSigmoidK = 1.2                // steepness; lower = less confident
    var wpTossEdge = 0.02
    var wpAntiTankBonus = 0.12
    var wpAntiTankSpaceMakerBonus = 0.10
    var wpPassiveRangeBonus = 0.08
    var wpStackPenalty = 0.25
    var wpNoAntiTankPenalty = 0.10
    var wpBaseDraftWeight = 0.35
    var wpBaselineConfidenceGames = 12.0
    var wpClampMin = 0.25               // never claim more certainty than this…
    var wpClampMax = 0.75               // …or this
    var wpShrinkMatches = 50.0          // logged matches for full confidence (shrinks to 50% below it)
    var wpCalibrationStrength = 1.0     // how much of the measured over/under-confidence to remove
    var wpCalibrationMinMatches = 15.0  // completed predictions needed before correcting at full strength

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DraftWeights()
        func v(_ k: CodingKeys, _ fallback: Double) -> Double {
            ((try? c.decodeIfPresent(Double.self, forKey: k)) ?? nil) ?? fallback
        }
        pickRoleMatch = v(.pickRoleMatch, d.pickRoleMatch)
        pickOffRolePerWeight = v(.pickOffRolePerWeight, d.pickOffRolePerWeight)
        pickTier = v(.pickTier, d.pickTier)
        pickEligibleBonus = v(.pickEligibleBonus, d.pickEligibleBonus)
        pickIneligiblePenalty = v(.pickIneligiblePenalty, d.pickIneligiblePenalty)
        pickCallout = v(.pickCallout, d.pickCallout)
        pickStackOne = v(.pickStackOne, d.pickStackOne)
        pickStackTwo = v(.pickStackTwo, d.pickStackTwo)
        pickPersonalMax = v(.pickPersonalMax, d.pickPersonalMax)
        personalConfidenceGames = v(.personalConfidenceGames, d.personalConfidenceGames)
        pickObservedMax = v(.pickObservedMax, d.pickObservedMax)
        observedConfidenceGames = v(.observedConfidenceGames, d.observedConfidenceGames)
        pickCounterBonus = v(.pickCounterBonus, d.pickCounterBonus)
        pickCounteredPenalty = v(.pickCounteredPenalty, d.pickCounteredPenalty)
        banRole = v(.banRole, d.banRole)
        banTier = v(.banTier, d.banTier)
        banCallout = v(.banCallout, d.banCallout)
        banThreatMax = v(.banThreatMax, d.banThreatMax)
        threatConfidenceGames = v(.threatConfidenceGames, d.threatConfidenceGames)
        banOwnPickPenalty = v(.banOwnPickPenalty, d.banOwnPickPenalty)
        unknownRoleWeight = v(.unknownRoleWeight, d.unknownRoleWeight)
        halfLifeDays = v(.halfLifeDays, d.halfLifeDays)
        rankedGameWeight = v(.rankedGameWeight, d.rankedGameWeight)
        smoothPseudoWins = v(.smoothPseudoWins, d.smoothPseudoWins)
        smoothPseudoGames = v(.smoothPseudoGames, d.smoothPseudoGames)
        minGames = v(.minGames, d.minGames)
        wpTier = v(.wpTier, d.wpTier)
        wpRole = v(.wpRole, d.wpRole)
        wpPersonal = v(.wpPersonal, d.wpPersonal)
        wpSigmoidK = v(.wpSigmoidK, d.wpSigmoidK)
        wpTossEdge = v(.wpTossEdge, d.wpTossEdge)
        wpAntiTankBonus = v(.wpAntiTankBonus, d.wpAntiTankBonus)
        wpAntiTankSpaceMakerBonus = v(.wpAntiTankSpaceMakerBonus, d.wpAntiTankSpaceMakerBonus)
        wpPassiveRangeBonus = v(.wpPassiveRangeBonus, d.wpPassiveRangeBonus)
        wpStackPenalty = v(.wpStackPenalty, d.wpStackPenalty)
        wpNoAntiTankPenalty = v(.wpNoAntiTankPenalty, d.wpNoAntiTankPenalty)
        wpBaseDraftWeight = v(.wpBaseDraftWeight, d.wpBaseDraftWeight)
        wpBaselineConfidenceGames = v(.wpBaselineConfidenceGames, d.wpBaselineConfidenceGames)
        wpClampMin = v(.wpClampMin, d.wpClampMin)
        wpClampMax = v(.wpClampMax, d.wpClampMax)
        wpShrinkMatches = v(.wpShrinkMatches, d.wpShrinkMatches)
        wpCalibrationStrength = v(.wpCalibrationStrength, d.wpCalibrationStrength)
        wpCalibrationMinMatches = v(.wpCalibrationMinMatches, d.wpCalibrationMinMatches)
    }
}

/// The playbook's structural rules, editable.
struct PlaybookConfig: Codable, Equatable {
    var modeMeta: [String: String]
    var dominantAggro: [DraftClass]
    var dominantPassive: [DraftClass]
    var targetsAggro: [[DraftClass]]
    var targetsPassive: [[DraftClass]]
    var callouts: [String: [String]]
    var classOverrides: [String: DraftClass]

    static let defaults = PlaybookConfig(
        modeMeta: ["brawlball": "Aggro", "gemgrab": "Aggro", "hotzone": "Aggro", "heist": "Aggro",
                   "bounty": "Passive", "knockout": "Passive"],
        dominantAggro: [.antiTank, .spaceMaker, .tank, .control, .thrower, .sniper, .support],
        dominantPassive: [.control, .sniper, .antiTank, .spaceMaker, .support, .tank, .thrower],
        targetsAggro: [[.antiTank], [.antiTank, .spaceMaker], [.spaceMaker, .tank], []],
        targetsPassive: [[.control], [.sniper, .control], [], []],
        callouts: ["brawlball": ["Crow", "Otis", "Chester", "Clancy"],
                   "hotzone": ["Lou", "Finx", "Crow", "Clancy", "Otis"],
                   "gemgrab": ["Chester", "Moe", "Lily", "Shade"],
                   "heist": ["Crow", "Colt", "Otis", "Melodie", "Kaze"],
                   "bounty": ["Pearl", "Gene", "Leon", "Angelo", "Belle"],
                   "knockout": ["Gene", "Leon", "Pearl", "Angelo", "R-T"]],
        classOverrides: [:])

    init(modeMeta: [String: String], dominantAggro: [DraftClass], dominantPassive: [DraftClass],
         targetsAggro: [[DraftClass]], targetsPassive: [[DraftClass]],
         callouts: [String: [String]], classOverrides: [String: DraftClass]) {
        self.modeMeta = modeMeta; self.dominantAggro = dominantAggro; self.dominantPassive = dominantPassive
        self.targetsAggro = targetsAggro; self.targetsPassive = targetsPassive
        self.callouts = callouts; self.classOverrides = classOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PlaybookConfig.defaults
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? fallback
        }
        modeMeta = v(.modeMeta, d.modeMeta)
        dominantAggro = v(.dominantAggro, d.dominantAggro)
        dominantPassive = v(.dominantPassive, d.dominantPassive)
        targetsAggro = v(.targetsAggro, d.targetsAggro)
        targetsPassive = v(.targetsPassive, d.targetsPassive)
        callouts = v(.callouts, d.callouts)
        classOverrides = v(.classOverrides, d.classOverrides)
    }
}

struct DraftConfig: Codable, Equatable {
    /// Bumped when defaults change so saved files can be migrated.
    var version = 2
    var weights = DraftWeights()
    var playbook = PlaybookConfig.defaults

    static let defaults = DraftConfig()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = ((try? c.decodeIfPresent(Int.self, forKey: .version)) ?? nil) ?? 1
        weights = ((try? c.decodeIfPresent(DraftWeights.self, forKey: .weights)) ?? nil) ?? DraftWeights()
        playbook = ((try? c.decodeIfPresent(PlaybookConfig.self, forKey: .playbook)) ?? nil) ?? .defaults
    }
}
