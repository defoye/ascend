import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the client's "have an invite code?" claim flow, shown on
/// `ConsumerRootView`'s no-coach state: normalizes the entered code, claims
/// it via `InviteRepository.claimInvite(code:clientID:)`, and surfaces the
/// resulting `Engagement` on success.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ClaimInviteViewModel {
    public var code = ""
    public private(set) var claimedEngagement: Engagement?
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let backend: any Backend
    private let clientID: Identifier<Person>

    public init(backend: any Backend, clientID: Identifier<Person>) {
        self.backend = backend
        self.clientID = clientID
    }

    public var isValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Claims the entered code. Returns whether the claim succeeded.
    @discardableResult
    public func claim() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            let engagement = try await backend.invites.claimInvite(
                code: EngagementInvite.normalize(code),
                clientID: clientID
            )
            claimedEngagement = engagement
            errorMessage = nil
            return true
        } catch let error as InviteError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = Self.genericErrorMessage
            return false
        }
    }

    private static let genericErrorMessage = "That code didn't work. Try again."

    private static func message(for error: InviteError) -> String {
        switch error {
        case .invalidCode: "That code didn't work. Double-check it with your coach."
        case .alreadyClaimed: "That code was already used."
        case .cannotClaimOwnInvite: genericErrorMessage
        }
    }
}
