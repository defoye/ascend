import DataInterfaces
import DesignSystem
import Domain
import Features
import InMemoryStore
import SwiftUI

/// Ascend's app entry point.
///
/// The App target is the sole composition root (see docs/ARCHITECTURE.md):
/// this is the one place that knows about a concrete backend adapter.
/// In DEBUG builds today that's `InMemoryStore`; a future Supabase adapter
/// slots in here without touching Domain, DataInterfaces, Features, or
/// DesignSystem.
@main
struct AscendApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
    }
}

/// Placeholder root view shown until Prompt 4+ wire up real screens. Reads the
/// composition root's `AppContainer` from the environment so later prompts can
/// build real screens against `container.backend` without touching this wiring.
struct RootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Text("Ascend")
            .font(.largeTitle)
            .padding()
    }
}

#Preview {
    RootView()
        .environment(AppContainer.live())
}
