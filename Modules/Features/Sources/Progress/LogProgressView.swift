import DesignSystem
import Domain
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A `.sheet`-presented flow for logging a `ProgressEntry`: pick a metric,
/// enter a value in an appropriate unit, and a date (defaulting to now).
/// Copy stays within Invariant 2 (docs/PRODUCT.md) — this screen describes a
/// measured value at a point in time, never a claim about what caused it.
public struct LogProgressView: View {
    @State private var viewModel: LogProgressViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: LogProgressViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    metricSection
                    valueSection
                    dateSection
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
            .navigationTitle("Log progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton("Log progress", isEnabled: viewModel.isValid, isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.save() != nil {
                            fireSuccessHaptic()
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
            }
        }
    }

    // MARK: - Sections

    private var metricSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Metric")
            Card {
                Picker("Metric", selection: $viewModel.metric) {
                    ForEach(MetricKind.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .onChange(of: viewModel.metric) { _, _ in viewModel.metricChanged() }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Value")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    AscendTextField(placeholder: "e.g. 185", text: $viewModel.valueText)
                        .keyboardType(.decimalPad)
                    if viewModel.availableUnits.count > 1 {
                        Picker("Unit", selection: $viewModel.unit) {
                            ForEach(viewModel.availableUnits, id: \.self) { unit in
                                Text(unit.shortLabel).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text(viewModel.unit.shortLabel)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Date")
            Card {
                DatePicker("Date", selection: $viewModel.recordedAt, in: ...Date(), displayedComponents: [.date])
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    /// A light success haptic on save, per docs/design/DESIGN_SPEC.md §4
    /// "Logging feedback". Lives in the view (not the view model) so no
    /// test path ever touches `UIFeedbackGenerator`.
    private func fireSuccessHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview("LogProgressView - Light") {
    LogProgressPreview()
        .preferredColorScheme(.light)
}

#Preview("LogProgressView - Dark") {
    LogProgressPreview()
        .preferredColorScheme(.dark)
}

private struct LogProgressPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        Text("Log progress preview")
            .sheet(isPresented: .constant(true)) {
                LogProgressView(
                    viewModel: LogProgressViewModel(backend: backend, engagementID: backend.engagementAID)
                )
            }
    }
}
