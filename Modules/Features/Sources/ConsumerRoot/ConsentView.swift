import DesignSystem
import Domain
import SwiftUI

/// The client-facing outcome-sharing consent screen (see
/// docs/design/DESIGN_SPEC.md §1 "Consent is a first-class screen,
/// privacy-forward: anonymous, scoped to tracked measurements only,
/// reversible"). Copy stays within Invariant 2 (docs/PRODUCT.md): it
/// describes what sharing enables Ascend to **verify** — a real, paid
/// coaching relationship with measured progress — never a claim that the
/// coach caused the result.
public struct ConsentView: View {
    @State private var viewModel: ConsentViewModel

    public init(viewModel: ConsentViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                toggleCard
                explainerCard
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Share progress")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Verified journeys")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    Toggle(isOn: consentBinding) {
                        VStack(alignment: .leading, spacing: Spacing.space1) {
                            Text("Share my progress")
                                .ascendType(.headline)
                                .foregroundStyle(Color.Ascend.textPrimary)
                            Text("Lets your tracked measurements count toward your coach's verified journeys.")
                                .ascendType(.footnote)
                                .foregroundStyle(Color.Ascend.textSecondary)
                        }
                    }
                    .tint(Color.Ascend.success)
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.danger)
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var consentBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isGranted },
            set: { granted in Task { await viewModel.setGranted(granted) } }
        )
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("How this works")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    explainerRow(
                        systemImage: "person.2.badge.gearshape",
                        text: "A verified journey only exists once you've had a real, established coaching relationship."
                    )
                    explainerRow(
                        systemImage: "checkmark.circle",
                        text: "It also needs a completed, paid session and at least two measurements over time."
                    )
                    explainerRow(
                        systemImage: "eye.slash",
                        text: "Journeys are shown anonymously — your name is never attached."
                    )
                    explainerRow(
                        systemImage: "arrow.uturn.backward",
                        text: "You can turn this off at any time; it stops new journeys immediately."
                    )
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func explainerRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.Ascend.verified)
                .frame(width: 20)
            Text(text)
                .ascendType(.footnote)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }
}

#Preview("ConsentView - Light") {
    ConsentPreview()
        .preferredColorScheme(.light)
}

#Preview("ConsentView - Dark") {
    ConsentPreview()
        .preferredColorScheme(.dark)
}

private struct ConsentPreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        NavigationStack {
            ConsentView(viewModel: ConsentViewModel(backend: backend, engagementID: backend.engagementAID))
        }
    }
}
