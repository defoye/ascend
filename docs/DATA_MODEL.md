# Data Model

Authoritative field spec for the `Domain` module. Prompt 1 implements this.
All types are `Codable`, `Sendable`, `Hashable`, and `Identifiable` where they carry
an `id`.

## Identifier

`Identifier<Entity>` — a phantom-typed `UUID` wrapper. **Not** named `ID`, because
that collides with `Identifiable.ID`. Codable as a bare string. `Hashable`,
`Sendable`.

## People & goals

- `Person(id, displayName, roles: Set<PersonRole>, goals: [Goal])`
- `PersonRole { consumer, professional }`
- `Goal(id, kind: GoalKind, metric: MetricKind?, target: MetricValue?, deadline: Date?)`
- `GoalKind { loseWeight, buildMuscle, getStronger, improveMobility,
  recoverFromInjury, trainForSport, improveEndurance, generalHealth }`

## Professional profile & services

- `ProfessionalProfile(id, personID, displayName, headline, bio, services: [Service],
  verifications: [Verification])`
- `ServiceCategory { strengthTraining, weightLoss, mobility, running,
  sportsPerformance, yoga, pilates, physicalTherapy, generalFitness }`
- `Service(id, category, title, priceCents, currency, modality: Modality)`
  - `Modality { inPerson, virtual, hybrid }`
- `Verification(id, kind: VerificationKind, status: VerificationStatus,
  evidenceURL: URL?)`
  - `VerificationKind { identity, certification, insurance }`
  - `VerificationStatus { unverified, pending, verified, rejected }`

## Engagement & sessions

- `Engagement(id, clientID, professionalID, status: EngagementStatus,
  startedAt: Date?, endedAt: Date?)`
  - `EngagementStatus { pending, active, paused, completed, ended }`
  - `isEstablished`: `startedAt != nil && status != .pending`
- `Session(id, engagementID, scheduledAt, status: SessionStatus)`
  - `SessionStatus { scheduled, completed, cancelled, noShow }`

## Programs

- `Program(id, authorID, title, summary, weeks: [ProgramWeek])`
- `ProgramWeek(id, index, workouts: [Workout])`
- `Workout(id, name, exercises: [ExercisePrescription])`
- `ExercisePrescription(id, exercise: Exercise, sets: Int, reps: String, notes: String?)`
- `Exercise(id, name)`
- `ProgramAssignment(id, programID, engagementID, assignedAt, startDate)`

## Metrics & progress

- `MetricKind { bodyweight, waistCircumference, squat1RM, bench1RM, deadlift1RM,
  bodyFatPercentage, restingHeartRate, fiveKTime }` — carries
  `lowerIsGenerallyBetter: Bool`.
- `MetricValue(value: Double, unit: MetricUnit)`
  - `MetricUnit { lb, kg, inch, cm, percent, bpm, seconds }`
- `ProgressEntry(id, engagementID, metric: MetricKind, value: MetricValue,
  recordedAt, source: ProgressSource)`
  - `ProgressSource { clientSelfReported, coachRecorded, inAppMeasured }`

## Messaging & payments

- `Message(id, engagementID, authorID: Identifier<Person>, body, sentAt)`
- `Payment(id, engagementID, amountCents, currency, status: PaymentStatus,
  platformFeeCents, stripePaymentIntentID: String?, createdAt: Date)`
  - `PaymentStatus { pending, succeeded, refunded, failed }`
  - the coach's net for a `.succeeded` payment is `amountCents - platformFeeCents`

## Verified outcomes — the core invariant

- `VerificationBasis(relationshipVerified, activityVerified, paymentVerified,
  consentGranted)` — `isFullyVerified` is true iff all four hold.
- `VerifiedOutcome(id, engagementID, metric: MetricKind, start: MetricValue,
  end: MetricValue, startedAt, endedAt, basis: VerificationBasis)`

  **No public initializer.** The only way to construct a `VerifiedOutcome` is:

  ```swift
  static func derive(
      from engagement: Engagement,
      metric: MetricKind,
      progress: [ProgressEntry],
      completedSessions: [Session],
      payments: [Payment],
      clientConsent: Bool
  ) -> VerifiedOutcome?
  ```

  Returns `nil` unless **all** of the following hold:
  - the relationship is established (`engagement.isEstablished`),
  - at least one session is `.completed`,
  - at least one payment is `.succeeded`,
  - `clientConsent == true`,
  - there are **at least 2 time-separated** `ProgressEntry` values for `metric`.

  Exposes:
  - `delta`: `end.value - start.value` (in `start`'s unit).
  - `isImprovement`: uses the metric's `lowerIsGenerallyBetter` to interpret `delta`
    correctly (e.g. a lower `fiveKTime` is an improvement; a higher `squat1RM` is).
  - `durationDays`: whole days between `startedAt` and `endedAt`.

This is Invariant 1 from docs/PRODUCT.md, enforced structurally: there is no code
path in the entire app that can construct a `VerifiedOutcome` without going through
`derive`.
