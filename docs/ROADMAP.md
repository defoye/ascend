# Roadmap

Ordered checklist of build prompts. Each prompt is dispatched per the "Execution
Protocol" in `CLAUDE.md`. Ordering after Prompt 3 is a reasonable plan, not a
contract — adjust as the product dictates.

- [x] **Prompt 0** — Project skeleton, Tuist modules, docs, CI-less build, git+GitHub.
- [x] **Prompt 1** — Implement the `Domain` data model per docs/DATA_MODEL.md,
      including `VerifiedOutcome.derive`, with full unit test coverage of its
      eligibility rules.
- [x] **Prompt 2** — `DataInterfaces` repository protocols (async/throwing,
      `AsyncStream`-based live reads; messaging built stream-first).
- [x] **Prompt 3** — `InMemoryStore` adapter implementing the repository protocols,
      plus `MockData` and `InMemoryStore.seeded()` as the default DEBUG backend.
- [x] **Prompt 4** — `DesignSystem` foundations: colors, typography, spacing, and
      core reusable components with light/dark previews.
- [x] **Prompt 5** — Coach "Today" dashboard (`TodayViewModel` + `TodayView`):
      upcoming sessions across all engagements, a recent-client-activity feed
      (progress logs + client messages, newest first), and a platform-fee-aware
      revenue snapshot (net/gross over a trailing 30-day window), each with a
      graceful empty state. Plus the coach's 5-tab scaffold (`CoachRootView`:
      Today, Clients, Programs, Messages, Profile) with placeholder screens for
      the not-yet-built tabs.
- [x] **Prompt 6** — Clients roster (`ClientsListView`/`ClientsListViewModel`):
      every engagement for the professional joined with the client's name/goal
      and a computed last-activity timestamp, filterable by `EngagementStatus`
      (chips + "All") and searchable by name, with an empty state and an
      "Add client" flow. Add-client (`AddClientView`/`AddClientViewModel`)
      creates a lightweight new `Person` + `Engagement`, or links an existing
      `.consumer` person not already engaged with this professional. Client
      detail (`ClientDetailView`/`ClientDetailViewModel`) shows a header with
      an editable engagement status, an Overview (goals + per-metric stat
      tiles), Program summary, Progress (per-metric `ProgressChart`s + recent
      entries), a Notes section, and a stubbed Message shortcut; edits
      (status, notes) write back through repositories. Added a `CoachNote`
      domain type and `NotesRepository` (`DataInterfaces`/`InMemoryStore`) to
      back the Notes section — see docs/DATA_MODEL.md.
- [x] **Prompt 7** — Program builder (`ProgramBuilderViewModel`/
      `ProgramBuilderView`): authoring a `Program`'s nested `ProgramWeek` →
      `Workout` → `ExercisePrescription` tree against a mutable `ProgramDraft`,
      with add/duplicate/delete/reorder at every level (weeks renumbered
      0-based contiguous from their display order on save) and pure,
      unit-tested draft operations (`ProgramDraftOperations`). Programs tab
      (`ProgramsListView`/`ProgramsListViewModel`) lists the coach's programs
      with an empty state and a "+" into the builder. An exercise picker
      (`ExercisePickerView`) sources a searchable library aggregated from the
      coach's existing programs (surfacing the 10 seeded exercises) plus
      free-text add for new ones. Assigning/reassigning a program to a client
      engagement, with a start date (`AssignProgramView`/
      `AssignProgramViewModel` → `ProgramRepository.assign(_:)`), is surfaced
      from client detail's Program section and refreshes
      `ClientDetailViewModel` to show the newly-assigned program.
- [x] **Prompt 8** — Sessions, scheduling, and coach availability. A pure,
      unit-tested `SessionTransitions.allowed(from:)` rule governs the
      `Session` lifecycle (`.scheduled` -> `.completed`/`.cancelled`/
      `.noShow`, each terminal): `ScheduleViewModel` applies a transition by
      building a fresh `Session` and persisting it via
      `SessionRepository.upsert(_:)` — completing a session is the "activity"
      pillar for `VerifiedOutcome.derive`, and completed sessions stay
      queryable per engagement via `fetchSessions(forEngagement:)`. A
      day/week schedule (`ScheduleView`/`ScheduleViewModel`) aggregates every
      session across all of a professional's engagements, navigable
      forward/back and centered on an injected clock (reusing
      `InMemoryStore.referenceDate` in DEBUG so seeded sessions render
      in-range), with swipe actions to complete/cancel/mark a no-show on
      `.scheduled` rows. Booking a new session
      (`BookSessionView`/`BookSessionViewModel`) picks a client engagement and
      a date/time and creates a `.scheduled` `Session`, which then appears on
      both the schedule and Today. Added a minimal `AvailabilityWindow`
      domain type and `AvailabilityRepository` (`DataInterfaces`/
      `InMemoryStore`, mirroring Prompt 6's `CoachNote`/`NotesRepository`) —
      see docs/DATA_MODEL.md — backing an availability editor
      (`AvailabilityEditorView`/`AvailabilityViewModel`) for weekly recurring
      windows, reachable from the schedule's toolbar and reflected as context
      on the day/week views. Local session reminders are scheduled behind a
      mockable `SessionReminderScheduling` protocol: a real
      `LiveSessionReminderScheduler` (`UNUserNotificationCenter`-backed) is
      the production default, and a `MockSessionReminderScheduler` spy backs
      previews and tests — booking schedules a reminder, cancelling removes
      it, and no test ever touches real notification permission. Today's
      "Upcoming sessions" section gets a "See all" action (plus a toolbar
      calendar button) pushing the full `ScheduleView` onto Today's existing
      `NavigationStack`, keeping the coach tab bar at 5 tabs.
- [x] **Prompt 9** — Progress logging + charts. `LogProgressViewModel`/
      `LogProgressView` (a `.sheet`) let a coach pick a `MetricKind`, enter a
      value in a metric-appropriate `MetricUnit` (defaulted per metric,
      overridable), and a date, then persist a `ProgressEntry` via
      `ProgressRepository.upsert(_:)` with an injectable `source` (defaults
      to `.coachRecorded`, ready for client self-logging later). A dedicated
      per-engagement Progress screen (`ProgressViewModel`/
      `EngagementProgressView` — named to avoid colliding with SwiftUI's
      `ProgressView`) subscribes to `progress.entries(forEngagement:)` live
      so newly logged entries update its charts immediately, renders one
      `ProgressChart` per tracked metric with directional deltas, and adds a
      `MetricKind` filter (chips + "All"); reachable from
      `ClientDetailView`'s Progress section via a "See all" push plus a
      "Log progress" entry point on both screens. Added consent-gated
      progress photos: a `ProgressPhoto` domain type + `ProgressPhotoRepository`
      (`DataInterfaces`/`InMemoryStore`, mirroring `ProgressRepository`) and a
      dedicated `photoConsent`/`setPhotoConsent` grant on
      `EngagementRepository`, separate from the existing outcome-derivation
      consent — see docs/DATA_MODEL.md. The Progress screen's photos section
      is completely absent (no thumbnails, no counts) whenever photo consent
      is withheld, and `ProgressViewModel` never even subscribes to photo
      data without consent; when granted, it shows placeholder photo tiles
      (`InMemoryStore` has no real assets) and a `PhotosPicker`-backed
      capture flow that stores only a reference, never image bytes.
- [ ] **Prompt 10** — Progress logging: `ProgressEntry` capture UI for coaches and
      clients, per metric.
- [x] **Prompt 11** — Messaging: stream-first chat UI per engagement.
- [x] **Prompt 12** — Verified Outcomes surface: showing derived outcomes on a
      provider's profile, respecting Invariant 2 (journeys, not causation) in all
      copy. Coach "Proof Profile" (`ProofProfileView`/`ProofProfileViewModel`),
      reachable from the Profile tab's new "Trust" section (5-tab bar
      unchanged): verification chips from the professional's `Verification`s,
      aggregate practice stats (sessions completed, active clients, retention
      over established engagements), a "How verification works" explainer of
      the four pillars + the >=2 progress-points requirement, and anonymized
      verified journeys ("Client · squat 1RM 185 → 225 lb · 4 weeks") sourced
      exclusively from `Backend.outcomes.outcomes(forProfessional:)` — whose
      only construction path is `Domain.VerifiedOutcome.derive` — so a
      consent-off engagement contributes zero journeys. Pure, unit-tested
      aggregation split into `ProofProfileSummaries` (mirroring
      `TodaySummaries`), covering stat math, journey-copy formatting (no
      client/coach names, no causal verbs), and sort order.
- [x] **Prompt 13** — `SupabaseBackend` adapter implementing `DataInterfaces`
      against real Supabase tables/auth; `Config/Secrets.xcconfig` wiring; offline
      write queue per docs/BACKEND.md. New module `SupabaseBackend` (depends
      only on `DataInterfaces`, `Domain`, and the `supabase-swift` package —
      Domain/DataInterfaces/InMemoryStore/Features stay backend-agnostic)
      implements every repository protocol plus `AuthGateway` against
      Postgres/Auth/Storage/Realtime: a generic `SupabaseTable<Row>` gateway
      backs most single-row CRUD repositories with an `OfflineWriteQueue`
      (durable, per-row-ordered, disk-backed) satisfying docs/BACKEND.md's
      offline-write-queue contract — a write attempts the network first and
      only queues on a transient (offline/timeout) failure, never on a real
      server rejection; multi-table aggregates (`ProfessionalProfile`'s
      services/verifications, `Program`'s weeks/workouts/exercise
      prescriptions) replace their children directly instead of going through
      the queue. Messaging stays stream-first via a genuine Supabase Realtime
      subscription (`postgres_changes` on `messages`); every other live view
      polls (`pollingStream`), a deliberate, documented choice. Progress
      photos store only a Storage object key, resolved to a short-lived
      signed URL on every read — never bytes, never a durable public URL.
      `OutcomeRepository` gathers evidence from Postgres and calls
      `Domain.VerifiedOutcome.derive` client-side, exactly like
      `InMemoryBackend` — the DB's `outcomes` view mirrors the same
      eligibility rules for reporting/debugging only, never a code path the
      app depends on. 12 timestamped SQL migrations
      (`Server/supabase/migrations/`) create every table plus the view and
      Storage bucket, with Row Level Security throughout: a coach sees only
      their own engagements/clients, a client sees only their own data,
      `coach_notes` are professional-only, and `progress_photos` are
      consent-gated in the database itself (mirroring
      `EngagementRepository.photoConsent`) in addition to the existing
      Features-level gate. The composition root
      (`App/Sources/AppContainer.swift`) selects `InMemoryStore.seeded()` in
      DEBUG unconditionally (zero-cost, offline, unchanged) and
      `SupabaseBackend` in Release, reading `SUPABASE_URL`/`SUPABASE_ANON_KEY`
      from Info.plist (`App/Sources/SupabaseConfig.swift`) — populated only in
      Release via `Config/Secrets.xcconfig` (`Project.swift`'s `appSettings`
      now uses per-configuration xcconfig). A separate, skippable
      `SupabaseBackendIntegrationTests` target round-trips real data when
      `ASCEND_TEST_SUPABASE_URL`/`ASCEND_TEST_SUPABASE_ANON_KEY` are present
      in the environment and no-ops cleanly otherwise — never part of the
      ordinary offline test suite. `SupabaseBackendTests` covers the
      offline-write-queue's ordering contract and Row DTO <-> Domain
      `Identifier`/snake_case mapping, pure and network-free. Debug and
      Release both build clean; the full suite (206 tests) passes with the
      integration target skipping cleanly; SwiftLint `--strict` 0 violations.
      The live DB round trip itself is the owner's follow-up — see
      docs/BUILD_STATUS.md for the exact `supabase login`/`link`/`db push`
      runbook.
- [x] **Prompt 11 (payments, mock)** — Payments behind a `PaymentGateway`
      protocol: `DataInterfaces` protocol + `MockPaymentGateway` in
      `InMemoryStore` writing `Payment` records (success/refund), coach
      price-setting/charge/payment-history + platform-fee-aware revenue, a
      client pay-screen stub, and the real Stripe Connect Express plan
      documented in docs/BACKEND.md (server work stays Prompt 14).
- [ ] **Prompt 14** — Payments: Stripe integration via Supabase Edge Functions
      (`Payment` lifecycle, platform fee handling); no Stripe secret keys in the app.
- [x] **Prompt 15** — Consumer/client experience slice, backend-agnostic and
      built entirely on `InMemoryStore` (see docs/BUILD_STATUS.md — this is
      the client-facing daily-use surface, distinct from the *discovery/
      marketplace* surface the founding vision's Phase 2 describes, which
      remains a later, deliberately deferred layer per docs/PRODUCT.md's
      provider-first sequencing). `ConsumerRootView` is a 4-tab `TabView`
      (Today, Progress, Coach, Me) per docs/design/DESIGN_SPEC.md §3,
      reachable from the App composition root's demo `DemoRole` toggle
      (`RootView` in `App/Sources/AscendApp.swift`, switchable via a
      "Switch role" row on each side's Profile/Me tab) against the same
      seeded backend as the coach side, resolved to a coherent seeded
      client (`InMemoryStore.demoClientPersonID` / `MockData.demoClientPersonID`
      — Morgan Chen: an active engagement, an assigned program, an upcoming
      session, coach messages, and consent granted). Client "Today"
      (`ConsumerHomeView`/`ConsumerHomeViewModel`) surfaces today's assigned
      workout (`ConsumerProgramSummaries.currentWorkout`, picked from the
      engagement's `ProgramAssignment` by elapsed weeks since `startDate`),
      the next upcoming session (reusing `TodaySummaries.upcomingSessions`),
      and a coach nudge (the latest coach-authored message), each with a
      graceful empty state. A workout player
      (`WorkoutPlayerView`/`WorkoutPlayerViewModel`) steps through the
      workout's `ExercisePrescription`s with per-set reps/weight logging and
      a rest timer, and "Finish workout" persists `.clientSelfReported`
      `ProgressEntry`s (bodyweight check-in, plus any barbell lift whose
      name maps to a `MetricKind` via
      `ConsumerProgramSummaries.metricKind(forExerciseNamed:)`) and
      opportunistically completes a same-day `.scheduled` `Session` via
      `SessionRepository` — the "activity" pillar `VerifiedOutcome.derive`
      needs. A "My Progress" dashboard (`ClientProgressView`) reuses
      `ProgressChart` and `ProgressViewModel` for the client's own charts
      plus milestone/streak tiles from a pure, unit-tested
      `ConsumerProgressSummaries` (current/longest logging streaks,
      per-metric deltas). Consent management (`ConsentView`/
      `ConsentViewModel`) gives the client an explicit, reversible toggle on
      `EngagementRepository.consent(for:)`/`setConsent(_:for:)` — the
      outcome-derivation grant, distinct from photo consent — and toggling
      it demonstrably flips whether `Domain.VerifiedOutcome.derive` yields
      an outcome for their engagement in both directions. Goal-first
      onboarding (`ConsumerOnboardingView`/`ConsumerOnboardingViewModel`)
      captures a structured intake (goal, experience level, injuries,
      preferences — no AI assessment, per docs/PRODUCT.md's deferred-AI
      track) that appends a real `Goal` to `Person.goals` and sends the rest
      as a summary message to the coach's thread. The "Coach" tab reuses
      `MessageThreadView` directly for the coaching thread. New tests:
      `ConsumerProgramSummariesTests`, `ConsumerProgressSummariesTests`,
      `WorkoutPlayerViewModelTests`, `ConsentEligibilityTests` (the
      Invariant-1 consent->eligibility proof, both directions),
      `ConsumerOnboardingViewModelTests`, `ConsumerHomeViewModelTests`.
- [x] **Prompt 16** — Polish, accessibility, App Store readiness. Accessibility
      sweep across the real screens (VoiceOver labels/traits, Dynamic Type via
      `.ascendType` text styles, >=44pt tap targets, reduce-motion handling on
      every animation — `AscendButton`, `WorkoutPlayerView`, and the message
      thread's auto-scroll). Error/empty/loading coverage: a reusable
      `ErrorBanner` (`DesignSystem`) now surfaces each view model's
      `loadErrorMessage`/`sendErrorMessage` inline on every list/detail screen
      instead of a misleading empty state, and view models degrade gracefully
      (no crashes) on load/write failure. App icon + launch screen + an
      `App/Resources/Assets.xcassets` catalog (1024² `AppIcon`, dynamic
      `LaunchBackground` color), wired via a `Project.swift` `resources` glob
      and `ASSETCATALOG_COMPILER_APPICON_NAME`. Privacy: a
      `PrivacyInfo.xcprivacy` manifest declaring collected data honestly
      (fitness metrics + progress photos as SENSITIVE, no tracking), a bundled
      `docs/PRIVACY_POLICY.md` + in-app `PrivacyPolicyView`, and progress
      photos confirmed still consent-gated (no regression — verified by the
      unchanged `photoConsent` gate and `ConsentEligibilityTests`).
      Analytics/crash behind a mockable `AnalyticsTracking` protocol
      (`DataInterfaces`) with an `AnalyticsEvent` enum carrying only
      ids/enums — never names/bodies/photo refs — a `NoOpAnalyticsTracker`
      Live default and a `RecordingAnalyticsTracker` spy (`InMemoryStore`),
      proven PII-free by `AnalyticsNoPIITests`. Settings screen
      (`SettingsView`/`SettingsViewModel`, reachable from both the coach
      Profile and consumer Me tabs): account, role switch, notification
      permission toggle, privacy policy, sign out, and IN-APP ACCOUNT
      DELETION via a pure, unit-tested `AccountDeletionEffect` that actually
      removes the person's data through the repositories on `InMemoryStore`
      (`AccountDeletionEffectTests`). Release build configuration builds
      clean; bundle id/version/entitlements sane. The archive + TestFlight +
      App Store Connect upload steps (which need the owner's Apple account)
      are documented in docs/BUILD_STATUS.md's owner action items — Claude
      cannot run them. Tagged `v0.1.0`.
- [x] **Prompt 17** — Real, persisted, roles-gated role switch for both-role
      people, plus a quiet cross-role "something new" indicator. `RootView`
      now persists the active `PersonRole` and gates the switcher on the
      signed-in person's actual `roles` (`RolePresenceStore` + `RoleGating`,
      App target): a single-role person is forced onto that role with no
      switcher; only a both-role person sees "Switch role". A new
      `RoleActivitySummary` service (`Features`) computes the latest inbound
      activity (messages, progress, sessions, program assignments) per role
      from the seeded `Backend`; `RootView` compares it against each role's
      persisted last-visited date to derive `otherRoleHasUpdates`, threaded
      through `CoachRootView`/`ConsumerRootView` -> `CoachProfileView`/
      `ConsumerMeView` -> `SettingsView`. The dot itself is a small filled
      `Color.Ascend.primary` circle (never the numeric red `.badge()`) —
      composited onto the Profile/Me tab icon via `DesignSystem`'s
      `TabIconWithDot` (an `ImageRenderer`-baked bitmap, since a plain
      overlay view is silently dropped by the system tab bar), and shown as
      a subtitle + dot on the shared "Switch role" row. The seeded demo
      professional (Jordan Ellis) now holds both `PersonRole`s so the
      both-role path — and the existing demo "Switch role" flow — stays
      exercised. New tests: `RoleActivitySummaryTests` (`FeaturesTests`),
      `RolePresenceStoreTests`/`RoleGatingTests` (`AscendTests`).
- [x] **Prompt 18** — Real sign-in / sign-up flow with role selection, plus
      editable roles in Settings. `AuthGateway.signUp` now carries
      `roles: Set<PersonRole>` (validated non-empty via a shared
      `AuthGatewayError.rolesRequired`); both adapters honor it — InMemoryStore
      creates the `Person` with exactly those roles, and SupabaseBackend stashes
      them in Auth `user_metadata` and reads them back when it first
      materializes the `people` row. A new `AuthView`/`AuthViewModel`
      (`Features`) replaces the old `SignedOutView` placeholder: a sign-in ↔
      sign-up toggle built from DesignSystem components (`AscendTextField` — now
      with a secure-entry variant — `AscendButton`, `ErrorBanner`), inline field
      validation, a loading state on the submit button, and a role picker
      ("Coach" -> `[.professional]`, "Training with a coach" -> `[.consumer]`,
      "Both" -> both). Wired into `RootView`'s `.signedOut` branch;
      `currentAuth` transitions the root automatically on success. Settings gains
      an "Account" affordance: a single-role person can add the role they lack
      (`SettingsViewModel.addOtherRole` -> `PersonRepository.upsert`), and
      `RootView` re-resolves role gating via a threaded `onRolesChanged` callback
      so the Prompt-17 switcher unlocks with no reinstall; a both-role person
      sees a static "Coach & client" status instead. New tests:
      `AuthViewModelTests` + `SettingsViewModelTests` (`FeaturesTests`), plus
      `signUp(roles:)` coverage (coach/client/both + empty-rejected) in
      `InMemoryStoreTests`.

## Design polish follow-ups (deferred)

Surfaced during the Claude Design polish pass (commits `9c62119`→`d9dc296`, docs/design/handoff/).
Both were deliberately **not** built in that pass because each needs a product decision
first, not more implementation — captured here so they aren't lost.

- [ ] **DP-1** — Consumer tab-bar restructure. The design canvas
      (docs/design/handoff/AscendScreens.dc.html §04) shows consumer tabs
      **Today · Workouts · Progress · Profile**, but the app ships
      **Today · Progress · Coach · Me** (`Modules/Features/Sources/ConsumerRoot`).
      Adopting the design set drops the "Coach" tab (the consumer↔coach messaging
      entry point) and "Me" (settings, sign-out, role switch) with no spec for where
      those relocate. **Decision needed before building:** where do messaging and
      account/settings live in the new tab set (e.g. messaging folded into a "Coach"
      surface reachable from Today? settings behind the Profile tab?). Left untouched
      in the polish pass rather than guess.
- [ ] **DP-2** — Workout Player one-exercise focus mode. The mockup
      (AscendScreens.dc.html §05, "EXERCISE 2 / 6") implies a one-exercise-at-a-time
      pager. The polish pass (commit `d9dc296`) added the progress header + segmented
      bar + per-set state styling on top of the **existing all-exercises scroll**
      rather than re-architect the interaction model silently. Converting
      `WorkoutPlayerView` to a true pager (swipe/advance per exercise, auto-advance
      after the last set) is the remaining, larger interaction change. **Decision
      needed:** confirm the pager model is wanted over the current scroll before the
      re-architecture.

## AI capabilities (deferred track)

Intentionally not sequenced into the phase-1 build — see the "AI: intentionally
deferred, not dropped" section of docs/PRODUCT.md for the rationale. Captured here so
the founding vision's AI surface is documented and not silently lost. These are
unordered relative to each other and will be slotted into the main sequence when we
deliberately pick AI up; most depend on the consumer discovery/marketplace surface
(Prompt 15) and/or a real backend (Prompt 13) existing first. AI is a product layer
on top of the verified-outcome substrate — it is explicitly **not** the moat.

- [ ] **AI-1** — Provider assistant: generate/draft a `Program` from a goal +
      constraints, draft client messages, and summarize an engagement's progress
      from its `ProgressEntry` history. Assistive drafts only; a human coach edits
      and owns the output.
- [ ] **AI-2** — Consumer AI goal assessment / onboarding: a guided intake that
      turns "I have back pain and want to lose 30 lbs" into structured `Goal`s +
      preferences, replacing/augmenting manual goal entry.
- [ ] **AI-3** — Consumer↔professional matching: rank professionals for a consumer
      by goals, specialty (`ServiceCategory`), availability, and **verified
      outcomes**, each recommendation carrying a human-readable "why." Depends on the
      consumer discovery surface (Prompt 15). This is the capability the vision's MVP
      philosophy ties to "prove consumers trust recommendations."
- [ ] **AI-4** — Provider marketing assistant: generate profile copy, program
      descriptions, and content. Must respect Invariant 2 (journeys, never causation)
      in all generated copy.

## Launch hardening (pre-release audit, 2026-07)

- [x] **LH-1** — Consumer role identity: Release consumer experience runs as the
      signed-in user's personID; the seeded-demo-client substitution is now a
      DEBUG-only AppContainer composition detail.
- [x] **LH-2** — Invite-based client onboarding: EngagementInvite + InviteRepository
      across all backends, coach invite-code flow replaces the RLS-doomed
      create-a-person Add Client, client claim flow on the no-coach screen.
      (Supabase SQL migration lands in LH-3.)
- [x] **LH-3** — engagement_invites migration + claim_invite security-definer RPC + RLS;
      RowCoding coverage for EngagementInviteRow. Live apply still owner's supabase db push.
- [x] **LH-4** — RLS hardening: exercises write-locked (insert-only), engagement inserts restricted to the professional, consent flips via client-only security-definer RPCs + column-guard trigger; adapter updated (exercise insert-if-absent, consent RPCs). SQL reviewed-only pending supabase db push.
- [x] **LH-5** — Connectivity resilience: MessageRepository gains a one-shot throwing fetchMessages; Today/ConsumerHome/MessageThread (and all other one-shot users) fail loudly with retryable errors instead of hanging on partial connectivity.
- [x] **LH-6** — Workout draft persistence: in-progress set logs/bodyweight/startedAt survive app termination via a Features-local WorkoutSessionDraftStoring seam (file-backed, same-day + same-workout restore gate, cleared on completion).
- [x] **LH-7** — Account deletion rework: person anonymized (never deleted — FK cascades would wipe the other party's history), engagements ended not deleted, other party's records preserved; AuthGateway.deleteAccount() destroys the auth identity via the delete-account edge function (deploy = owner action).
- [x] **LH-8** — Progress-photo UI hidden for launch (it never uploaded real bytes); Domain/repositories/Storage policies/consent plumbing kept dark for the real feature.
- [x] **LH-9** — Dark payments surface removed: charge/pay/pricing/history UI deleted, SupabaseBackend's fake gateway replaced with NoOpPaymentGateway (a live-mode charge now throws instead of fabricating a succeeded payment); PaymentsMode gating, Payment domain/repositories, and revenue reads kept.
- [x] **LH-10** — Email-confirmation sign-up flow: AuthGateway.signUp returns SignUpOutcome, the auth screen shows a check-your-email notice instead of silently doing nothing, and an unconfirmed sign-in gets a specific message. Works with confirmation on or off.
