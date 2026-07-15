import Domain
import Foundation
import Testing

@testable import Ascend

@Suite("RolePresenceStore persistence")
@MainActor
struct RolePresenceStoreTests {
    @Test("defaults to professional and no visits when nothing persisted")
    func defaultsAreProfessionalWithNoVisits() throws {
        let defaults = try #require(UserDefaults(suiteName: "RolePresenceStoreTests.\(UUID().uuidString)"))
        let store = RolePresenceStore(defaults: defaults)
        #expect(store.activeRole == .professional)
        #expect(store.lastVisited(.professional) == nil)
        #expect(store.lastVisited(.consumer) == nil)
    }

    @Test("activeRole persists across store instances sharing the same UserDefaults")
    func activeRolePersistsAcrossInstances() throws {
        let defaults = try #require(UserDefaults(suiteName: "RolePresenceStoreTests.\(UUID().uuidString)"))
        let store = RolePresenceStore(defaults: defaults)
        store.activeRole = .consumer

        let reloaded = RolePresenceStore(defaults: defaults)
        #expect(reloaded.activeRole == .consumer)
    }

    @Test("markVisited records a per-role last-visited date that persists across instances")
    func lastVisitedPersistsPerRole() throws {
        let defaults = try #require(UserDefaults(suiteName: "RolePresenceStoreTests.\(UUID().uuidString)"))
        let store = RolePresenceStore(defaults: defaults)
        let visitedAt = Date(timeIntervalSince1970: 1_700_000_000)
        store.markVisited(.consumer, at: visitedAt)

        let reloaded = RolePresenceStore(defaults: defaults)
        #expect(reloaded.lastVisited(.consumer) == visitedAt)
        #expect(reloaded.lastVisited(.professional) == nil)
    }
}

@Suite("RoleGating")
struct RoleGatingTests {
    @Test("a single-role person is forced onto that role regardless of what's persisted")
    func singleRoleIsForced() {
        #expect(RoleGating.resolveActiveRole(roles: [.professional], persisted: .consumer) == .professional)
        #expect(RoleGating.resolveActiveRole(roles: [.consumer], persisted: .professional) == .consumer)
    }

    @Test("a both-role person keeps their persisted role")
    func bothRolesKeepsPersistedChoice() {
        #expect(RoleGating.resolveActiveRole(roles: [.professional, .consumer], persisted: .consumer) == .consumer)
        #expect(RoleGating.resolveActiveRole(roles: [.professional, .consumer], persisted: .professional) == .professional)
    }

    @Test("the switcher is only offered to a both-role person")
    func switcherAvailabilityMatchesRoleCount() {
        #expect(RoleGating.switcherAvailable(roles: [.professional]) == false)
        #expect(RoleGating.switcherAvailable(roles: [.consumer]) == false)
        #expect(RoleGating.switcherAvailable(roles: [.professional, .consumer]) == true)
    }
}
