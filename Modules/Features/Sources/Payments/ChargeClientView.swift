import DesignSystem
import Domain
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A `.sheet`-presented flow for charging a client for a session or
/// package: pick which client to bill, then pick one of the coach's own
/// service prices (quick-select) or type a custom amount, and charge it
/// through `ChargeClientViewModel.charge()`.
public struct ChargeClientView: View {
    @State private var viewModel: ChargeClientViewModel
    @Environment(\.dismiss) private var dismiss
    private let onCharged: () -> Void

    public init(viewModel: ChargeClientViewModel, onCharged: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onCharged = onCharged
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                            .padding(.horizontal, Spacing.space4)
                    }
                    clientSection
                    amountSection
                    if let chargeErrorMessage = viewModel.chargeErrorMessage {
                        Text(chargeErrorMessage)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.danger)
                            .padding(.horizontal, Spacing.space4)
                    }
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Charge client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton("Charge", isEnabled: viewModel.isValid, isLoading: viewModel.isCharging) {
                    Task {
                        if await viewModel.charge() != nil {
                            fireSuccessHaptic()
                            onCharged()
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

    // MARK: - Sections

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Client")
            Card {
                if viewModel.engagementOptions.isEmpty {
                    Text("No clients yet.")
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                } else {
                    Picker("Client", selection: $viewModel.selectedEngagementID) {
                        ForEach(viewModel.engagementOptions) { option in
                            Text(option.clientName).tag(Optional(option.engagementID))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Amount")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    AscendTextField(placeholder: "e.g. 120.00", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                    if !viewModel.services.isEmpty {
                        servicesQuickSelect
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var servicesQuickSelect: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.space2) {
                ForEach(viewModel.services) { service in
                    Chip(
                        "\(service.title) · $\(ChargeClientViewModel.displayString(forCents: service.priceCents))",
                        style: .filter(isSelected: false)
                    ) {
                        viewModel.selectService(service)
                    }
                }
            }
        }
    }

    /// A light success haptic on charge, mirroring `LogProgressView`. Lives
    /// in the view (not the view model) so no test path ever touches
    /// `UIFeedbackGenerator`.
    private func fireSuccessHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview("ChargeClientView - Light") {
    ChargeClientPreview()
        .preferredColorScheme(.light)
}

#Preview("ChargeClientView - Dark") {
    ChargeClientPreview()
        .preferredColorScheme(.dark)
}

private struct ChargeClientPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        Text("Charge client preview")
            .sheet(isPresented: .constant(true)) {
                ChargeClientView(viewModel: ChargeClientViewModel(backend: backend, professionalID: professionalID))
            }
    }
}
