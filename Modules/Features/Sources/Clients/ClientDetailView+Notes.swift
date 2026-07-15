import DesignSystem
import Domain
import SwiftUI

// MARK: - Notes and message shortcut
//
// Split into their own extension file (rather than kept in
// `ClientDetailView.swift`) purely to stay under SwiftLint's `file_length` —
// SwiftLint measures each file independently, and this mirrors the same
// split `ClientDetailView.swift` already uses for its Progress section.
extension ClientDetailView {
    // MARK: - Notes

    var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Coach notes")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    if viewModel.notes.isEmpty {
                        Text("No notes yet.")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.space3) {
                            ForEach(viewModel.notes) { note in
                                noteRow(note)
                            }
                        }
                    }
                    Divider()
                    addNoteField
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    @ViewBuilder
    private func noteRow(_ note: CoachNote) -> some View {
        if editingNoteID == note.id {
            editingNoteRow(note)
        } else {
            Button {
                editingNoteID = note.id
                editingNoteText = note.body
            } label: {
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text(note.body)
                        .ascendType(.body)
                        .foregroundStyle(Color.Ascend.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text("Updated \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func editingNoteRow(_ note: CoachNote) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            AscendTextField(text: $editingNoteText)
            HStack(spacing: Spacing.space2) {
                AscendButton("Save", size: .compact) {
                    Task {
                        await viewModel.updateNote(note, body: editingNoteText)
                        editingNoteID = nil
                    }
                }
                AscendButton("Cancel", variant: .secondary, size: .compact) {
                    editingNoteID = nil
                }
            }
        }
    }

    private var addNoteField: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            AscendTextField(label: "Add a note", placeholder: "Write a private note about this client…", text: $viewModel.draftNoteBody)
            AscendButton(
                "Save note",
                variant: .secondary,
                size: .compact,
                isEnabled: !viewModel.draftNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Task { await viewModel.saveNote() }
            }
        }
    }

    // MARK: - Message shortcut

    var messageShortcut: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Messages")
            Card {
                ListRow(
                    title: "Message \(viewModel.clientName)",
                    subtitle: "Open the conversation",
                    action: { showingMessageThread = true },
                    leading: {
                        Image(systemName: "bubble.left")
                            .foregroundStyle(Color.Ascend.primary)
                    },
                    trailing: { EmptyView() }
                )
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}
