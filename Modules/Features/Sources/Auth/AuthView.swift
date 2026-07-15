import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// Real sign-in / sign-up screen shown while `AuthGateway.currentAuth` is
/// `.signedOut` (see the App composition root's `RootView`). Sign-up
/// captures a role choice (coach / training with a coach / both) that
/// drives the created `Person`'s `roles` (see docs/PRODUCT.md "Roles") —
/// editable later in Settings (`SettingsViewModel.addOtherRole`).
public struct AuthView: View {
    @State private var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName, email, password
    }

    public init(viewModel: AuthViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Spacing.space6) {
                header
                modePicker
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                formCard
                submitButton
            }
            .padding(.horizontal, Spacing.space4)
            .padding(.top, Spacing.space10)
            .padding(.bottom, Spacing.space6)
        }
        .background(Color.Ascend.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: Spacing.space2) {
            Text("Ascend")
                .ascendType(.largeTitle)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text(viewModel.mode == .signIn ? "Sign in to continue" : "Create your account")
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }

    private var modePicker: some View {
        Picker("Sign in or sign up", selection: $viewModel.mode) {
            Text("Sign in").tag(AuthViewModel.Mode.signIn)
            Text("Sign up").tag(AuthViewModel.Mode.signUp)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Sign in or sign up")
    }

    private var formCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space4) {
                if viewModel.mode == .signUp {
                    AscendTextField(
                        label: "Full name",
                        placeholder: "Jordan Lee",
                        text: $viewModel.displayName,
                        errorText: viewModel.displayNameError
                    )
                    .focused($focusedField, equals: .displayName)
                    .textContentType(.name)
                }
                AscendTextField(
                    label: "Email",
                    placeholder: "you@example.com",
                    text: $viewModel.email,
                    errorText: viewModel.emailError
                )
                .focused($focusedField, equals: .email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                AscendTextField(
                    label: "Password",
                    placeholder: viewModel.mode == .signUp ? "At least 8 characters" : "Password",
                    text: $viewModel.password,
                    isSecure: true,
                    errorText: viewModel.passwordError
                )
                .focused($focusedField, equals: .password)
                .textContentType(viewModel.mode == .signUp ? .newPassword : .password)

                if viewModel.mode == .signUp {
                    rolePicker
                }
            }
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text("I'm here to")
                .ascendType(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Ascend.textSecondary)
            VStack(spacing: 0) {
                ForEach(Array(AuthRoleChoice.allCases.enumerated()), id: \.element) { index, choice in
                    if index != 0 {
                        Divider()
                    }
                    roleRow(choice)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.Ascend.surfaceSecondary)
            )
        }
    }

    private func roleRow(_ choice: AuthRoleChoice) -> some View {
        let isSelected = viewModel.roleChoice == choice
        return Button {
            viewModel.roleChoice = choice
        } label: {
            HStack(spacing: Spacing.space3) {
                Text(choice.displayName)
                    .ascendType(.body)
                    .foregroundStyle(Color.Ascend.textPrimary)
                Spacer(minLength: Spacing.space2)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.Ascend.primary : Color.Ascend.textTertiary)
            }
            .padding(.horizontal, Spacing.space3)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var submitButton: some View {
        AscendButton(
            viewModel.mode == .signIn ? "Sign in" : "Create account",
            isLoading: viewModel.isSubmitting
        ) {
            focusedField = nil
            Task { await viewModel.submit() }
        }
    }
}

#Preview("AuthView - Sign in - Light") {
    AuthView(viewModel: AuthViewModel(auth: PreviewAuthGateway()))
        .preferredColorScheme(.light)
}

#Preview("AuthView - Sign in - Dark") {
    AuthView(viewModel: AuthViewModel(auth: PreviewAuthGateway()))
        .preferredColorScheme(.dark)
}

#Preview("AuthView - Sign up") {
    AuthSignUpPreview()
        .preferredColorScheme(.light)
}

#Preview("AuthView - Error") {
    AuthErrorPreview()
        .preferredColorScheme(.light)
}

private struct AuthSignUpPreview: View {
    var body: some View {
        let viewModel = AuthViewModel(auth: PreviewAuthGateway())
        viewModel.mode = .signUp
        return AuthView(viewModel: viewModel)
    }
}

private struct AuthErrorPreview: View {
    var body: some View {
        let viewModel = AuthViewModel(auth: PreviewFailingAuthGateway())
        viewModel.email = "demo@ascend.app"
        viewModel.password = "wrongpassword"
        return AuthView(viewModel: viewModel)
            .task { await viewModel.submit() }
    }
}

private struct PreviewFailingAuthGateway: AuthGateway {
    var currentAuth: AsyncStream<AuthState> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws { throw PreviewAuthError.demo }
    func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws {
        throw PreviewAuthError.demo
    }
    func signOut() async throws {}
}

private enum PreviewAuthError: Error {
    case demo
}
