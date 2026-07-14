import Domain
import Foundation

/// Pure, directly-testable logic behind the program builder — kept free of
/// any backend/view-model dependency (mirrors `TodaySummaries` /
/// `ClientsSummaries`; see docs/TESTING.md).
public enum ProgramDraftOperations {
    /// Appends a new, empty week.
    public static func addWeek(_ weeks: [ProgramWeekDraft]) -> [ProgramWeekDraft] {
        weeks + [ProgramWeekDraft()]
    }

    /// Inserts a deep copy (fresh ids throughout) of the week at `index`
    /// immediately after it. No-op if `index` is out of range.
    public static func duplicateWeek(_ weeks: [ProgramWeekDraft], at index: Int) -> [ProgramWeekDraft] {
        guard weeks.indices.contains(index) else { return weeks }
        var result = weeks
        result.insert(weeks[index].duplicated(), at: index + 1)
        return result
    }

    /// Removes the items at `offsets` — used for both week deletion and, via
    /// the same generic helper, workout/prescription deletion.
    public static func delete<Element>(_ items: [Element], at offsets: IndexSet) -> [Element] {
        var result = items
        result.remove(atOffsets: offsets)
        return result
    }

    /// Reorders the items, moving `source` to `destination` — used for week,
    /// workout, and prescription reordering alike.
    public static func move<Element>(_ items: [Element], from source: IndexSet, to destination: Int) -> [Element] {
        var result = items
        result.move(fromOffsets: source, toOffset: destination)
        return result
    }
}

/// Pure helper for the exercise picker's library, aggregated from the coach's
/// existing programs (see docs/DATA_MODEL.md and Prompt 7's brief — no new
/// repository or Domain type; free-text add covers exercises not yet used in
/// any program).
public enum ExerciseLibrary {
    /// Every distinct exercise (by case-insensitive name) used across
    /// `programs`, alphabetized.
    public static func aggregate(from programs: [Program]) -> [Exercise] {
        let allExercises = programs.flatMap { program in
            program.weeks.flatMap { week in
                week.workouts.flatMap { workout in
                    workout.exercises.map(\.exercise)
                }
            }
        }
        let sorted = allExercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var seenNames: Set<String> = []
        var result: [Exercise] = []
        for exercise in sorted where seenNames.insert(exercise.name.lowercased()).inserted {
            result.append(exercise)
        }
        return result
    }
}
