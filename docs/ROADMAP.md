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
- [ ] **Prompt 6** — Services management screens (`Service` CRUD, pricing, modality).
- [ ] **Prompt 7** — Engagements: list/detail screens, starting and managing a
      client relationship (`Engagement` lifecycle).
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
