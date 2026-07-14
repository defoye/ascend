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
- [ ] **Prompt 8** — Sessions: scheduling, marking completed/cancelled/no-show.
- [ ] **Prompt 9** — Programs: authoring `Program`/`ProgramWeek`/`Workout`, and
      assigning programs to engagements.
- [ ] **Prompt 10** — Progress logging: `ProgressEntry` capture UI for coaches and
      clients, per metric.
- [ ] **Prompt 11** — Messaging: stream-first chat UI per engagement.
- [ ] **Prompt 12** — Verified Outcomes surface: showing derived outcomes on a
      provider's profile, respecting Invariant 2 (journeys, not causation) in all
      copy.
- [ ] **Prompt 13** — `SupabaseBackend` adapter implementing `DataInterfaces`
      against real Supabase tables/auth; `Config/Secrets.xcconfig` wiring; offline
      write queue per docs/BACKEND.md.
- [ ] **Prompt 14** — Payments: Stripe integration via Supabase Edge Functions
      (`Payment` lifecycle, platform fee handling); no Stripe secret keys in the app.
- [ ] **Prompt 15** — Consumer-facing discovery/marketplace surface (Phase 2 per
      docs/PRODUCT.md): browsing verified professionals and their outcomes.
- [ ] **Prompt 16** — Polish pass: accessibility audit, performance pass, error/empty
      state coverage, App Store metadata/screenshots.
