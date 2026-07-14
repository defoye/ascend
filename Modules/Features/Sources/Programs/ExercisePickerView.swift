import DesignSystem
import Domain
import SwiftUI

/// A searchable picker sourced from the coach's exercise library (every
/// distinct exercise used across their existing programs — see
/// `ExerciseLibrary.aggregate`). Free-text add is always available: typing a
/// name that isn't already in the library offers to create a new `Exercise`
/// on the spot (see Prompt 7's brief — no new repository/Domain type; this
/// covers exercises the library doesn't have yet).
struct ExercisePickerView: View {
    let library: [Exercise]
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredLibrary: [Exercise] {
        guard !trimmedSearch.isEmpty else { return library }
        return library.filter { $0.name.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    private var canAddFreeText: Bool {
        !trimmedSearch.isEmpty && !library.contains { $0.name.localizedCaseInsensitiveCompare(trimmedSearch) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if library.isEmpty && trimmedSearch.isEmpty {
                    EmptyState(
                        systemImage: "magnifyingglass",
                        title: "No exercises yet",
                        message: "Type a name below to add your first exercise."
                    )
                } else {
                    ForEach(filteredLibrary) { exercise in
                        ListRow(title: exercise.name, action: { select(exercise) })
                    }
                }
                if canAddFreeText {
                    ListRow(
                        title: "Add \"\(trimmedSearch)\"",
                        subtitle: "New exercise",
                        action: { select(Exercise(id: Identifier(), name: trimmedSearch)) },
                        leading: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.Ascend.primary)
                        },
                        trailing: { EmptyView() }
                    )
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search or add an exercise")
            .navigationTitle("Choose exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func select(_ exercise: Exercise) {
        onSelect(exercise)
        dismiss()
    }
}

#Preview("ExercisePickerView - Light") {
    ExercisePickerView(library: ExercisePickerPreview.library, onSelect: { _ in })
        .preferredColorScheme(.light)
}

#Preview("ExercisePickerView - Dark") {
    ExercisePickerView(library: ExercisePickerPreview.library, onSelect: { _ in })
        .preferredColorScheme(.dark)
}

private enum ExercisePickerPreview {
    static let library = [
        Exercise(id: Identifier(), name: "Back Squat"),
        Exercise(id: Identifier(), name: "Bench Press"),
        Exercise(id: Identifier(), name: "Deadlift"),
        Exercise(id: Identifier(), name: "Overhead Press")
    ]
}
