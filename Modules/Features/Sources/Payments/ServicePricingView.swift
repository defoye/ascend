import DesignSystem
import Domain
import SwiftUI

/// Lets a coach edit the price of each service on their `ProfessionalProfile`
/// and save the changes back through `ServicePricingViewModel.save()`.
public struct ServicePricingView: View {
    @State private var viewModel: ServicePricingViewModel
    @State private var didSave = false

    public init(viewModel: ServicePricingViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if viewModel.services.isEmpty {
                    emptyState
                } else {
                    servicesSection
                    saveButton
                }
                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.danger)
                        .padding(.horizontal, Spacing.space4)
                }
                if didSave {
                    Text("Prices saved.")
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.success)
                        .padding(.horizontal, Spacing.space4)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Services & pricing")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        Card {
            EmptyState(
                systemImage: "tag",
                title: "No services yet",
                message: "Services you offer will show up here once your profile has them."
            )
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Your services")
            VStack(spacing: Spacing.space3) {
                ForEach(viewModel.services) { service in
                    serviceRow(service)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text(service.title)
                    .ascendType(.headline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                AscendTextField(
                    label: "Price (\(service.currency))",
                    placeholder: "e.g. 120.00",
                    text: priceBinding(for: service)
                )
                .keyboardType(.decimalPad)
            }
        }
    }

    private func priceBinding(for service: Service) -> Binding<String> {
        Binding(
            get: { viewModel.draftPrices[service.id] ?? "" },
            set: { viewModel.draftPrices[service.id] = $0 }
        )
    }

    private var saveButton: some View {
        AscendButton("Save prices", isLoading: viewModel.isSaving) {
            Task {
                didSave = await viewModel.save()
            }
        }
        .padding(.horizontal, Spacing.space4)
    }
}

#Preview("ServicePricingView - Light") {
    ServicePricingPreview()
        .preferredColorScheme(.light)
}

#Preview("ServicePricingView - Dark") {
    ServicePricingPreview()
        .preferredColorScheme(.dark)
}

private struct ServicePricingPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        NavigationStack {
            ServicePricingView(
                viewModel: ServicePricingViewModel(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID)
            )
        }
    }
}
