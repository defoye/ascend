import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ProgramBuilderViewModel + AssignProgramViewModel against seeded data")
@MainActor
struct ProgramBuilderAndAssignmentTests {
    @Test("building a program (incl. a free-text exercise), saving it, and assigning it to an engagement surfaces on that engagement")
    func buildSaveAssignFlow() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first)

        // Build: title, one week, one workout, one prescription with a
        // free-text exercise not in the seeded library.
        let builderViewModel = ProgramBuilderViewModel(backend: backend, professionalID: professional.id)
        builderViewModel.draft.title = "Custom Plan"
        builderViewModel.draft.summary = "A test-built program."
        builderViewModel.addWeek()
        let weekID = try #require(builderViewModel.draft.weeks.first?.id)
        builderViewModel.addWorkout(weekID: weekID)
        let workoutID = try #require(builderViewModel.week(withID: weekID)?.workouts.first?.id)
        builderViewModel.setWorkoutName("Full Body", weekID: weekID, workoutID: workoutID)

        let freeTextExercise = Exercise(id: Identifier(), name: "Custom Sled Push")
        builderViewModel.addPrescription(freeTextExercise, weekID: weekID, workoutID: workoutID)
        let prescriptionID = try #require(
            builderViewModel.workout(weekID: weekID, workoutID: workoutID)?.exercises.first?.id
        )
        builderViewModel.updatePrescription(
            ExercisePrescriptionDraft(id: prescriptionID, exercise: freeTextExercise, sets: 4, reps: "10", notes: "Go heavy"),
            weekID: weekID,
            workoutID: workoutID
        )

        // Save: comes back through the repository with the expected nested structure.
        let saved = await builderViewModel.save()
        #expect(saved)
        #expect(builderViewModel.saveErrorMessage == nil)

        let programID = builderViewModel.draft.id
        let persisted = try #require(try await backend.programs.get(programID))
        #expect(persisted.title == "Custom Plan")
        #expect(persisted.summary == "A test-built program.")
        #expect(persisted.weeks.count == 1)
        #expect(persisted.weeks[0].index == 0)
        #expect(persisted.weeks[0].workouts.count == 1)
        #expect(persisted.weeks[0].workouts[0].name == "Full Body")
        let persistedPrescription = try #require(persisted.weeks[0].workouts[0].exercises.first)
        #expect(persistedPrescription.exercise.name == "Custom Sled Push")
        #expect(persistedPrescription.sets == 4)
        #expect(persistedPrescription.reps == "10")
        #expect(persistedPrescription.notes == "Go heavy")

        let authored = try await backend.programs.list(forAuthor: professional.id)
        #expect(authored.contains { $0.id == programID })

        // Assign: appears on the engagement's assignments with a start date.
        let assignViewModel = AssignProgramViewModel(
            backend: backend,
            professionalID: professional.id,
            engagementID: engagement.id,
            clock: { InMemoryStore.referenceDate }
        )
        await assignViewModel.load()
        assignViewModel.selectedProgramID = programID
        let startDate = InMemoryStore.referenceDate.addingTimeInterval(86_400)
        assignViewModel.startDate = startDate

        let assigned = await assignViewModel.assign()
        #expect(assigned)
        #expect(assignViewModel.saveErrorMessage == nil)

        let assignments = try await backend.programs.assignments(forEngagement: engagement.id)
        let newAssignment = try #require(assignments.first { $0.programID == programID })
        #expect(newAssignment.startDate == startDate)
        #expect(try await backend.programs.get(programID)?.id == programID)
    }

    @Test("reassigning surfaces the most recently assigned program as current on client detail")
    func reassignSurfacesNewestProgram() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first)

        let programA = Program(id: Identifier(), authorID: professional.id, title: "Program A", summary: "", weeks: [])
        let programB = Program(id: Identifier(), authorID: professional.id, title: "Program B", summary: "", weeks: [])
        _ = try await backend.programs.upsert(programA)
        _ = try await backend.programs.upsert(programB)

        let firstAssign = AssignProgramViewModel(
            backend: backend,
            professionalID: professional.id,
            engagementID: engagement.id,
            clock: { InMemoryStore.referenceDate }
        )
        firstAssign.selectedProgramID = programA.id
        #expect(await firstAssign.assign())

        let secondAssign = AssignProgramViewModel(
            backend: backend,
            professionalID: professional.id,
            engagementID: engagement.id,
            clock: { InMemoryStore.referenceDate.addingTimeInterval(60) }
        )
        secondAssign.selectedProgramID = programB.id
        #expect(await secondAssign.assign())

        let detailViewModel = ClientDetailViewModel(
            backend: backend,
            engagementID: engagement.id,
            professionalID: professional.id,
            clock: { InMemoryStore.referenceDate }
        )
        await detailViewModel.load()
        #expect(detailViewModel.program?.id == programB.id)
    }
}
