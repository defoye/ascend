import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's "Proof Profile": verification badges, aggregate practice
/// stats, anonymized verified journeys, and a plain-language explainer of
/// how verification works (see docs/design/DESIGN_SPEC.md §1, §3).
///
/// Every journey on this screen is exactly what `Domain.VerifiedOutcome.derive`
/// yielded for this professional — there is no other path to a journey
/// appearing here (Invariant 1), and every journey's copy describes a
/// measured change over a real relationship, never a caused result
/// (Invariant 2, docs/PRODUCT.md).
public struct ProofProfileView: View {
    @State private var viewModel: ProofProfileViewModel

    public init(viewModel: ProofProfileViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                headerSection
                verificationSection
                statsSection
                explainerSection
                journeysSection
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Proof Profile")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        Card {
            HStack(spacing: Spacing.space3) {
                Avatar(name: viewModel.displayName, size: .lg, showsVerifiedBadge: hasAnyVerified)
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text(viewModel.displayName)
                        .ascendType(.title3)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    if !viewModel.headline.isEmpty {
                        Text(viewModel.headline)
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var hasAnyVerified: Bool {
        viewModel.verifications.contains { $0.status == .verified }
    }

    // MARK: - Verification chips

    @ViewBuilder
    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Verification")
            if viewModel.verifications.isEmpty {
                Card {
                    Text("No verifications on file yet.")
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.space2) {
                        ForEach(viewModel.verifications) { verification in
                            VerificationChip(verification: verification)
                        }
                    }
                    .padding(.horizontal, Spacing.space4)
                }
            }
        }
    }

    // MARK: - Aggregate stats

    private var statColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Practice stats")
            LazyVGrid(columns: statColumns, spacing: Spacing.space3) {
                StatTile(label: "Sessions", value: "\(viewModel.stats.sessionsCompleted)")
                StatTile(label: "Active clients", value: "\(viewModel.stats.activeClients)")
                StatTile(label: "Retention", value: retentionValue, unit: viewModel.stats.retentionRate == nil ? nil : "%")
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var retentionValue: String {
        guard let retentionRate = viewModel.stats.retentionRate else { return "—" }
        return "\(Int((retentionRate * 100).rounded()))"
    }

    // MARK: - How verification works

    @ViewBuilder
    private var explainerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(viewModel.paymentsMode == .live ? "How verification works" : "How Tracked results work")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    Text(explainerIntro)
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                    ForEach(explainerPoints, id: \.self) { point in
                        HStack(alignment: .top, spacing: Spacing.space2) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.Ascend.verified)
                                .accessibilityHidden(true)
                            Text(point)
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var explainerIntro: String {
        switch viewModel.paymentsMode {
        case .live: "A journey only appears here once every one of these is true:"
        case .free: "A tracked result appears here once every one of these is true:"
        }
    }

    /// The four non-payment pillars are identical to `VerifiedOutcome.derive`'s
    /// in both modes (see docs/DATA_MODEL.md) — only the payment pillar's
    /// framing changes: in `.live` it's a requirement already satisfied by
    /// every journey shown; in `.free` it's named as what upgrades a Tracked
    /// result to "Verified" once payments are turned on (Option B, see
    /// docs/BUILD_STATUS.md "Rollout strategy — free first, monetize later").
    private var explainerPoints: [String] {
        switch viewModel.paymentsMode {
        case .live:
            [
                "An established, ongoing coaching relationship",
                "At least one completed session together",
                "At least one succeeded payment",
                "The client's explicit consent to share their journey",
                "Two or more measurements of the same metric, recorded over time"
            ]
        case .free:
            [
                "An established, ongoing coaching relationship",
                "At least one completed session together",
                "The client's explicit consent to share their journey",
                "Two or more measurements of the same metric, recorded over time",
                "A completed payment — activates the \u{201C}Verified\u{201D} badge once payments are turned on"
            ]
        }
    }

    // MARK: - Verified journeys / Tracked results

    @ViewBuilder
    private var journeysSection: some View {
        switch viewModel.paymentsMode {
        case .live: verifiedJourneysSection
        case .free: trackedJourneysSection
        }
    }

    @ViewBuilder
    private var verifiedJourneysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Verified journeys")
            Card {
                if viewModel.journeys.isEmpty {
                    EmptyState(
                        systemImage: "checkmark.seal",
                        title: "No verified journeys yet",
                        message: "Journeys appear here once a client's progress is measured, "
                            + "paid, and consented to be shown."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.journeys.enumerated()), id: \.element.id) { index, journey in
                            if index > 0 {
                                Divider()
                            }
                            journeyRow(description: journey.description, badge: AnyView(VerifiedBadge(style: .compact)))
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    @ViewBuilder
    private var trackedJourneysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Tracked results")
            Card {
                if viewModel.trackedJourneys.isEmpty {
                    EmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No tracked results yet",
                        message: "Results appear here once a client's progress is measured "
                            + "and consented to be shown. Turn payments on to activate Verified."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.trackedJourneys.enumerated()), id: \.element.id) { index, journey in
                            if index > 0 {
                                Divider()
                            }
                            journeyRow(description: journey.description, badge: AnyView(TrackedBadge()))
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func journeyRow(description: String, badge: AnyView) -> some View {
        HStack(spacing: Spacing.space3) {
            badge
            Text(description)
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.space2)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// A small verification pill: a filled dot colored by `VerificationStatus`,
/// the verification kind's label, and the status word.
private struct VerificationChip: View {
    let verification: Verification

    var body: some View {
        HStack(spacing: Spacing.space1) {
            Circle().fill(tone).frame(width: 7, height: 7)
            Text("\(verification.kind.displayName) · \(verification.status.displayName)")
        }
        .ascendType(.footnote)
        .fontWeight(.semibold)
        .foregroundStyle(Color.Ascend.textPrimary)
        .padding(.horizontal, Spacing.space3)
        .frame(height: 30)
        .background(Capsule().fill(Color.Ascend.surfaceSecondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(verification.kind.displayName), \(verification.status.displayName)")
    }

    private var tone: Color {
        switch verification.status {
        case .verified: Color.Ascend.verified
        case .pending: Color.Ascend.warning
        case .unverified: Color.Ascend.textSecondary
        case .rejected: Color.Ascend.danger
        }
    }
}

extension VerificationKind {
    var displayName: String {
        switch self {
        case .identity: "Identity"
        case .certification: "Certification"
        case .insurance: "Insurance"
        }
    }
}

extension VerificationStatus {
    var displayName: String {
        switch self {
        case .unverified: "Unverified"
        case .pending: "Pending"
        case .verified: "Verified"
        case .rejected: "Rejected"
        }
    }
}

#Preview("ProofProfileView - Live - Light") {
    ProofProfilePreview(paymentsMode: .live)
        .preferredColorScheme(.light)
}

#Preview("ProofProfileView - Live - Dark") {
    ProofProfilePreview(paymentsMode: .live)
        .preferredColorScheme(.dark)
}

#Preview("ProofProfileView - Free (Tracked) - Light") {
    ProofProfilePreview(paymentsMode: .free)
        .preferredColorScheme(.light)
}

#Preview("ProofProfileView - Free (Tracked) - Dark") {
    ProofProfilePreview(paymentsMode: .free)
        .preferredColorScheme(.dark)
}

private struct ProofProfilePreview: View {
    let paymentsMode: PaymentsMode

    var body: some View {
        let professionalID = Identifier<Person>()
        NavigationStack {
            ProofProfileView(
                viewModel: ProofProfileViewModel(
                    backend: PreviewBackend(professionalID: professionalID),
                    professionalID: professionalID,
                    paymentsMode: paymentsMode
                )
            )
        }
    }
}
