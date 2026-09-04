import Foundation

/// A brawler's alternate form or state, expressed as a *diff* against its base
/// profile rather than as a second profile.
///
/// A form-shifting brawler does not have unknown positioning — it has several
/// legitimate states. The base profile stays authoritative; a form overrides
/// only the fields that genuinely change.
///
/// This is identity, not simulation. It records that Bonnie is backline in the
/// cannon and frontline out of it; it says nothing about which form she is in
/// during a given match.
///
/// ## Draft-time versus current-state identity
///
/// A draft engine must not treat a transform brawler as permanently locked into
/// either state, and equally must not award it the full strength of every form
/// at once. Two pieces of information keep both readings available:
///
/// 1. **The base profile is the state the brawler begins each life in.** That is
///    the identity an opponent can always count on, and the only one certain at
///    the moment of a pick.
/// 2. **`availability` says how a form is reached.** A form behind a Super is
///    deniable — pressure the brawler and it never arrives — while a guaranteed
///    form is not. A future engine can therefore treat forms as *reachable
///    potential*, discounted by how deniable they are, rather than as free
///    additional strength.
///
/// How *often* a form is reached is patch-dependent (charge rates, cooldowns)
/// and belongs in `BalanceState`. That it is Super-gated at all is stable
/// identity and belongs here.
struct FormOverride: Codable, Hashable, Identifiable {
    /// How a form is reached — the stable half of "will this actually happen?".
    enum Availability: String, Codable, CaseIterable {
        /// Entered every life with no precondition an opponent can deny.
        case guaranteed
        /// Requires charging a Super, so pressure can prevent it entirely.
        case superGated
        /// Situational or random; it cannot be planned around by either side.
        case conditional
    }

    /// Display name of the state — "Cannon", "Dragon", "Ninja".
    var name: String
    /// How reachable this form is. Defaults to `superGated`, the common case.
    var availability: Availability
    /// Replaces the base positioning when this form is active. `nil` keeps it.
    var positioning: Positioning?
    /// Appended after the base roles, preserving base priority order.
    var addedRoles: [BrawlerRole]
    var addedEngagePatterns: [EngagePattern]
    var removedEngagePatterns: [EngagePattern]
    var addedTraits: Set<Trait>
    var removedTraits: Set<Trait>
    var addedFunctions: Set<DraftFunction>
    var notes: String?

    var id: String { name }

    init(name: String, availability: Availability = .superGated,
         positioning: Positioning? = nil,
         addedRoles: [BrawlerRole] = [],
         addedEngagePatterns: [EngagePattern] = [],
         removedEngagePatterns: [EngagePattern] = [],
         addedTraits: Set<Trait> = [], removedTraits: Set<Trait> = [],
         addedFunctions: Set<DraftFunction> = [], notes: String? = nil) {
        self.name = name; self.availability = availability; self.positioning = positioning
        self.addedRoles = addedRoles
        self.addedEngagePatterns = addedEngagePatterns
        self.removedEngagePatterns = removedEngagePatterns
        self.addedTraits = addedTraits; self.removedTraits = removedTraits
        self.addedFunctions = addedFunctions; self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case name, availability, positioning, addedRoles, addedEngagePatterns, removedEngagePatterns,
             addedTraits, removedTraits, addedFunctions, notes
    }
    init(from decoder: Decoder) throws {
        let d = try TolerantDecoder(decoder, keyedBy: CodingKeys.self)
        name = d.get(.name, "")
        availability = d.get(.availability, .superGated)
        positioning = d.optional(.positioning)
        addedRoles = d.get(.addedRoles, [])
        addedEngagePatterns = d.get(.addedEngagePatterns, [])
        removedEngagePatterns = d.get(.removedEngagePatterns, [])
        addedTraits = d.get(.addedTraits, [])
        removedTraits = d.get(.removedTraits, [])
        addedFunctions = d.get(.addedFunctions, [])
        notes = d.optional(.notes)
    }
}

extension BrawlerProfile {
    /// This profile as it stands in the named form. An unknown or nil name
    /// returns the base unchanged — the base is always authoritative.
    func resolved(inForm formName: String?) -> BrawlerProfile {
        guard let formName, let form = forms.first(where: { $0.name == formName }) else { return self }
        var out = self
        if let p = form.positioning { out.positioning = p }
        for role in form.addedRoles where !out.roles.contains(role) { out.roles.append(role) }
        out.engagePatterns = out.engagePatterns.filter { !form.removedEngagePatterns.contains($0) }
            + form.addedEngagePatterns.filter { !out.engagePatterns.contains($0) }
        out.traits.subtract(form.removedTraits)
        out.traits.formUnion(form.addedTraits)
        out.draftFunctions.formUnion(form.addedFunctions)
        return out
    }

    var hasForms: Bool { !forms.isEmpty }
    var formNames: [String] { forms.map(\.name) }

    /// Every identity an opponent may have to account for: the base a pick is
    /// certain to deliver, plus each form it can reach.
    ///
    /// Deliberately returns the states rather than a merged super-profile, so a
    /// future engine must decide how to weight them and cannot accidentally
    /// award the combined strength of all forms at once.
    var reachableStates: [(form: FormOverride?, profile: BrawlerProfile)] {
        [(nil, self)] + forms.map { ($0, resolved(inForm: $0.name)) }
    }

    /// True when every form is deniable — nothing is guaranteed beyond the base.
    var allFormsAreDeniable: Bool {
        !forms.isEmpty && forms.allSatisfy { $0.availability != .guaranteed }
    }
}
