import DesignSystem
import Domain
import SwiftUI

/// STUB: a minimal client-facing "pay for a service" screen. No real card
/// entry — this exists to prove the client side of `PaymentGateway` works
/// end-to-end (mock charge -> succeeded state), not as a finished consumer
/// payment UI (see `ClientPayViewModel`).
public struct ClientPayView: View {
    @State private var viewModel: ClientPayViewModel

    public init(viewModel: ClientPayViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                serviceCard
                if viewModel.isPaid {
                    confirmationCard
                } else {
                    payButton
                }
                if let payErrorMessage = viewModel.payErrorMessage {
                    Text(payErrorMessage)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.danger)
                        .padding(.horizontal, Spacing.space4)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Pay")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Service")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text(viewModel.service.title)
                        .ascendType(.title3)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    Text(priceLabel)
                        .ascendType(.statMedium)
                        .foregroundStyle(Color.Ascend.textPrimary)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var priceLabel: String {
        "$\(String(format: "%.2f", Double(viewModel.service.priceCents) / 100)) \(viewModel.service.currency)"
    }

    private var payButton: some View {
        AscendButton("Pay \(priceLabel)", isLoading: viewModel.isPaying) {
            Task { await viewModel.pay() }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var confirmationCard: some View {
        Card {
            EmptyState(
                systemImage: "checkmark.circle.fill",
                title: "Payment successful",
                message: "Your payment for \(viewModel.service.title) has been received."
            )
        }
        .padding(.horizontal, Spacing.space4)
    }
}

#Preview("ClientPayView - Light") {
    ClientPayPreview()
        .preferredColorScheme(.light)
}

#Preview("ClientPayView - Dark") {
    ClientPayPreview()
        .preferredColorScheme(.dark)
}

private struct ClientPayPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        let service = Service(
            id: Identifier(),
            category: .strengthTraining,
            title: "1:1 Strength Coaching",
            priceCents: 15_000,
            currency: "USD",
            modality: .hybrid
        )
        NavigationStack {
            ClientPayView(viewModel: ClientPayViewModel(backend: backend, engagementID: backend.engagementAID, service: service))
        }
    }
}
