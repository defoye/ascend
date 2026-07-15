import Domain
import Foundation
import Observation

/// Persists the signed-in person's active `PersonRole` and, per role, when
/// they last visited that side of the app (see docs/design/DESIGN_SPEC.md §4
/// "Role switch"). Backed by `UserDefaults`, mirroring `DemoModeStore`'s
/// persistence pattern. This is composition-root state — the App target is
/// the only place allowed to own persistence (see CLAUDE.md's dependency
/// rule) — `RoleActivitySummary` (in `Features`) stays pure and stateless.
@MainActor
@Observable
final class RolePresenceStore {
    private static let activeRoleKey = "com.ascend.role.active"
    private static let lastVisitedKeyPrefix = "com.ascend.role.lastVisited."

    private let defaults: UserDefaults

    var activeRole: PersonRole {
        didSet { defaults.set(activeRole.rawValue, forKey: Self.activeRoleKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        activeRole = PersonRole(rawValue: defaults.string(forKey: Self.activeRoleKey) ?? "") ?? .professional
    }

    func lastVisited(_ role: PersonRole) -> Date? {
        defaults.object(forKey: Self.lastVisitedKeyPrefix + role.rawValue) as? Date
    }

    func markVisited(_ role: PersonRole, at date: Date) {
        defaults.set(date, forKey: Self.lastVisitedKeyPrefix + role.rawValue)
    }
}

/// Pure gating decisions for the role switcher, kept free of `UserDefaults`
/// / view state so they're directly unit-testable (see docs/PRODUCT.md
/// "Roles": a person with only one role never sees a switcher).
enum RoleGating {
    /// The role to render, given which roles the signed-in person actually
    /// holds and their last-persisted choice. A single-role person is always
    /// forced onto that one role, regardless of what's persisted (e.g. from
    /// a prior session when they held both).
    static func resolveActiveRole(roles: Set<PersonRole>, persisted: PersonRole) -> PersonRole {
        if roles.count == 1, let only = roles.first {
            return only
        }
        if roles.contains(persisted) {
            return persisted
        }
        return roles.contains(.professional) ? .professional : .consumer
    }

    /// The switcher is only ever offered to a person who holds both roles.
    static func switcherAvailable(roles: Set<PersonRole>) -> Bool {
        roles.count > 1
    }
}
