import Foundation

/// Provenance for a hand-authored profile.
///
/// Exists to make the fourth authoring law enforceable — *omission beats
/// invention*. A profile that was guessed at is marked as such and appears in a
/// review report, rather than sitting in the roster indistinguishable from one
/// that is well understood.
struct AuthoringMetadata: Codable, Hashable {
    enum Confidence: String, Codable, CaseIterable, Comparable {
        case low, medium, high

        private var rank: Int {
            switch self { case .low: return 0; case .medium: return 1; case .high: return 2 }
        }
        static func < (a: Confidence, b: Confidence) -> Bool { a.rank < b.rank }
    }

    /// Why a profile is unresolved, so a missing role can never quietly read as
    /// "this brawler has no role".
    enum UnresolvedReason: String, Codable, CaseIterable {
        /// Not enough kit evidence to author it yet.
        case insufficientEvidence
        /// The mechanic exists but the vocabulary cannot express it.
        case vocabularyGap
        /// Two definitions both partly fit and the tie is unbroken.
        case classificationBoundary
        /// Behaviour differs by form or state in a way the base profile can't hold.
        case stateBehaviour
        /// Not draftable in this context — promo brawlers hidden from ranked.
        case gameContextExclusion
    }

    var confidence: Confidence
    /// Required whenever a profile carries no role.
    var unresolvedReason: UnresolvedReason?
    var reviewedAt: Date?
    /// Which evidence backed this profile — e.g. "playbook:antiTank",
    /// "brawlapi-tip", "match-log", "model-knowledge".
    var sources: [String]
    /// Anything left deliberately unresolved, for a human to settle.
    var openQuestions: [String]

    init(confidence: Confidence = .medium, unresolvedReason: UnresolvedReason? = nil,
         reviewedAt: Date? = nil,
         sources: [String] = [], openQuestions: [String] = []) {
        self.confidence = confidence
        self.unresolvedReason = unresolvedReason
        self.reviewedAt = reviewedAt
        self.sources = sources
        self.openQuestions = openQuestions
    }

    /// Needs a human to look at it before the roster can be trusted.
    var needsReview: Bool { confidence < .high || !openQuestions.isEmpty }

    enum CodingKeys: String, CodingKey {
        case confidence, unresolvedReason, reviewedAt, sources, openQuestions
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        confidence = d.get(.confidence, .medium)
        unresolvedReason = d.optional(.unresolvedReason)
        reviewedAt = d.optional(.reviewedAt)
        sources = d.get(.sources, [])
        openQuestions = d.get(.openQuestions, [])
    }
}
