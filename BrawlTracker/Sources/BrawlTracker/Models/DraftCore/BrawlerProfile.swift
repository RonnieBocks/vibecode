import Foundation

/// The stable identity record for one brawler.
///
/// The contract for this type: **no field here may change because of a balance
/// patch.** Lou is a controller with a slow area projectile and no escape tool
/// whether or not his damage was touched this month. Anything a patch moves
/// lives in `BalanceState`.
struct BrawlerProfile: Codable, Hashable, Identifiable {
    var key: BrawlerKey
    /// Ordered, primary first. Order is identity — it is never re-sorted to
    /// reflect current meta strength.
    var roles: [BrawlerRole]
    /// Optional on purpose. `flexible` means "genuinely varies", so it must not
    /// double as "not yet known" — an unauthored positioning stays nil and shows
    /// up in the coverage report instead of asserting something false.
    var positioning: Positioning?
    var engagePatterns: [EngagePattern]
    /// What the brawler is expected to do in a draft. An affinity, not a gate.
    var draftFunctions: Set<DraftFunction>
    var traits: Set<Trait>
    var skill: SkillProfile
    /// Alternate forms, expressed as diffs against this base profile. Empty for
    /// the great majority of brawlers.
    var forms: [FormOverride]
    /// Provenance and confidence. Absent for profiles nobody has reviewed.
    var authoring: AuthoringMetadata?
    var notes: String?

    var id: String { key.normalized }
    var primaryRole: BrawlerRole? { roles.first }

    init(key: BrawlerKey,
         roles: [BrawlerRole] = [],
         positioning: Positioning? = nil,
         engagePatterns: [EngagePattern] = [],
         draftFunctions: Set<DraftFunction> = [],
         traits: Set<Trait> = [],
         skill: SkillProfile = SkillProfile(),
         forms: [FormOverride] = [],
         authoring: AuthoringMetadata? = nil,
         notes: String? = nil) {
        self.key = key
        self.roles = roles
        self.positioning = positioning
        self.engagePatterns = engagePatterns
        self.draftFunctions = draftFunctions
        self.traits = traits
        self.skill = skill
        self.forms = forms
        self.authoring = authoring
        self.notes = notes
    }

    func has(_ trait: Trait) -> Bool { traits.contains(trait) }
    func performs(_ function: DraftFunction) -> Bool { draftFunctions.contains(function) }

    /// Terms this build doesn't recognise — surfaced so a coverage report can
    /// flag a document authored against a newer vocabulary.
    var unknownTerms: [String] {
        var out: [String] = []
        out += roles.filter { !$0.isKnown }.map(\.rawValue)
        out += engagePatterns.filter { !$0.isKnown }.map(\.rawValue)
        out += draftFunctions.filter { !$0.isKnown }.map(\.rawValue)
        out += traits.filter { !$0.isKnown }.map(\.rawValue)
        if let p = positioning, !p.isKnown { out.append(p.rawValue) }
        return out.sorted()
    }

    enum CodingKeys: String, CodingKey {
        case key, roles, positioning, engagePatterns, draftFunctions, traits, skill, forms, authoring, notes
    }

    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        key = d.get(.key, BrawlerKey(normalized: ""))
        roles = d.get(.roles, [])
        positioning = d.optional(.positioning)
        engagePatterns = d.get(.engagePatterns, [])
        draftFunctions = d.get(.draftFunctions, [])
        traits = d.get(.traits, [])
        skill = d.get(.skill, SkillProfile())
        forms = d.get(.forms, [])
        authoring = d.optional(.authoring)
        notes = d.optional(.notes)
    }
}

/// A keyed collection of profiles. Lookup is alias-aware, so a renamed brawler
/// still resolves through stored history.
struct BrawlerProfileSet: Codable, Hashable {
    var schemaVersion: Int
    var profiles: [BrawlerProfile]

    init(profiles: [BrawlerProfile] = []) {
        schemaVersion = DraftCoreSchema.version
        self.profiles = profiles
    }

    private var index: [String: BrawlerProfile] {
        Dictionary(profiles.map { ($0.key.normalized, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func profile(for name: String) -> BrawlerProfile? {
        let n = BrawlerArt.normalize(name)
        if let direct = index[n] { return direct }
        return profiles.first { $0.key.matches(name) }
    }

    func profile(for key: BrawlerKey) -> BrawlerProfile? { profile(for: key.normalized) }

    /// Names present in `roster` that have no profile. The engine must stay
    /// usable when this is non-empty — a new brawler arrives before its profile
    /// does, so missing data degrades to neutral rather than to invisible.
    func missingProfiles(in roster: [String]) -> [String] {
        roster.filter { profile(for: $0) == nil }.sorted()
    }

    /// Profiles a human should look at: guessed, incomplete, or carrying an
    /// unresolved question.
    var needingReview: [BrawlerProfile] {
        profiles.filter { $0.authoring?.needsReview ?? true }
            .sorted { $0.key.normalized < $1.key.normalized }
    }

    enum CodingKeys: String, CodingKey { case schemaVersion, profiles }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        schemaVersion = d.get(.schemaVersion, DraftCoreSchema.version)
        profiles = d.get(.profiles, [])
    }
}
