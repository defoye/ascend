import DesignSystem
import SwiftUI

// MARK: - Loading skeleton
//
// Split into an extension (rather than kept in `ClientDetailView.swift`)
// purely to stay under SwiftLint's `file_length` / `type_body_length` —
// mirrors the same split this file's siblings use for Progress/Notes.
//
// Mirrors the populated layout box-for-box — header, stat grid, chart,
// notes — with neutral skeleton fills (see docs/design/handoff/
// HANDOFF_README.md §06 "Loading — skeleton not spinner").
extension ClientDetailView {
    var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            headerSkeleton
            statGridSkeleton
            chartSkeleton
            notesSkeleton
        }
    }

    private var headerSkeleton: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.space3) {
                SkeletonBlock(width: 56, height: 56, cornerRadius: Radius.pill)
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    SkeletonText(width: 140, height: 18)
                    SkeletonText(width: 100, height: 13)
                }
                Spacer(minLength: Spacing.space2)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var statGridSkeleton: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: Spacing.space3) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonBlock(height: 78, cornerRadius: Radius.md)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var chartSkeleton: some View {
        Card {
            SkeletonBlock(height: 150, cornerRadius: Radius.sm)
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var notesSkeleton: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space2) {
                SkeletonText(width: 220, height: 13)
                SkeletonText(width: 160, height: 13)
                SkeletonText(width: 90, height: 11)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }
}
