import Domain
import Foundation

extension MockData {
    struct ProgramData {
        let programs: [Program]
        let assignments: [ProgramAssignment]
    }

    static let strengthFoundationsID = Identifier<Program>(uuid(7, 0))
    static let fatLossKickstartID = Identifier<Program>(uuid(7, 1))

    // MARK: - Exercise library

    static let exerciseNames = [
        "Back Squat", "Bench Press", "Deadlift", "Overhead Press", "Barbell Row",
        "Goblet Squat", "Push-up", "Walking Lunge", "Plank", "Kettlebell Swing"
    ]

    static func exercise(_ index: Int) -> Exercise {
        Exercise(id: Identifier(uuid(11, UInt8(index))), name: exerciseNames[index])
    }

    static func prescription(
        _ exerciseIndex: Int,
        sets: Int,
        reps: String,
        notes: String? = nil,
        idSeed: UInt8
    ) -> ExercisePrescription {
        ExercisePrescription(
            id: Identifier(uuid(10, idSeed)),
            exercise: exercise(exerciseIndex),
            sets: sets,
            reps: reps,
            notes: notes
        )
    }

    // MARK: - Programs

    static func programsAndExercises() -> ProgramData {
        ProgramData(
            programs: [strengthFoundationsProgram(), fatLossKickstartProgram()],
            assignments: programAssignments()
        )
    }

    static func strengthFoundationsProgram() -> Program {
        Program(
            id: strengthFoundationsID,
            authorID: professionalPersonID,
            title: "Strength Foundations",
            summary: "An 8-week linear progression across the big compound lifts.",
            weeks: [
                ProgramWeek(
                    id: Identifier(uuid(8, 0)),
                    index: 0,
                    workouts: [
                        Workout(
                            id: Identifier(uuid(9, 0)),
                            name: "Lower Body",
                            exercises: [
                                prescription(0, sets: 5, reps: "5", idSeed: 0),
                                prescription(2, sets: 3, reps: "5", idSeed: 1)
                            ]
                        )
                    ]
                ),
                ProgramWeek(
                    id: Identifier(uuid(8, 1)),
                    index: 1,
                    workouts: [
                        Workout(
                            id: Identifier(uuid(9, 1)),
                            name: "Upper Body",
                            exercises: [
                                prescription(1, sets: 5, reps: "5", idSeed: 2),
                                prescription(4, sets: 3, reps: "8", idSeed: 3),
                                prescription(3, sets: 3, reps: "6", idSeed: 4)
                            ]
                        )
                    ]
                )
            ]
        )
    }

    static func fatLossKickstartProgram() -> Program {
        Program(
            id: fatLossKickstartID,
            authorID: professionalPersonID,
            title: "Fat Loss Kickstart",
            summary: "A 6-week full-body circuit program to build a training habit.",
            weeks: [
                ProgramWeek(
                    id: Identifier(uuid(8, 2)),
                    index: 0,
                    workouts: [
                        Workout(
                            id: Identifier(uuid(9, 2)),
                            name: "Full Body Circuit A",
                            exercises: [
                                prescription(5, sets: 3, reps: "12", idSeed: 5),
                                prescription(6, sets: 3, reps: "10", idSeed: 6),
                                prescription(9, sets: 3, reps: "15", idSeed: 7)
                            ]
                        )
                    ]
                ),
                ProgramWeek(
                    id: Identifier(uuid(8, 3)),
                    index: 1,
                    workouts: [
                        Workout(
                            id: Identifier(uuid(9, 3)),
                            name: "Full Body Circuit B",
                            exercises: [
                                prescription(7, sets: 3, reps: "12", notes: "Alternating legs", idSeed: 8),
                                prescription(8, sets: 3, reps: "45s", idSeed: 9)
                            ]
                        )
                    ]
                )
            ]
        )
    }

    static func programAssignments() -> [ProgramAssignment] {
        [
            ProgramAssignment(
                id: Identifier(uuid(12, 0)),
                programID: strengthFoundationsID,
                engagementID: engagementID(2),
                assignedAt: date(-68),
                startDate: date(-65)
            ),
            ProgramAssignment(
                id: Identifier(uuid(12, 1)),
                programID: fatLossKickstartID,
                engagementID: engagementID(1),
                assignedAt: date(-98),
                startDate: date(-95)
            ),
            ProgramAssignment(
                id: Identifier(uuid(12, 2)),
                programID: fatLossKickstartID,
                engagementID: engagementID(5),
                assignedAt: date(-198),
                startDate: date(-195)
            )
        ]
    }
}
