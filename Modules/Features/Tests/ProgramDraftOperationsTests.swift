import Domain
import Foundation
import Testing
@testable import Features

@Suite("ProgramDraft operations (pure, no backend)")
struct ProgramDraftOperationsTests {
    @Test("addWeek appends a single empty week")
    func addWeekAppends() {
        let result = ProgramDraftOperations.addWeek([])
        #expect(result.count == 1)
        #expect(result[0].workouts.isEmpty)

        let resultTwo = ProgramDraftOperations.addWeek(result)
        #expect(resultTwo.count == 2)
    }

    @Test("duplicateWeek deep-copies the week, its workouts, and their prescriptions with fresh identifiers")
    func duplicateWeekDeepCopies() {
        let exercise = Exercise(id: Identifier(), name: "Back Squat")
        let prescription = ExercisePrescriptionDraft(exercise: exercise, sets: 5, reps: "5", notes: "Go heavy")
        let workout = WorkoutDraft(name: "Lower Body", exercises: [prescription])
        let week = ProgramWeekDraft(workouts: [workout])

        let result = ProgramDraftOperations.duplicateWeek([week], at: 0)

        #expect(result.count == 2)
        #expect(result[0].id == week.id)

        let duplicate = result[1]
        #expect(duplicate.id != week.id)
        #expect(duplicate.workouts.count == 1)
        #expect(duplicate.workouts[0].id != workout.id)
        #expect(duplicate.workouts[0].name == "Lower Body")
        #expect(duplicate.workouts[0].exercises.count == 1)
        #expect(duplicate.workouts[0].exercises[0].id != prescription.id)
        #expect(duplicate.workouts[0].exercises[0].exercise == exercise)
        #expect(duplicate.workouts[0].exercises[0].sets == 5)
        #expect(duplicate.workouts[0].exercises[0].reps == "5")
        #expect(duplicate.workouts[0].exercises[0].notes == "Go heavy")
    }

    @Test("duplicateWeek is a no-op for an out-of-range index")
    func duplicateWeekOutOfRangeIsNoOp() {
        let weeks = [ProgramWeekDraft()]
        let result = ProgramDraftOperations.duplicateWeek(weeks, at: 5)
        #expect(result.count == 1)
    }

    @Test("delete removes items at the given offsets")
    func deleteRemovesAtOffsets() {
        let weeks = [ProgramWeekDraft(), ProgramWeekDraft(), ProgramWeekDraft()]
        let result = ProgramDraftOperations.delete(weeks, at: IndexSet(integer: 1))
        #expect(result.count == 2)
        #expect(result[0].id == weeks[0].id)
        #expect(result[1].id == weeks[2].id)
    }

    @Test("move reorders items from source to destination")
    func moveReordersItems() {
        let weekA = ProgramWeekDraft()
        let weekB = ProgramWeekDraft()
        let weekC = ProgramWeekDraft()
        let result = ProgramDraftOperations.move([weekA, weekB, weekC], from: IndexSet(integer: 2), to: 0)
        #expect(result.map(\.id) == [weekC.id, weekA.id, weekB.id])
    }

    @Test("makeProgram renumbers week index 0-based contiguous from display order after delete + duplicate")
    func makeProgramRenumbersIndices() {
        var draft = ProgramDraft(authorID: Identifier(), title: "Test Program", summary: "")
        draft.weeks = ProgramDraftOperations.addWeek(draft.weeks)
        draft.weeks = ProgramDraftOperations.addWeek(draft.weeks)
        draft.weeks = ProgramDraftOperations.addWeek(draft.weeks)
        draft.weeks = ProgramDraftOperations.delete(draft.weeks, at: IndexSet(integer: 0))
        draft.weeks = ProgramDraftOperations.duplicateWeek(draft.weeks, at: 0)

        let program = draft.makeProgram()

        #expect(program.weeks.count == 3)
        #expect(program.weeks.map(\.index) == [0, 1, 2])
    }

    @Test("a loaded program's draft round-trips week order via index and back to contiguous indices on save")
    func draftRoundTripsExistingProgramOrder() {
        let weekA = ProgramWeek(id: Identifier(), index: 0, workouts: [])
        let weekB = ProgramWeek(id: Identifier(), index: 1, workouts: [])
        let program = Program(id: Identifier(), authorID: Identifier(), title: "Existing", summary: "", weeks: [weekB, weekA])

        let draft = ProgramDraft(program: program)
        #expect(draft.weeks.map(\.id) == [weekA.id, weekB.id])

        let rebuilt = draft.makeProgram()
        #expect(rebuilt.weeks.first { $0.id == weekA.id }?.index == 0)
        #expect(rebuilt.weeks.first { $0.id == weekB.id }?.index == 1)
    }
}

@Suite("ExerciseLibrary aggregation")
struct ExerciseLibraryTests {
    @Test("aggregate dedups by case-insensitive name and sorts alphabetically")
    func aggregateDedupsAndSorts() {
        let squatA = Exercise(id: Identifier(), name: "Back Squat")
        let squatB = Exercise(id: Identifier(), name: "back squat")
        let bench = Exercise(id: Identifier(), name: "Bench Press")
        let program = Program(
            id: Identifier(),
            authorID: Identifier(),
            title: "P",
            summary: "",
            weeks: [
                ProgramWeek(
                    id: Identifier(),
                    index: 0,
                    workouts: [
                        Workout(
                            id: Identifier(),
                            name: "W",
                            exercises: [
                                ExercisePrescription(id: Identifier(), exercise: bench, sets: 3, reps: "10", notes: nil),
                                ExercisePrescription(id: Identifier(), exercise: squatA, sets: 5, reps: "5", notes: nil),
                                ExercisePrescription(id: Identifier(), exercise: squatB, sets: 3, reps: "8", notes: nil)
                            ]
                        )
                    ]
                )
            ]
        )

        let library = ExerciseLibrary.aggregate(from: [program])

        #expect(library.count == 2)
        #expect(library.map(\.name) == ["Back Squat", "Bench Press"])
    }
}
