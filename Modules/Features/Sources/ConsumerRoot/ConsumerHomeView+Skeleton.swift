import DesignSystem
import SwiftUI

// MARK: - Header and loading skeleton
//
// Split into an extension (rather than kept in `ConsumerHomeView.swift`)
// purely to stay under SwiftLint's `file_length` / `type_body_length` —
// mirrors the same split `TodayView+Skeleton.swift` uses for the coach
// "Today" header.
extension ConsumerHomeView {
    // MARK: - Header

    /// The in-scroll "Wednesday, Jul 16 / Today" header with the client's
    /// own avatar (no verified badge — clients aren't verified), matching
    /// the coach "Today" header pattern in `TodayView+Skeleton.swift` (see
    /// docs/design/handoff/HANDOFF_README.md §04).
    var header: some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(TodayHeaderDateFormatter.string(from: clock()))
                    .ascendType(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Ascend.textSecondary)
                Text("Today")
                    .ascendType(.largeTitle)
                    .foregroundStyle(Color.Ascend.textPrimary)
            }
            Spacer(minLength: Spacing.space2)
            Avatar(name: viewModel.clientName, size: .md, showsVerifiedBadge: false)
        }
        .padding(.horizontal, Spacing.space4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loading skeleton

    /// Mirrors the populated layout box-for-box with neutral skeleton fills
    /// (see docs/design/handoff/HANDOFF_README.md §06 "Loading — skeleton
    /// not spinner"): the teal hero card, up-next row, coach nudge, and
    /// bodyweight chart. The header above stays real — its date/title never
    /// depend on a fetch — only the fetched sections skeleton.
    var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            heroSkeleton
            rowSkeletonSection(labelWidth: 70, leadingSize: 40)
            rowSkeletonSection(labelWidth: 110, leadingSize: 40)
            chartSkeleton
        }
    }

    private var heroSkeleton: some View {
        SkeletonCard {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                SkeletonText(width: 120, height: 11)
                SkeletonText(width: 180, height: 22)
                SkeletonText(width: 210, height: 14)
                SkeletonBlock(height: 44, cornerRadius: Radius.md)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func rowSkeletonSection(labelWidth: CGFloat, leadingSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonText(width: labelWidth, height: 12)
                .padding(.horizontal, Spacing.space4)
                .padding(.bottom, Spacing.space2)
            Card {
                HStack(spacing: Spacing.space3) {
                    SkeletonBlock(width: leadingSize, height: leadingSize, cornerRadius: Radius.pill)
                    VStack(alignment: .leading, spacing: Spacing.space2) {
                        SkeletonText(width: 130, height: 13)
                        SkeletonText(width: 90, height: 11)
                    }
                    Spacer(minLength: Spacing.space2)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var chartSkeleton: some View {
        SkeletonCard {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                SkeletonText(width: 100, height: 12)
                SkeletonText(width: 70, height: 22)
                SkeletonBlock(height: 140, cornerRadius: Radius.sm)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }
}
