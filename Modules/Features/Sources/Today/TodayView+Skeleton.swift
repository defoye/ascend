import DesignSystem
import SwiftUI

// MARK: - Header, content, and loading skeleton
//
// Split into an extension (rather than kept in `TodayView.swift`) purely to
// stay under SwiftLint's `file_length` / `type_body_length` — mirrors the
// same split `ClientDetailView.swift` uses for its Progress section.
extension TodayView {
    // MARK: - Header

    /// The in-scroll "Tuesday, Jul 15 / Today" header with the coach's own
    /// avatar, replacing a plain `navigationTitle` so the date line and
    /// verified-badge avatar (see docs/design/handoff/HANDOFF_README.md §01)
    /// have room to render — a native large title has no slot for either.
    var header: some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(TodayHeaderDateFormatter.string(from: now()))
                    .ascendType(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Ascend.textSecondary)
                Text("Today")
                    .ascendType(.largeTitle)
                    .foregroundStyle(Color.Ascend.textPrimary)
            }
            Spacer(minLength: Spacing.space2)
            Avatar(name: viewModel.professionalName, size: .md, showsVerifiedBadge: true)
        }
        .padding(.horizontal, Spacing.space4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Content / loading skeleton

    @ViewBuilder
    var content: some View {
        if viewModel.isLoading {
            loadingSkeleton
        } else {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                upcomingSection
                activitySection
                if viewModel.paymentsMode == .live {
                    revenueSection
                }
            }
        }
    }

    /// Mirrors `content`'s populated layout box-for-box with neutral
    /// skeleton fills (see docs/design/handoff/HANDOFF_README.md §06
    /// "Loading — skeleton not spinner"). The static header above stays real
    /// (its date/title never depend on a fetch) — only the fetched sections
    /// skeleton.
    var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            skeletonSection(labelWidth: 90, rowCount: 2, leadingSize: 38, leadingRadius: Radius.pill, showsTrailing: true)
            skeletonSection(labelWidth: 100, rowCount: 2, leadingSize: 34, leadingRadius: Radius.sm, showsTrailing: false)
            if viewModel.paymentsMode == .live {
                revenueSkeleton
            }
        }
    }

    private func skeletonSection(
        labelWidth: CGFloat,
        rowCount: Int,
        leadingSize: CGFloat,
        leadingRadius: CGFloat,
        showsTrailing: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonText(width: labelWidth, height: 12)
                .padding(.horizontal, Spacing.space4)
                .padding(.bottom, Spacing.space2)
            Card {
                VStack(spacing: 0) {
                    ForEach(0..<rowCount, id: \.self) { index in
                        if index > 0 {
                            Divider()
                        }
                        skeletonRow(leadingSize: leadingSize, leadingRadius: leadingRadius, showsTrailing: showsTrailing)
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func skeletonRow(leadingSize: CGFloat, leadingRadius: CGFloat, showsTrailing: Bool) -> some View {
        HStack(spacing: Spacing.space3) {
            SkeletonBlock(width: leadingSize, height: leadingSize, cornerRadius: leadingRadius)
            VStack(alignment: .leading, spacing: Spacing.space2) {
                SkeletonText(width: 130, height: 13)
                SkeletonText(width: 80, height: 11)
            }
            Spacer(minLength: Spacing.space2)
            if showsTrailing {
                SkeletonText(width: 44, height: 12)
            }
        }
        .padding(.vertical, Spacing.space3)
    }

    private var revenueSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonText(width: 130, height: 12)
                .padding(.horizontal, Spacing.space4)
                .padding(.bottom, Spacing.space2)
            Card {
                SkeletonBlock(width: 120, height: 26, cornerRadius: 6)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}
