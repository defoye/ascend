import DataInterfaces
import DesignSystem
import Domain

/// Namespace placeholder for the Ascend Features module.
///
/// Features contains SwiftUI screens and @MainActor @Observable view models.
/// It depends on DesignSystem, DataInterfaces, and Domain only — never on a
/// concrete backend adapter (InMemoryStore, SupabaseBackend, ...). The App
/// target is the sole composition root that wires a backend in.
/// See docs/ARCHITECTURE.md.
public enum Features {}
