import SwiftUI

/// The seven draft classes from the playbook (how a brawler behaves in draft,
/// not the game's official class).
enum DraftClass: String, CaseIterable, Identifiable, Codable {
    case antiTank = "Anti-Tank"
    case spaceMaker = "Space Maker"
    case tank = "Tank"
    case control = "Control"
    case sniper = "Sniper"
    case thrower = "Thrower"
    case support = "Support"
    case unknown = "Unclassified"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .antiTank: return Color(red: 0.95, green: 0.45, blue: 0.35)
        case .spaceMaker: return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .tank: return Color(red: 0.45, green: 0.55, blue: 0.65)
        case .control: return Color(red: 0.35, green: 0.70, blue: 0.55)
        case .sniper: return Color(red: 0.50, green: 0.60, blue: 0.92)
        case .thrower: return Color(red: 0.90, green: 0.70, blue: 0.30)
        case .support: return Color(red: 0.45, green: 0.78, blue: 0.85)
        case .unknown: return .gray
        }
    }
}

/// The two metas every mode reduces to.
enum DraftMeta: String, Codable {
    case aggro = "Aggro"
    case passive = "Passive"
    case unknown = "Unknown"
}

enum DraftPlaybook {
    // MARK: - Roster → class (keyed by normalized brawler name)

    private static let roster: [DraftClass: [String]] = [
        .thrower: ["Barley", "Dynamike", "Larry & Lawrie", "Tick", "Sprout", "Grom",
                   "Ziggy", "Sirius", "Juju", "Willow", "Berry"],
        .tank: ["Trunk", "Draco", "Frank", "Fang", "Buster", "El Primo", "Hank",
                "Jacky", "Rosa", "Ash"],
        .spaceMaker: ["Bull", "Bibi", "Ollie", "Kenji", "Mortis", "Shade", "Mina",
                      "Buzz", "Alli", "Carl", "Edgar", "Kaze", "Lily", "Mico", "Sam",
                      "Chuck", "Gigi", "Melodie", "Darryl"],
        .antiTank: ["Chester", "Nita", "Moe", "Rico", "Tara", "Emz", "Lou", "Finx",
                    "Ruffs", "Sandy", "Otis", "Lumi", "Shelly", "Surge", "Charlie",
                    "Gale", "Spike", "Cordelius", "Maisie", "Colt", "Griff", "Crow",
                    "8-Bit", "Clancy", "Colette", "Meg"],
        .support: ["Kit", "Max", "Gray", "Poco", "Jae-yong", "Doug", "Glowy"],
        .sniper: ["Mandy", "R-T", "Gus", "Piper", "Brock", "Byron", "Angelo",
                  "Pierce", "Nani", "Belle", "Bea"],
        .control: ["Amber", "Meeple", "Leon", "Pam", "Bo", "Pearl", "Gene", "Stu",
                   "Janet", "Penny", "Jessie", "Squeak", "Eve", "Lola", "Najia",
                   "Bonnie", "Mr. P"],
    ]

    static let classByName: [String: DraftClass] = {
        var map: [String: DraftClass] = [:]
        for (cls, names) in roster {
            for name in names { map[BrawlerArt.normalize(name)] = cls }
        }
        return map
    }()

    /// The live, editable configuration (set by DraftConfigStore).
    static var config: DraftConfig = .defaults

    /// Class from the built-in roster, ignoring user overrides.
    static func baseClass(for name: String) -> DraftClass {
        classByName[BrawlerArt.normalize(name)] ?? .unknown
    }

    static func draftClass(for name: String) -> DraftClass {
        let key = BrawlerArt.normalize(name)
        return config.playbook.classOverrides[key] ?? classByName[key] ?? .unknown
    }

    // MARK: - Modes

    /// Maps a game-mode name (any case) to its meta (editable).
    static func meta(forMode mode: String) -> DraftMeta {
        config.playbook.modeMeta[normalizeMode(mode)].flatMap(DraftMeta.init(rawValue:)) ?? .unknown
    }

    /// Target classes for a slot (0 = 1st, 1 = 2–3, 2 = 4–5, 3 = Last); empty = counter logic.
    static func targetClasses(meta: DraftMeta, slotIndex: Int) -> [DraftClass] {
        let arr = meta == .aggro ? config.playbook.targetsAggro : meta == .passive ? config.playbook.targetsPassive : []
        return arr[safe: slotIndex] ?? []
    }

    static func callouts(forMode mode: String) -> [String] {
        config.playbook.callouts[normalizeMode(mode)] ?? []
    }

    static func normalizeMode(_ mode: String) -> String {
        mode.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.reduce("") { $0 + String($1) }
    }

    /// One slot of a mode's pick-order track.
    struct Slot: Identifiable { let label: String; let text: String; var id: String { label } }

    struct ModeGuide {
        let meta: DraftMeta
        let slots: [Slot]
        /// Notable brawlers to weight up for this mode's first pick / bans.
        let priorityCallouts: [String]
    }

    static func guide(forMode mode: String) -> ModeGuide? {
        switch normalizeMode(mode) {
        case "brawlball":
            return ModeGuide(meta: .aggro, slots: [
                Slot(label: "1st", text: "Best available anti-tank — Crow, Otis, Chester, Clancy."),
                Slot(label: "2–3", text: "Next-best anti-tank. If enemy skipped anti-tank, take the best space maker, then circle back."),
                Slot(label: "4–5", text: "Add a space maker if enemy lacks one, or a tank (Frank/Draco) vs an unanswered space maker."),
                Slot(label: "Last", text: "Counter what's missing — no space maker → thrower; no anti-tank → tank."),
            ], priorityCallouts: callouts(forMode: mode))
        case "hotzone":
            return ModeGuide(meta: .aggro, slots: [
                Slot(label: "1st", text: "Best anti-tank — Lou, Finx, Crow, Clancy, Otis."),
                Slot(label: "2–3", text: "Next-best anti-tank, or an aggressive pick if the first was weak."),
                Slot(label: "4–5", text: "Anti-tank + space maker is the strongest finish. High-HP tank vs a stacked space maker with no damage."),
                Slot(label: "Last", text: "Counter the hole in their comp."),
            ], priorityCallouts: callouts(forMode: mode))
        case "gemgrab":
            return ModeGuide(meta: .aggro, slots: [
                Slot(label: "1st", text: "Best anti-tank."),
                Slot(label: "2–3", text: "Anti-tank + a gem-steal hyper: Chester, Moe, Lily, Shade."),
                Slot(label: "4–5", text: "Counter their weakness, prioritizing gem-steal potential."),
                Slot(label: "Last", text: "Counter. Never stack three of the same class."),
            ], priorityCallouts: callouts(forMode: mode))
        case "heist":
            return ModeGuide(meta: .aggro, slots: [
                Slot(label: "1st", text: "Anti-tank that also does safe damage — Crow, Colt."),
                Slot(label: "2–3", text: "More anti-tank/damage (Otis, 8-Bit, Colt, Belle) plus a strong damage hyper (Melodie, Kaze, Moe, Chuck)."),
                Slot(label: "4–5", text: "More damage — or a durable control pick (Belle/Eve) once two teammates already deal damage."),
                Slot(label: "Last", text: "Counter the gap. vs Chuck: out-damage the opposite safe instead of defending."),
            ], priorityCallouts: callouts(forMode: mode))
        case "bounty":
            return ModeGuide(meta: .passive, slots: [
                Slot(label: "1st", text: "Solid all-rounder, good vs aggro but not a hard counter — Pearl, Gene, Leon, Glowy."),
                Slot(label: "2–3", text: "Belle, Gus, Byron, RT, Bo, or Jae-Yong. Pro lines bait a 'blue-star' pick (Mina, Mortis, Kaze, Carl) — high risk."),
                Slot(label: "4–5", text: "Counter the read — Nani vs snipers, Alli vs blue-star, thrower vs double-sniper, support to hunt shot-dependent comps."),
                Slot(label: "Last", text: "Pure counter: no aggro → thrower/sniper; double-sniper + thrower → Mortis/Melodie."),
            ], priorityCallouts: callouts(forMode: mode))
        case "knockout":
            return ModeGuide(meta: .passive, slots: [
                Slot(label: "1st", text: "Solid pick — Gene, Leon, Pearl, Angelo, RT."),
                Slot(label: "2–3", text: "Strong hyper + good matchup — Leon, Mandy, Bo, RT, Alli, Meeple."),
                Slot(label: "4–5", text: "Another solid hyper brawler. Avoid throwers unless your team can protect the pick."),
                Slot(label: "Last", text: "Counter: Darryl vs no tank answer, thrower vs no thrower answer, Melodie vs no sniper answer."),
            ], priorityCallouts: callouts(forMode: mode))
        default:
            return nil
        }
    }

    // MARK: - Class priority per meta (which classes to weight for picks/bans)

    /// Classes that dominate each meta, strongest first (used to rank ban/pick
    /// candidates alongside the user's tier list).
    static func dominantClasses(for meta: DraftMeta) -> [DraftClass] {
        switch meta {
        case .aggro: return config.playbook.dominantAggro
        case .passive: return config.playbook.dominantPassive
        case .unknown: return DraftClass.allCases.filter { $0 != .unknown }
        }
    }
}
