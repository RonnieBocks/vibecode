import Foundation

/// # Objective knowledge must stay separate from player knowledge
///
/// Everything in DraftCore models **the game**, never **the player**. A profile
/// says what Lou is; it never says how well you play him.
///
/// These types are objective knowledge and must never gain user-specific or
/// learned-performance fields:
///
/// - `BrawlerProfile`  — stable identity
/// - `BalanceState`    — the game's numbers this patch
/// - `CapabilitySet`   — derived from the two above
/// - `InteractionModel`— how brawlers relate to each other
/// - `RankedSeason`    — the competitive environment
///
/// Specifically forbidden here: player win rate, user proficiency, user skill,
/// personal recommendation score, player preference, or anything else that
/// varies between two people looking at the same patch.
///
/// `SkillProfile` is deliberately *not* an exception. It records how demanding
/// a brawler is **in general** — a property of the kit, true for everyone. It
/// says nothing about whether a particular player meets that demand.
///
/// ## Why the separation matters
///
/// The eventual recommendation pipeline has to keep these values distinct and
/// individually inspectable:
///
///     Objective Draft Score          ← DraftCore alone
///     Meta / Current-State Adjustment← DraftCore (BalanceState, RankedSeason)
///     Player Proficiency Adjustment  ← future PlayerModel
///     Contextual Player Adjustment   ← future PlayerModel
///     Final Personalized Score       ← composed from the above
///
/// If player data leaked into a profile, the first two terms could no longer be
/// computed on their own, and "is this pick good?" would become inseparable
/// from "is this pick good *for me*?". That subsystem is not built yet; this
/// boundary exists so building it later stays cheap.
///
/// Player-side data already exists elsewhere and stays there: `DraftLearning`
/// holds personal and observed win rates, and `MatchLogStore` holds match
/// history. Neither is imported by DraftCore.
protocol ObjectiveKnowledge {}

extension BrawlerProfile: ObjectiveKnowledge {}
extension BalanceState: ObjectiveKnowledge {}
extension CapabilitySet: ObjectiveKnowledge {}
extension InteractionModel: ObjectiveKnowledge {}
extension RankedSeason: ObjectiveKnowledge {}

enum DraftCoreBoundary {
    /// Field-name fragments that would signal player data leaking into the
    /// objective model. Asserted against the encoded form of every
    /// `ObjectiveKnowledge` type, so the boundary is checked rather than
    /// merely documented.
    static let forbiddenFieldFragments = [
        "winrate", "winloss", "proficiency", "userskill", "playerskill",
        "personal", "preference", "recommendationscore", "myrate", "ownrate",
        "elo", "trophies", "mastery",
    ]

    /// Every key in `json`, recursively, lowercased.
    static func keys(in json: Any) -> [String] {
        switch json {
        case let dict as [String: Any]:
            return dict.keys.map { $0.lowercased() } + dict.values.flatMap { keys(in: $0) }
        case let array as [Any]:
            return array.flatMap { keys(in: $0) }
        default:
            return []
        }
    }
}
