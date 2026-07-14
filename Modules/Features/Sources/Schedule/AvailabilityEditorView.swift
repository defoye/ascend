import DesignSystem
import Domain
import SwiftUI

/// A `.sheet`-presented editor for the coach's weekly recurring
/// availability: a list of `AvailabilityWindow`s (add/edit via a nested
/// sheet, delete via swipe), reachable from the schedule's toolbar.
public struct AvailabilityEditorView: View {
    @State private var viewModel: AvailabilityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingWindow: AvailabilityWindow?
    @State private var showingEditor = false

    public init(viewModel: AvailabilityViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Availability")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editingWindow = nil
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add availability window")
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    AvailabilityWindowEditorSheet(window: editingWindow) { weekday, startMinute, endMinute in
                        Task {
                            if let editingWindow {
                                await viewModel.updateWindow(editingWindow, weekday: weekday, startMinute: startMinute, endMinute: endMinute)
                            } else {
                                await viewModel.addWindow(weekday: weekday, startMinute: startMinute, endMinute: endMinute)
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
                .task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.windows.isEmpty && !viewModel.isLoading {
            EmptyState(
                systemImage: "clock",
                title: "No availability set",
                message: "Add weekly windows so you (and eventually clients) know when you're generally open for sessions.",
                actionTitle: "Add window",
                action: {
                    editingWindow = nil
                    showingEditor = true
                }
            )
            .frame(maxHeight: .infinity)
            .background(Color.Ascend.background)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.danger)
                        .padding(.horizontal, Spacing.space4)
                        .padding(.top, Spacing.space2)
                }
                windowsList
            }
            .background(Color.Ascend.background)
        }
    }

    private var windowsList: some View {
        List {
            ForEach(viewModel.windows) { window in
                windowRow(window)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingWindow = window
                        showingEditor = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteWindow(window.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func windowRow(_ window: AvailabilityWindow) -> some View {
        ListRow(
            title: ScheduleFormatting.weekdaySymbol(window.weekday),
            subtitle: "\(ScheduleFormatting.timeString(fromMinutes: window.startMinute)) – \(ScheduleFormatting.timeString(fromMinutes: window.endMinute))",
            leading: { Image(systemName: "clock").foregroundStyle(Color.Ascend.primary) },
            trailing: { EmptyView() }
        )
    }
}

/// A nested sheet for adding or editing a single `AvailabilityWindow`'s
/// weekday and start/end times. `window == nil` means "adding new."
private struct AvailabilityWindowEditorSheet: View {
    let window: AvailabilityWindow?
    let onSave: (Int, Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var weekday: Int
    @State private var startTime: Date
    @State private var endTime: Date

    init(window: AvailabilityWindow?, onSave: @escaping (Int, Int, Int) -> Void) {
        self.window = window
        self.onSave = onSave
        _weekday = State(initialValue: window?.weekday ?? 2)
        _startTime = State(initialValue: ScheduleFormatting.date(fromMinutes: window?.startMinute ?? 9 * 60))
        _endTime = State(initialValue: ScheduleFormatting.date(fromMinutes: window?.endMinute ?? 17 * 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    dayPicker
                    timePickers
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle(window == nil ? "Add window" : "Edit window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(weekday, ScheduleFormatting.minutes(from: startTime), ScheduleFormatting.minutes(from: endTime))
                        dismiss()
                    }
                }
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Day")
            Card {
                Picker("Day", selection: $weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(ScheduleFormatting.weekdaySymbol(day)).tag(day)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var timePickers: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Time")
            Card {
                VStack(spacing: Spacing.space3) {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    Divider()
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("AvailabilityEditorView - Light") {
    AvailabilityEditorPreview()
        .preferredColorScheme(.light)
}

#Preview("AvailabilityEditorView - Dark") {
    AvailabilityEditorPreview()
        .preferredColorScheme(.dark)
}

private struct AvailabilityEditorPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        Text("Availability editor preview")
            .sheet(isPresented: .constant(true)) {
                AvailabilityEditorView(viewModel: AvailabilityViewModel(backend: backend, professionalID: professionalID))
            }
    }
}
