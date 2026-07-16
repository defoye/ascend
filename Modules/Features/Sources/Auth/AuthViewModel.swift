import DataInterfaces
import Domain
import Observation

/// The three role choices offered at sign-up (see docs/PRODUCT.md "Roles"):
/// "Coach" -> `[.professional]`, "Training with a coach" -> `[.consumer]`,
/// "Both" -> both. A `Features`-local UI mapping onto `Domain.PersonRole` —
/// not a `Domain` type itself, since it only exists to drive this one
/// screen's picker.
public enum AuthRoleChoice: String, CaseIterable, Identifiable, Sendable {
    case coach
    case client
    case both

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .coach: "Coach"
        case .client: "Training with a coach"
        case .both: "Both"
        }
    }

    public var roles: Set<PersonRole> {
        switch self {
        case .coach: [.professional]
        case .client: [.consumer]
        case .both: [.professional, .consumer]
        }
    }
}

/// View model for `AuthView`: toggles between sign-in and sign-up, validates
/// input locally, and calls through to `AuthGateway`. A successful sign-in
/// or sign-up transitions `AuthGateway.currentAuth` to `.signedIn`, which
/// the App composition root's `RootView` observes to leave this screen —
/// this view model never navigates directly.
@MainActor
@Observable
public final class AuthViewModel {
    public enum Mode: Hashable, Sendable {
        case signIn, signUp
    }

    public var mode: Mode = .signIn {
        didSet { errorMessage = nil }
    }
    public var displayName = ""
    public var email = ""
    public var password = ""
    public var roleChoice: AuthRoleChoice = .client

    public private(set) var isSubmitting = false
    public private(set) var errorMessage: String?
    public private(set) var displayNameError: String?
    public private(set) var emailError: String?
    public private(set) var passwordError: String?
    /// Set after a sign-up that returns `.confirmationRequired`, to the
    /// email that needs confirming; `AuthView` renders it as a banner
    /// instead of silently doing nothing. Cleared at the top of every
    /// `submit()` call (so any fresh sign-in or sign-up attempt starts
    /// clean) and re-set by that same call if it's another
    /// `.confirmationRequired` sign-up. It is not cleared by `mode`'s
    /// `didSet`, because `submit()` itself sets `mode = .signIn` as part of
    /// showing the notice — clearing there would immediately erase what it
    /// just set. A user manually switching back to "Sign up" therefore
    /// still sees the notice until their next `submit()`, which is the
    /// simplest rule that can't strand it and can't self-erase.
    public private(set) var confirmationNoticeEmail: String?

    private static let minPasswordLength = 8

    private let auth: any AuthGateway

    public init(auth: any AuthGateway) {
        self.auth = auth
    }

    /// Validates the current form state, then calls `signIn`/`signUp`
    /// against `AuthGateway`. Field-level errors (`displayNameError`,
    /// `emailError`, `passwordError`) are cleared and recomputed on every
    /// call; `errorMessage` surfaces a submission failure (wrong
    /// credentials, network) via `ErrorBanner`.
    public func submit() async {
        errorMessage = nil
        confirmationNoticeEmail = nil
        guard validate() else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: trimmedEmail, password: password)
            case .signUp:
                let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                let outcome = try await auth.signUp(
                    email: trimmedEmail, password: password, displayName: trimmedName, roles: roleChoice.roles
                )
                if outcome == .confirmationRequired {
                    confirmationNoticeEmail = trimmedEmail
                    mode = .signIn
                }
            }
            errorMessage = nil
        } catch AuthGatewayError.emailNotConfirmed {
            errorMessage = "Confirm your email first — check your inbox for the link we sent to \(trimmedEmail)."
        } catch {
            errorMessage = mode == .signIn
                ? "Couldn't sign in. Check your email and password and try again."
                : "Couldn't create your account. Try again."
        }
    }

    private func validate() -> Bool {
        displayNameError = nil
        emailError = nil
        passwordError = nil
        var isValid = true

        if mode == .signUp, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayNameError = "Enter your name"
            isValid = false
        }
        if !Self.isValidEmail(email) {
            emailError = "Enter a valid email address"
            isValid = false
        }
        if password.count < Self.minPasswordLength {
            passwordError = "Password must be at least \(Self.minPasswordLength) characters"
            isValid = false
        }
        return isValid
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = trimmed.firstIndex(of: "@"), atIndex != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}
