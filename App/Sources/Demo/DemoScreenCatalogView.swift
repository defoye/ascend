#if DEBUG

import DataInterfaces
import Domain
import Features
import SwiftUI

/// A flat, resolved-at-runtime list of direct jumps into the coach and
/// consumer screens (see docs/TESTABILITY.md "Screen catalog"). Entries that
/// need a specific engagement/program the active scenario doesn't have
/// simply don't appear — itself a demonstration of that scenario's empty
/// state via the screen's own tab instead.
struct DemoScreenCatalogView: View {
    let bundle: DemoBackendBundle
    let clock: @Sendable () -> Date
    @Binding var activeRole: PersonRole

    @State private var firstEngagementID: Identifier<Engagement>?
    @State private var clientEngagementID: Identifier<Engagement>?

    var body: some View {
        List {
            Section("Coach") { coachEntries }
            Section("Consumer") { consumerEntries }
        }
        .navigationTitle("Screen Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .task { await resolve() }
    }

    private func resolve() async {
        let professionalEngagements = (try? await bundle.backend.engagements.fetchEngagements(
            forProfessional: bundle.professionalID
        )) ?? []
        firstEngagementID = professionalEngagements.first?.id
        let clientEngagements = (try? await bundle.backend.engagements.fetchEngagements(forClient: bundle.clientID)) ?? []
        clientEngagementID = clientEngagements.first?.id
    }

    @ViewBuilder
    private var coachEntries: some View {
        catalogLink("Today", subtitle: "Coach dashboard") {
            TodayView(
                viewModel: TodayViewModel(backend: bundle.backend, professionalID: bundle.professionalID, paymentsMode: .live, clock: clock),
                backend: bundle.backend,
                professionalID: bundle.professionalID,
                now: clock
            )
        }
        catalogLink("Clients", subtitle: "Roster") {
            ClientsListView(
                viewModel: ClientsListViewModel(backend: bundle.backend, professionalID: bundle.professionalID, clock: clock),
                backend: bundle.backend,
                professionalID: bundle.professionalID,
                clock: clock
            )
        }
        if let firstEngagementID {
            catalogLink("Client Detail", subtitle: "First client") {
                ClientDetailView(
                    viewModel: ClientDetailViewModel(
                        backend: bundle.backend,
                        engagementID: firstEngagementID,
                        professionalID: bundle.professionalID,
                        clock: clock
                    )
                )
            }
        }
        catalogLink("Invite Client", subtitle: "Start a new engagement") {
            InviteClientView(viewModel: InviteClientViewModel(backend: bundle.backend, professionalID: bundle.professionalID))
        }
        catalogLink("Programs", subtitle: "Authored programs") {
            ProgramsListView(
                viewModel: ProgramsListViewModel(backend: bundle.backend, professionalID: bundle.professionalID),
                backend: bundle.backend,
                professionalID: bundle.professionalID
            )
        }
        catalogLink("Program Builder", subtitle: "New program") {
            ProgramBuilderView(viewModel: ProgramBuilderViewModel(backend: bundle.backend, professionalID: bundle.professionalID))
        }
        catalogLink("Schedule", subtitle: "Every session") {
            ScheduleView(
                viewModel: ScheduleViewModel(
                    backend: bundle.backend,
                    professionalID: bundle.professionalID,
                    clock: clock,
                    reminders: MockSessionReminderScheduler()
                ),
                backend: bundle.backend,
                professionalID: bundle.professionalID,
                clock: clock,
                reminders: MockSessionReminderScheduler()
            )
        }
        catalogLink("Availability", subtitle: "Recurring weekly windows") {
            AvailabilityEditorView(viewModel: AvailabilityViewModel(backend: bundle.backend, professionalID: bundle.professionalID))
        }
        catalogLink("Messages", subtitle: "Conversations") {
            ConversationsListView(
                viewModel: ConversationsListViewModel(backend: bundle.backend, professionalID: bundle.professionalID),
                backend: bundle.backend,
                professionalID: bundle.professionalID
            )
        }
        if let firstEngagementID {
            catalogLink("Message Thread", subtitle: "First conversation") {
                MessageThreadView(
                    viewModel: MessageThreadViewModel(backend: bundle.backend, engagementID: firstEngagementID, selfID: bundle.professionalID)
                )
            }
            catalogLink("Progress", subtitle: "First client's charts") {
                EngagementProgressView(viewModel: ProgressViewModel(backend: bundle.backend, engagementID: firstEngagementID))
            }
            catalogLink("Log Progress", subtitle: "Coach-recorded entry") {
                LogProgressView(viewModel: LogProgressViewModel(backend: bundle.backend, engagementID: firstEngagementID, clock: clock))
            }
        }
        catalogLink("Proof Profile", subtitle: "Verified / tracked journeys") {
            ProofProfileView(viewModel: ProofProfileViewModel(backend: bundle.backend, professionalID: bundle.professionalID, paymentsMode: .live))
        }
        catalogLink("Service Pricing", subtitle: "Business services") {
            ServicePricingView(viewModel: ServicePricingViewModel(backend: bundle.backend, professionalID: bundle.professionalID))
        }
        catalogLink("Charge Client", subtitle: "Charge flow") {
            ChargeClientView(
                viewModel: ChargeClientViewModel(backend: bundle.backend, professionalID: bundle.professionalID)
            )
        }
        catalogLink("Payment History", subtitle: "Succeeded + refunded payments") {
            PaymentHistoryView(
                viewModel: PaymentHistoryViewModel(backend: bundle.backend, professionalID: bundle.professionalID, clock: clock),
                backend: bundle.backend,
                professionalID: bundle.professionalID
            )
        }
        catalogLink("Settings", subtitle: "Coach account") {
            SettingsView(
                backend: bundle.backend,
                personID: bundle.professionalID,
                roleLabel: "Coach",
                reminderScheduler: MockSessionReminderScheduler(),
                onSwitchRole: nil
            )
        }
    }

    @ViewBuilder
    private var consumerEntries: some View {
        catalogLink("Today", subtitle: "Consumer dashboard") {
            ConsumerHomeView(
                viewModel: ConsumerHomeViewModel(backend: bundle.backend, clientID: bundle.clientID, clock: clock),
                backend: bundle.backend,
                clock: clock
            )
        }
        if let clientEngagementID {
            catalogLink("Progress", subtitle: "\"My Progress\" dashboard") {
                ClientProgressView(viewModel: ProgressViewModel(backend: bundle.backend, engagementID: clientEngagementID), clock: clock)
            }
            catalogLink("Coach Chat", subtitle: "Message thread") {
                MessageThreadView(
                    viewModel: MessageThreadViewModel(backend: bundle.backend, engagementID: clientEngagementID, selfID: bundle.clientID)
                )
            }
            catalogLink("Consent", subtitle: "Outcome-sharing consent toggle") {
                ConsentView(viewModel: ConsentViewModel(backend: bundle.backend, engagementID: clientEngagementID))
            }
            catalogLink("Onboarding", subtitle: "Goal-first intake") {
                ConsumerOnboardingView(
                    viewModel: ConsumerOnboardingViewModel(
                        backend: bundle.backend,
                        clientID: bundle.clientID,
                        engagementID: clientEngagementID,
                        clock: clock
                    )
                )
            }
        }
        catalogLink("Me", subtitle: "Consumer account") {
            ConsumerMeView(
                backend: bundle.backend,
                clientID: bundle.clientID,
                engagementID: clientEngagementID,
                clock: clock,
                paymentsMode: .live,
                onSwitchRole: nil
            )
        }
    }

    @ViewBuilder
    private func catalogLink<Destination: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#endif
