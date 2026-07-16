import DesignSystem
import SwiftUI

// MARK: - Loading skeleton
//
// Split into an extension (rather than kept in `ProofProfileView.swift`)
// purely to stay under SwiftLint's `file_length` / `type_body_length` —
// mirrors the same split `ClientDetailView.swift`/`TodayView.swift` use.
//
// Mirrors the populated layout box-for-box — header, verification chips,
// practice stats, explainer, journeys — with neutral skeleton fills (see
// docs/design/handoff/HANDOFF_README.md §06 "Loading — skeleton not
// spinner").
extension ProofProfileView {
    var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.space6) {
            headerSkeleton
            verificationSkeleton
            statsSkeleton
            explainerSkeleton
            journeysSkeleton
        }
    }

    private var headerSkeleton: some View {
        Card {
            HStack(spacing: Spacing.space3) {
                SkeletonBlock(width: 56, height: 56, cornerRadius: Radius.pill)
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    SkeletonText(width: 140, height: 18)
                    SkeletonText(width: 180, height: 13)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var verificationSkeleton: some View {
        HStack(spacing: Spacing.space2) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonBlock(width: 110, height: 30, cornerRadius: Radius.pill)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var statsSkeleton: some View {
        LazyVGrid(columns: statColumns, spacing: Spacing.space3) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonBlock(height: 70, cornerRadius: Radius.md)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var explainerSkeleton: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                SkeletonText(width: 240, height: 13)
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: Spacing.space2) {
                        SkeletonBlock(width: 16, height: 16, cornerRadius: Radius.pill)
                        SkeletonText(width: 200, height: 13)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var journeysSkeleton: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }
                    HStack(spacing: Spacing.space3) {
                        SkeletonBlock(width: 60, height: 24, cornerRadius: Radius.pill)
                        SkeletonText(width: 200, height: 13)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Spacing.space2)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
    }
}
