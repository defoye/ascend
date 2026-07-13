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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Placeholder root view shown until Prompt 1+ wire up real screens.
struct RootView: View {
    var body: some View {
        Text("Ascend")
            .font(.largeTitle)
            .padding()
    }
}

#Preview {
    RootView()
}
