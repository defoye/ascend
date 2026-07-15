#if DEBUG

import DesignSystem
import Domain
import SwiftUI

/// The demo harness's discoverable entry point: a small wrench button that
/// floats in the bottom-right corner of every DEBUG launch, whether or not
/// demo mode is currently on — tapping it always opens the control panel,
/// whose first control is the on/off switch itself (see docs/TESTABILITY.md
/// "How to use it").
struct DemoLauncherButton: View {
    let demoModeStore: DemoModeStore
    let harnessState: DemoHarnessState
    @Binding var activeRole: PersonRole
    @State private var showingPanel = false

    var body: some View {
        Button {
            showingPanel = true
        } label: {
            Image(systemName: demoModeStore.isEnabled ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Ascend.onPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(demoModeStore.isEnabled ? Color.Ascend.primary : Color.Ascend.textTertiary))
                .shadow(radius: 4)
        }
        .padding(Spacing.space4)
        .accessibilityLabel(demoModeStore.isEnabled ? "Demo mode is on. Open demo controls." : "Open demo mode controls")
        .accessibilityIdentifier("demoLauncherButton")
        .sheet(isPresented: $showingPanel) {
            DemoControlPanelView(demoModeStore: demoModeStore, harnessState: harnessState, activeRole: $activeRole)
        }
    }
}

#endif
