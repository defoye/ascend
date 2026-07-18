# Data Model

Semantics for the `Domain` module that are NOT derivable from reading the
source. For field-level types themselves, read the source directly —
`Modules/Domain/Sources/` is one public type per file (e.g. `Engagement.swift`,
`VerifiedOutcome.swift`), so it can't drift out of sync with a doc the way a
copied field list can.
All types are `Codable`, `Sendable`, `Hashable`, and `Identifiable` where they carry
an `id`.

`Identifier<Entity>` is a phantom-typed `UUID` wrapper — **not** named `ID`,
because that collides with `Identifiable.ID`.

## Engagement invites — how a coaching relationship actually starts

- `EngagementInvite(id, code, professionalID, suggestedClientName: String?,
  createdAt, claimedByPersonID: Identifier<Person>?, claimedAt: Date?,
  engagementID: Identifier<Engagement>?)` — a coach-issued invite code; `isClaimed`
  is `claimedByPersonID != nil`. `suggestedClientName` is what the coach typed when
  creating the invite — display-only, never used to create or match a `Person`.

  This is the **only** way a new coaching relationship is created. A coach can
  never create another person's `Person` row directly: production Supabase RLS
  requires `people.id == auth.uid()`, so any "add client" flow that fabricates a
  client id is dead on arrival. Instead the coach creates an `EngagementInvite`
  (`EngagementInvite.generateCode()` — 8 characters from the unambiguous alphabet
  `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, no `I`/`L`/`O`/`0`/`1`), shares the code
  out-of-band, and the client claims it under their own authenticated account.

  `InviteRepository` (`DataInterfaces`) provides `createInvite(forProfessional:
  suggestedClientName:)`, `pendingInvites(forProfessional:)`,
  `revokeInvite(_:)`, and `claimInvite(code:clientID:)`; `Backend` vends it as
  `var invites: any InviteRepository`. Implemented in-memory by `InMemoryBackend`
  (`InMemoryBackend+InviteRepository.swift`, regenerating the code on the
  unlikely collision) and against Supabase by `SupabaseBackend`
  (`SupabaseBackend+InviteRepository.swift`) — see docs/BACKEND.md for the
  `engagement_invites`/`claim_invite` contract the Supabase adapter is written
  against.

  **Claim semantics**, honored identically by every backend: matching is
  case-insensitive and whitespace-trimmed (`EngagementInvite.normalize(_:)`).
  Looking up the (normalized) code throws `InviteError.invalidCode` if no
  unclaimed invite matches, `InviteError.alreadyClaimed` if it's already
  claimed, and `InviteError.cannotClaimOwnInvite` if the claimer is the invite's
  own professional. On success: a new `.active` `Engagement` is created linking
  the claimer to the invite's professional, the invite is marked claimed
  (`claimedByPersonID`/`claimedAt`/`engagementID`), and — if the claiming
  `Person` exists and lacks `.consumer` in `roles` — that role is added, since
  role-gated UI depends on `roles` being truthful.

## Programs

Field-level types (`Program`, `ProgramWeek`, `Workout`, `ExercisePrescription`,
`Exercise`, `ProgramAssignment`) live in `Modules/Domain/Sources/`; read them
there. Nothing about their semantics is non-obvious from the fields alone.

## Metrics & progress

Field-level types (`MetricKind`, `MetricValue`, `MetricUnit`, `ProgressEntry`,
`ProgressSource`) live in `Modules/Domain/Sources/`. One thing worth knowing
that isn't obvious from the fields: `MetricKind` carries a
`lowerIsGenerallyBetter: Bool` used to interpret a delta's direction correctly
(see "Verified outcomes" below).

## Progress photos — sensitive, consent-gated

- `ProgressPhoto(id, engagementID, reference: String, capturedAt, source:
  ProgressSource)` — a reference to a single progress photo. `reference` is a
  String asset identifier or URL, **never** image bytes: in production this
  maps to a signed URL into Supabase Storage; `InMemoryStore` treats it as an
  opaque key with no backing asset. `ProgressPhotoRepository`
  (`DataInterfaces`) provides `fetchPhotos(forEngagement:)`, a live
  `photos(forEngagement:) -> AsyncStream<[ProgressPhoto]>`, `upsert(_:)`, and
  `delete(_:)`; `Backend` vends it as `var progressPhotos: any
  ProgressPhotoRepository`. Implemented in-memory by `InMemoryBackend`
  (`InMemoryBackend+ProgressPhotoRepository.swift`), seeded with two photo
  references on one engagement in `MockData` (`MockData+Photos.swift`).

- Progress photos have their **own** consent grant on `EngagementRepository`,
  separate from `consent(for:)`/`setConsent(_:for:)` (which scopes only
  outcome derivation): `photoConsent(for engagementID:) async throws -> Bool`
  and `setPhotoConsent(_ granted: Bool, for engagementID:) async throws`. A
  client may share their measurement trend without ever sharing photos, or
  vice versa — the two grants are independent and both default to `false`.
  Seeded via `MockData.photoConsentByEngagement()`: exactly one engagement
  has photo consent granted, every other engagement withholds it, so the
  Progress screen's consent gate has real seeded cases on both sides. Every
  Features read path MUST check `photoConsent(for:)` before surfacing
  anything `ProgressPhotoRepository` returns — the gate lives in the caller,
  not the repository.

  UI for this feature is deferred post-launch (a pre-release audit found the
  picker never uploaded real image bytes); the data layer, Storage policies,
  and consent plumbing above ship dark for the real feature later.

## Coach notes

`CoachNote` (`Modules/Domain/Sources/CoachNote.swift`) is a coach's private
note about a client engagement, not visible to the client — the one fact not
obvious from the fields themselves. Backed by `NotesRepository`
(`DataInterfaces`), implemented in-memory by `InMemoryBackend`
(`InMemoryBackend+NotesRepository.swift`).

## Coach availability

`AvailabilityWindow` (`Modules/Domain/Sources/AvailabilityWindow.swift`) is
purely descriptive — it does **not** block booking a session outside a
window; it only gives the schedule view context for when a professional is
generally open. Backed by `AvailabilityRepository` (`DataInterfaces`),
implemented in-memory by `InMemoryBackend`
(`InMemoryBackend+AvailabilityRepository.swift`).

## Messaging & payments

Field-level types (`Message`, `Payment`, `PaymentStatus`) live in
`Modules/Domain/Sources/`. One thing worth knowing that isn't obvious from the
fields: the coach's net for a `.succeeded` payment is `amountCents -
platformFeeCents`.

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
