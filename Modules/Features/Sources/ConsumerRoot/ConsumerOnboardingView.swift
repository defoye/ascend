import DesignSystem
import Domain
import SwiftUI

/// Goal-first consumer onboarding: a guided intake (goal, experience level,
/// injuries/limitations, preferences) that produces a `Goal` and stores the
/// rest of the structured intake against the engagement (see
/// `ConsumerOnboardingViewModel`). Deliberately **not** AI-assessed — per
/// docs/PRODUCT.md, AI goal assessment/matching is a later, intentionally
/// deferred phase; this screen only captures structured data a human coach
/// can read.
public struct ConsumerOnboardingView: View {
    @State private var viewModel: ConsumerOnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: ConsumerOnboardingViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    introCard
                    goalSection
                    experienceSection
                    detailsSection
                    if let saveErrorMessage = viewModel.saveErrorMessage {
                        Text(saveErrorMessage)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.danger)
                            .padding(.horizontal, Spacing.space4)
                    }
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Tell us about you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton("Save", isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.submit() != nil {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
            }
        }
    }

    private var introCard: some View {
        Card {
            Text("A quick intake helps your coach build a plan around your goal, experience, and any limitations. This never uses AI to assess you — it's just stored for your coach to read.")
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("What's your main goal?")
            Card {
                Picker("Goal", selection: $viewModel.goalKind) {
                    ForEach(GoalKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Training experience")
            Card {
                Picker("Experience", selection: $viewModel.experienceLevel) {
                    ForEach(ExperienceLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Anything else?")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    AscendTextField(
                        label: "Injuries or limitations",
                        placeholder: "e.g. lower back sensitivity (optional)",
                        text: $viewModel.injuriesText
                    )
                    AscendTextField(
                        label: "Preferences",
                        placeholder: "e.g. prefer virtual sessions (optional)",
                        text: $viewModel.preferencesText
                    )
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("ConsumerOnboardingView - Light") {
    ConsumerOnboardingPreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerOnboardingView - Dark") {
    ConsumerOnboardingPreview()
        .preferredColorScheme(.dark)
}

private struct ConsumerOnboardingPreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        Text("Onboarding preview")
            .sheet(isPresented: .constant(true)) {
                ConsumerOnboardingView(
                    viewModel: ConsumerOnboardingViewModel(backend: backend, clientID: Identifier(), engagementID: backend.engagementAID)
                )
            }
    }
}
