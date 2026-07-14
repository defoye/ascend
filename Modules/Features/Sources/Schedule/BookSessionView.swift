import DesignSystem
import Domain
import SwiftUI

/// A `.sheet`-presented flow for booking a new session: pick one of the
/// coach's clients (engagements) and a date/time, then confirm. Booking
/// directly creates a `.scheduled` session — there is no separate
/// "confirm" step (see `SessionTransitions`).
public struct BookSessionView: View {
    @State private var viewModel: BookSessionViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: BookSessionViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    clientPicker
                    dateTimeSection
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
            .navigationTitle("Book session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton("Book session", isEnabled: viewModel.isValid, isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.book() != nil {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
            }
            .task { await viewModel.load() }
        }
    }

    private var clientPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Client")
            Card {
                if viewModel.engagementOptions.isEmpty {
                    EmptyState(
                        systemImage: "person.2",
                        title: "No clients to book",
                        message: "Add a client first, then come back to book a session."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.engagementOptions.enumerated()), id: \.element.id) { index, option in
                            if index > 0 {
                                Divider()
                            }
                            clientRow(option)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func clientRow(_ option: BookableEngagement) -> some View {
        ListRow(
            title: option.clientName,
            action: { viewModel.selectedEngagementID = option.engagementID },
            leading: { Avatar(name: option.clientName, size: .md) },
            trailing: {
                if viewModel.selectedEngagementID == option.engagementID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.Ascend.primary)
                }
            }
        )
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Date & time")
            Card {
                DatePicker("Date & time", selection: $viewModel.scheduledAt, displayedComponents: [.date, .hourAndMinute])
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("BookSessionView - Light") {
    BookSessionPreview()
        .preferredColorScheme(.light)
}

#Preview("BookSessionView - Dark") {
    BookSessionPreview()
        .preferredColorScheme(.dark)
}

private struct BookSessionPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        Text("Book session preview")
            .sheet(isPresented: .constant(true)) {
                BookSessionView(
                    viewModel: BookSessionViewModel(
                        backend: backend,
                        professionalID: professionalID,
                        reminders: MockSessionReminderScheduler()
                    )
                )
            }
    }
}
