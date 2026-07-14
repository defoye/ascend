import DesignSystem
import Domain
import PhotosUI
import SwiftUI

// MARK: - Photos
//
// Split into an extension (rather than kept in `EngagementProgressView.swift`)
// purely to stay under SwiftLint's `type_body_length`/`file_length` —
// SwiftLint measures each type/extension body independently.
//
// This section is the app's one sensitive surface: progress photos. It is
// **completely absent** — no card, no count, no placeholder — whenever
// `photoConsentGranted` is `false`. There is no code path here that renders
// anything photo-related without first checking consent.
extension EngagementProgressView {
    @ViewBuilder
    var photosSection: some View {
        if viewModel.photoConsentGranted {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Progress photos")
                Card {
                    VStack(alignment: .leading, spacing: Spacing.space4) {
                        consentExplainer
                        if viewModel.photos.isEmpty {
                            Text("No photos yet.")
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textSecondary)
                        } else {
                            photoGrid
                        }
                        captureRow
                        revokeConsentButton
                    }
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    private var consentExplainer: some View {
        Text("The client has shared photo access for this engagement. Photos are private to this relationship and can be revoked at any time.")
            .ascendType(.footnote)
            .foregroundStyle(Color.Ascend.textSecondary)
    }

    private var photoGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: Spacing.space2) {
            ForEach(viewModel.photos) { photo in
                ProgressPhotoTile(photo: photo)
            }
        }
    }

    private var captureRow: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            Label("Add photo", systemImage: "plus.circle.fill")
                .ascendType(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Ascend.primary)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                // Deliberately never loads the picked item's image data —
                // `ProgressPhoto` stores an opaque reference, never bytes
                // (see docs/BACKEND.md). The picker's stable item identifier
                // is a perfectly good reference for the in-memory/mock path;
                // a real backend would instead reference a signed upload URL
                // returned after uploading the asset out-of-band.
                await viewModel.addPhoto(reference: newItem.itemIdentifier ?? UUID().uuidString)
                photoPickerItem = nil
            }
        }
    }

    @ViewBuilder
    private var revokeConsentButton: some View {
        AscendButton("Turn off photo sharing", variant: .secondary, size: .compact) {
            Task { await viewModel.setPhotoConsent(false) }
        }
    }
}

/// A placeholder tile for a `ProgressPhoto`: `InMemoryStore` has no real photo
/// assets, so this renders a deterministic symbol/color keyed by the photo's
/// `reference` rather than decoding any image data.
private struct ProgressPhotoTile: View {
    let photo: ProgressPhoto

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            .fill(tileColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(systemName: "photo.fill")
                    .foregroundStyle(.white)
            )
            .accessibilityLabel("Progress photo from \(photo.capturedAt.formatted(date: .abbreviated, time: .omitted))")
    }

    private var tileColor: Color {
        let hash = abs(photo.reference.hashValue)
        let palette: [Color] = [Color.Ascend.primary, Color.Ascend.success, Color.Ascend.warning]
        return palette[hash % palette.count]
    }
}
