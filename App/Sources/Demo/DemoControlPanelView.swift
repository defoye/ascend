#if DEBUG

import DesignSystem
import Domain
import InMemoryStore
import SwiftUI

/// The demo harness's control panel (see docs/DEMO_HARNESS.md): the on/off
/// switch for demo mode itself, then — only once it's on — the scenario
/// switcher, role switch, clock control, payment-outcome control, and a
/// link into the screen catalog.
struct DemoControlPanelView: View {
    @Bindable var demoModeStore: DemoModeStore
    let harnessState: DemoHarnessState
    @Bindable var clockController: DemoClockController
    @Binding var activeRole: PersonRole
    @Environment(\.dismiss) private var dismiss

    init(demoModeStore: DemoModeStore, harnessState: DemoHarnessState, activeRole: Binding<PersonRole>) {
        self.demoModeStore = demoModeStore
        self.harnessState = harnessState
        clockController = harnessState.clockController
        _activeRole = activeRole
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    modeSection
                    if demoModeStore.isEnabled {
                        scenarioSection
                        roleSection
                        clockSection
                        catalogSection
                    }
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Demo Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Demo mode")
            Card {
                Toggle(isOn: $demoModeStore.isEnabled) {
                    VStack(alignment: .leading, spacing: Spacing.space1) {
                        Text("Enable demo harness")
                            .ascendType(.headline)
                            .foregroundStyle(Color.Ascend.textPrimary)
                        Text("Off by default. Persists across relaunch. DEBUG builds only — never ships in Release.")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
                .tint(Color.Ascend.primary)
                .frame(minHeight: 44)
                .accessibilityIdentifier("demoModeToggle")
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Scenario")
            Card {
                VStack(spacing: Spacing.space2) {
                    ForEach(DemoScenario.allCases) { scenario in
                        scenarioRow(scenario)
                        if scenario != DemoScenario.allCases.last {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func scenarioRow(_ scenario: DemoScenario) -> some View {
        ListRow(
            title: scenario.title,
            subtitle: scenario.subtitle,
            action: { demoModeStore.scenario = scenario },
            leading: {
                Image(systemName: demoModeStore.scenario == scenario ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(demoModeStore.scenario == scenario ? Color.Ascend.primary : Color.Ascend.textTertiary)
            },
            trailing: { EmptyView() }
        )
        .accessibilityIdentifier("scenario_\(scenario.rawValue)")
    }

    private var roleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Role")
            Card {
                Picker("Role", selection: $activeRole) {
                    Text("Coach").tag(PersonRole.professional)
                    Text("Consumer").tag(PersonRole.consumer)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var clockSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Clock")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    DatePicker(
                        "Demo date",
                        selection: $clockController.currentDate,
                        displayedComponents: [.date]
                    )
                    HStack(spacing: Spacing.space3) {
                        AscendButton("Seeded reference date", variant: .secondary, size: .compact) {
                            clockController.currentDate = InMemoryStore.referenceDate
                        }
                        AscendButton("Now", variant: .secondary, size: .compact) {
                            clockController.currentDate = Date()
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Screens")
            Card {
                if let bundle = harnessState.bundle {
                    NavigationLink {
                        DemoScreenCatalogView(bundle: bundle, clock: harnessState.clockController.clock, activeRole: $activeRole)
                    } label: {
                        ListRow(
                            title: "Screen catalog",
                            subtitle: "Jump directly into any screen/state for the active scenario",
                            leading: { Image(systemName: "square.grid.2x2").foregroundStyle(Color.Ascend.textSecondary) },
                            trailing: {
                                Image(systemName: "chevron.right").foregroundStyle(Color.Ascend.textTertiary)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack {
                        ProgressView()
                        Text("Loading scenario…")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#endif
