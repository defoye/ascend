import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's full payment history: an all-time platform-fee-aware revenue
/// summary (net/gross, reusing `TodaySummaries.revenueSummary`), a "Charge
/// client" entry point, and every payment across every engagement, newest
/// first, each row showing its status and (for `.succeeded` payments) the
/// coach's net.
public struct PaymentHistoryView: View {
    @State private var viewModel: PaymentHistoryViewModel
    @State private var showingChargeClient = false
    private let professionalID: Identifier<Person>
    private let backend: any Backend

    public init(viewModel: PaymentHistoryViewModel, backend: any Backend, professionalID: Identifier<Person>) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                revenueSection
                historySection
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Payments")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingChargeClient = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Charge client")
            }
        }
        .sheet(isPresented: $showingChargeClient) {
            ChargeClientView(
                viewModel: ChargeClientViewModel(backend: backend, professionalID: professionalID),
                onCharged: { Task { await viewModel.load() } }
            )
        }
    }

    // MARK: - Revenue

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("All-time revenue")
            Card {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: Spacing.space3) {
                    StatTile(label: "Net", value: dollarString(viewModel.revenueSummary.netCents))
                    StatTile(label: "Gross", value: dollarString(viewModel.revenueSummary.grossCents))
                    StatTile(label: "Payments", value: "\(viewModel.revenueSummary.count)")
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func dollarString(_ cents: Int) -> String {
        "$\(String(format: "%.2f", Double(cents) / 100))"
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("History")
            if viewModel.items.isEmpty {
                Card {
                    EmptyState(
                        systemImage: "creditcard",
                        title: "No payments yet",
                        message: "Charges you make to clients will show up here.",
                        actionTitle: "Charge client",
                        action: { showingChargeClient = true }
                    )
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            paymentRow(item)
                        }
                    }
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    private func paymentRow(_ item: PaymentHistoryItem) -> some View {
        ListRow(
            title: item.clientName,
            subtitle: item.payment.createdAt.formatted(date: .abbreviated, time: .omitted),
            leading: { EmptyView() },
            trailing: {
                VStack(alignment: .trailing, spacing: Spacing.space1) {
                    Text(dollarString(item.payment.amountCents))
                        .ascendType(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(Color.Ascend.textPrimary)
                    statusChip(item.payment.status)
                }
            }
        )
    }

    private func statusChip(_ status: PaymentStatus) -> some View {
        switch status {
        case .succeeded: Chip("Succeeded", style: .status(.active))
        case .pending: Chip("Pending", style: .status(.pending))
        case .refunded: Chip("Refunded", style: .filter(isSelected: false))
        case .failed: Chip("Failed", style: .goalTag(dotColor: Color.Ascend.danger))
        }
    }
}

#Preview("PaymentHistoryView - Light") {
    PaymentHistoryPreview()
        .preferredColorScheme(.light)
}

#Preview("PaymentHistoryView - Dark") {
    PaymentHistoryPreview()
        .preferredColorScheme(.dark)
}

private struct PaymentHistoryPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            PaymentHistoryView(
                viewModel: PaymentHistoryViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }
}
