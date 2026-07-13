import DataInterfaces
import DesignSystem
import Domain
import Foundation
import SwiftUI

/// The coach experience's public entry point: a 5-tab `TabView` per
/// docs/design/DESIGN_SPEC.md §3 (Today, Clients, Programs, Messages,
/// Profile). Today is the only real screen so far; the rest are "Coming
/// soon" placeholders that later prompts replace.
///
/// Takes only `any Backend` + the signed-in professional's identifier (and
/// an optional clock) so the App composition root can wire it without
/// Features ever depending on a concrete backend adapter.
public struct CoachRootView: View {
    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
    }

    public var body: some View {
        TabView {
            TodayView(viewModel: TodayViewModel(backend: backend, professionalID: professionalID, clock: clock), now: clock)
                .tabItem { Label("Today", systemImage: "calendar") }

            ComingSoonView(
                title: "Clients",
                systemImage: "person.2",
                message: "Your client list and their engagement details will live here."
            )
            .tabItem { Label("Clients", systemImage: "person.2") }

            ComingSoonView(
                title: "Programs",
                systemImage: "dumbbell",
                message: "Build and assign training programs to your clients here."
            )
            .tabItem { Label("Programs", systemImage: "dumbbell") }

            ComingSoonView(
                title: "Messages",
                systemImage: "bubble.left",
                message: "Message threads with your clients will live here."
            )
            .tabItem { Label("Messages", systemImage: "bubble.left") }

            ComingSoonView(
                title: "Profile",
                systemImage: "person.crop.circle",
                message: "Your professional profile, services, and verifications will live here."
            )
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Color.Ascend.primary)
    }
}

/// A titled `NavigationStack` around a friendly "Coming soon" `EmptyState`,
/// standing in for a tab whose real screen a later prompt (6, 7, 8, ...)
/// will build.
private struct ComingSoonView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            EmptyState(
                systemImage: systemImage,
                title: "\(title) coming soon",
                message: message
            )
            .frame(maxHeight: .infinity)
            .background(Color.Ascend.background)
            .navigationTitle(title)
        }
    }
}

#Preview("CoachRootView - Light") {
    CoachRootPreview()
        .preferredColorScheme(.light)
}

#Preview("CoachRootView - Dark") {
    CoachRootPreview()
        .preferredColorScheme(.dark)
}

private struct CoachRootPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        CoachRootView(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID)
    }
}
