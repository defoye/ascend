import DesignSystem
import SwiftUI

// MARK: - Verified journeys / Tracked results
//
// Split into an extension (rather than kept in `ProofProfileView.swift`)
// purely to stay under SwiftLint's `file_length` — mirrors the same split
// `ClientDetailView.swift` uses for its Progress/Notes sections.
extension ProofProfileView {
    @ViewBuilder
    var journeysSection: some View {
        switch viewModel.paymentsMode {
        case .live: verifiedJourneysSection
        case .free: trackedJourneysSection
        }
    }

    @ViewBuilder
    private var verifiedJourneysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Verified journeys")
            if viewModel.journeys.isEmpty {
                Card {
                    EmptyState(
                        systemImage: "checkmark.seal",
                        title: "No verified journeys yet",
                        message: "Journeys appear here once a client's progress is measured, "
                            + "paid, and consented to be shown.",
                        actionTitle: "Check for journeys",
                        action: { Task { await viewModel.load() } }
                    )
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                substantiationLine
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(verifiedJourneyDetails.enumerated()), id: \.element.id) { index, content in
                            if index > 0 {
                                Divider()
                            }
                            journeyRow(content: content, badge: AnyView(VerifiedBadge(style: .compact)))
                        }
                    }
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    @ViewBuilder
    private var trackedJourneysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Tracked results")
            if viewModel.trackedJourneys.isEmpty {
                Card {
                    EmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No tracked results yet",
                        message: "Results appear here once a client's progress is measured "
                            + "and consented to be shown. Turn payments on to upgrade Tracked results automatically.",
                        actionTitle: "Check for results",
                        action: { Task { await viewModel.load() } }
                    )
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                substantiationLine
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(trackedJourneyDetails.enumerated()), id: \.element.id) { index, content in
                            if index > 0 {
                                Divider()
                            }
                            journeyRow(content: content, badge: AnyView(TrackedBadge()))
                        }
                    }
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    /// The mode-appropriate substantiation line (verbatim per
    /// docs/design/CLAUDE_DESIGN_BRIEF.md), shown once above the journey
    /// list — never a per-row repeat.
    private var substantiationLine: some View {
        Text(ProofProfileCopy.substantiationLine(for: viewModel.paymentsMode))
            .ascendType(.footnote)
            .foregroundStyle(Color.Ascend.textSecondary)
            .padding(.horizontal, Spacing.space4)
            .padding(.bottom, Spacing.space2)
    }

    /// `viewModel.journeys`, paired with the anonymized detail-sheet content
    /// each row opens on tap — derived purely from `VerifiedOutcome`, never
    /// hand-authored (Invariant 1).
    private var verifiedJourneyDetails: [JourneyDetailContent] {
        viewModel.journeys.map { JourneyDetailContent.verified($0, mode: viewModel.paymentsMode) }
    }

    /// `viewModel.trackedJourneys`, paired with detail-sheet content.
    private var trackedJourneyDetails: [JourneyDetailContent] {
        viewModel.trackedJourneys.map { JourneyDetailContent.tracked($0, mode: viewModel.paymentsMode) }
    }

    /// A tappable journey row — chevron affordance opens the anonymized
    /// journey-detail sheet (docs/design/handoff/HANDOFF_README.md
    /// "Interactions & Behavior": "Proof Profile journey → journey detail
    /// sheet"). The badge itself never animates (trust marks stay still and
    /// factual, docs/design/DESIGN_SPEC.md §4).
    private func journeyRow(content: JourneyDetailContent, badge: AnyView) -> some View {
        Button {
            selectedJourney = content
        } label: {
            HStack(spacing: Spacing.space3) {
                badge
                Text(content.summaryLine)
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.Ascend.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.space2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.summaryLine)
        .accessibilityHint("Double tap to view journey detail")
        .accessibilityAddTraits(.isButton)
    }
}
