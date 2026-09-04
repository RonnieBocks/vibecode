import Foundation

/// What a brawler fundamentally *is*. Nothing here may hold a value that a
/// balance patch can move — that belongs in `BalanceState`.

// MARK: - Role

/// The brawler's role identity. Open vocabulary so an unrecognised term
/// round-trips rather than failing to decode, but the seeded roster is held to
/// the eight controlled terms below.
struct BrawlerRole: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    /// The duelist class: damage that punishes bulk and committed divers.
    static let antiTank   = BrawlerRole(rawValue: "antiTank")
    /// Takes ground by threatening to close; absorbs the bruiser archetype.
    static let spaceMaker = BrawlerRole(rawValue: "spaceMaker")
    /// Selects a specific target and commits to removing it on its own terms,
    /// then disengages.
    ///
    /// The elimination may be immediate *or set up over time*: poke to weaken,
    /// deny sustain to create a kill threshold, commit with mobility, secure
    /// the kill, escape. Time-to-kill is not the test — target selection,
    /// control of when the commitment happens, and the ability to leave are.
    ///
    /// Excludes poke and control brawlers that merely happen to be mobile: if
    /// damage is spread across the enemy team rather than aimed at removing one
    /// target, or the mobility exists to reposition rather than to commit onto
    /// a target, the brawler is not an assassin.
    static let assassin   = BrawlerRole(rawValue: "assassin")
    /// Wins by absorbing damage and occupying contested ground.
    static let tank       = BrawlerRole(rawValue: "tank")
    /// Long range, high single-target damage, punished up close.
    static let sniper     = BrawlerRole(rawValue: "sniper")
    /// Attacks indirectly, without line of sight, to deny ground.
    static let thrower    = BrawlerRole(rawValue: "thrower")
    /// Restricts where enemies can go; wins by shaping the map.
    static let control    = BrawlerRole(rawValue: "control")
    /// Increases what teammates can do.
    static let support    = BrawlerRole(rawValue: "support")

    static let known: [BrawlerRole] = [.antiTank, .spaceMaker, .assassin, .tank,
                                       .sniper, .thrower, .control, .support]
}

// MARK: - Positioning

/// Depth relative to team formation. Deliberately excludes lateral concepts:
/// a side-lane assignment is not a depth, and is decided per map rather than
/// being stable identity.
///
/// There is no `flexible` term. Depth variation by mode is a property of the
/// *mode*, not of the brawler, so "flexible" could not be defined without
/// collapsing into "unknown" — and unknown is already representable, because
/// `BrawlerProfile.positioning` is optional.
struct Positioning: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    static let frontline = Positioning(rawValue: "frontline")
    static let midline   = Positioning(rawValue: "midline")
    static let backline  = Positioning(rawValue: "backline")

    static let known: [Positioning] = [.frontline, .midline, .backline]

    /// 0 = front, 1 = back; `flexible` sits in the middle. `nil` for a term
    /// this build doesn't recognise.
    var depth: Double? {
        switch self {
        case .frontline: return 0
        case .midline: return 0.5
        case .backline: return 1
        default: return nil
        }
    }
}

// MARK: - Engage pattern

/// How the brawler engages or applies pressure — never where it stands.
/// Ordered, most characteristic first.
struct EngagePattern: VocabularyTerm {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }

    /// Commits directly to close distance and kill, on its own terms.
    static let dive     = EngagePattern(rawValue: "dive")
    /// Takes an indirect or concealed route to attack from an off-angle.
    static let flank    = EngagePattern(rawValue: "flank")
    /// Chips from range without committing.
    static let poke     = EngagePattern(rawValue: "poke")
    /// Forces enemies to give ground through sustained threat.
    static let pressure = EngagePattern(rawValue: "pressure")
    /// Anchors a position and denies ground; the enemy must come to it.
    static let hold     = EngagePattern(rawValue: "hold")

    static let known: [EngagePattern] = [.dive, .flank, .poke, .pressure, .hold]
}

// MARK: - Skill

/// How demanding the brawler is to play, across six authored dimensions.
///
/// Every dimension is rated **1 = low, 5 = high**, in the same direction, so
/// there is no polarity trap while authoring. Consistency is deliberately not
/// authored: it is derived for display as the inverse of `variance`.
struct SkillProfile: Codable, Hashable {
    /// Execution beyond aiming: timing, combos, resource management.
    var mechanicalDifficulty: Int
    /// Precision the primary attack demands (base attack, not the Super).
    var aimDifficulty: Int
    /// How much value depends on standing in exactly the right place.
    var positioningDifficulty: Int
    /// Knowledge outside mechanics: matchups, timers, rotations, maps.
    var gameKnowledge: Int
    /// How much practical effectiveness varies across engagements, matchups,
    /// maps, team compositions, execution outcomes, or temporary game states.
    var variance: Int
    /// The cost of one mistake, independent of how often mistakes happen.
    var mistakePunishment: Int
    var note: String?

    init(mechanicalDifficulty: Int = 3, aimDifficulty: Int = 3,
         positioningDifficulty: Int = 3, gameKnowledge: Int = 3,
         variance: Int = 3, mistakePunishment: Int = 3, note: String? = nil) {
        self.mechanicalDifficulty = mechanicalDifficulty
        self.aimDifficulty = aimDifficulty
        self.positioningDifficulty = positioningDifficulty
        self.gameKnowledge = gameKnowledge
        self.variance = variance
        self.mistakePunishment = mistakePunishment
        self.note = note
    }

    /// 1…5 mapped onto 0…1.
    static func normalize(_ level: Int) -> Double {
        (Double(min(5, max(1, level))) - 1) / 4
    }

    var mechanical: Double { Self.normalize(mechanicalDifficulty) }
    var aim: Double { Self.normalize(aimDifficulty) }
    var positioning: Double { Self.normalize(positioningDifficulty) }
    var knowledge: Double { Self.normalize(gameKnowledge) }
    var swinginess: Double { Self.normalize(variance) }
    var punishment: Double { Self.normalize(mistakePunishment) }

    /// Display-only inverse of variance. Never authored.
    var consistency: Double { 1 - swinginess }

    /// How demanding the brawler is before it stops being a liability.
    var floor: Double { (mechanical + aim + positioning + swinginess) / 4 }
    /// How much a strong player can add beyond that.
    var ceiling: Double { (mechanical + aim + knowledge) / 3 }

    enum CodingKeys: String, CodingKey {
        case mechanicalDifficulty, aimDifficulty, positioningDifficulty,
             gameKnowledge, variance, mistakePunishment, note
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        mechanicalDifficulty = d.get(.mechanicalDifficulty, 3)
        aimDifficulty = d.get(.aimDifficulty, 3)
        positioningDifficulty = d.get(.positioningDifficulty, 3)
        gameKnowledge = d.get(.gameKnowledge, 3)
        variance = d.get(.variance, 3)
        mistakePunishment = d.get(.mistakePunishment, 3)
        note = d.optional(.note)
    }
}
