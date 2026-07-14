# Build Status

A running snapshot of where the Ascend build sequence stands: what has shipped,
what is next, and what is blocked on external accounts you (the owner) must set
up. Prompt numbers follow the source build sequence (`Ascend-Build-Prompts.md`).
`docs/ROADMAP.md` remains the detailed per-prompt checklist; this file is the
at-a-glance "done / next / needs-you" view.

_Last updated: 2026-07-14 (through Prompt 12)._

## ✅ Done — shipped, built clean, tests green on `InMemoryStore` ($0, no backend)

| # | Prompt | Notes |
|---|--------|-------|
| 0 | Repo, tooling, docs, Execution Protocol | Tuist modules, dependency rule, git+GitHub |
| 1 | `Domain` data model | incl. `VerifiedOutcome.derive` + full eligibility tests |
| 2 | `DataInterfaces` repository protocols | async/throwing, `AsyncStream` live reads |
| 3 | `InMemoryStore` adapter + `MockData` + `.seeded()` | DEBUG default backend |
| 4 | `DesignSystem` foundations | colors, type, spacing, components, light/dark previews |
| 5 | Coach "Today" dashboard | upcoming sessions, activity feed, fee-aware revenue |
| 6 | Clients roster + client detail | filter/search, add-client, notes, progress |
| 7 | Program builder + assignment | nested draft tree, exercise picker |
| 8 | Scheduling & availability | session lifecycle, day/week schedule, reminders |
| 9 | Progress logging + charts | metric capture UI, per-metric charts, consent-gated photos |
| 10 | Messaging | stream-first chat UI per engagement |
| 11 | Payments behind a `PaymentGateway` protocol (mock) | `MockPaymentGateway`, coach price-set/charge/history, client pay stub, fee-aware revenue |
| 12 | Verified Outcomes surface (coach Proof Profile) | derives outcomes via `Domain.derive`, consent-respecting, journeys-not-causation copy |

> Note: `docs/ROADMAP.md` carries a stray unchecked "Prompt 10 — Progress logging
> capture UI" line that duplicates work already delivered in Prompt 9 (a
> renumbering artifact). No separate work is owed for it.

## 🔜 Next — remaining build prompts

| # | Prompt | Can be done now (by Claude) | Blocked on you |
|---|--------|------------------------------|----------------|
| 13 | `SupabaseBackend` adapter | Adapter code, SQL migrations, config wiring, build clean on `InMemoryStore` default, skippable integration test | **Supabase project** + `SUPABASE_URL`/`SUPABASE_ANON_KEY` in `Config/Secrets.xcconfig` → then the live round-trip |
| 14 | Server: Stripe Connect + edge functions | Edge-function code (TS/Deno), `SupabaseBackend`'s `PaymentGateway` wiring, outcomes view/derivation, deploy+secrets docs | **Stripe (Connect test mode) + Supabase** deploy → live charge that writes a `Payment` row |
| 15 | Consumer/client experience slice | Everything (backend-agnostic, runs on `InMemoryStore`) — client home, workout player, progress, consent, onboarding | — |
| 16 | Polish, accessibility, App Store readiness | Everything on `InMemoryStore`: a11y, error/empty states, privacy manifest, settings, Debug+Release build, full suite green, tag `v0.1.0` | **Apple Developer account** → archive + TestFlight/App Store upload |

## 🙋 What needs you (owner action items)

These gate the *live* portions of 13/14/16. The code for each lands first;
these are the steps only you can do (see `Ascend-Build-Prompts.md` §3 Runbooks A/B):

1. **Supabase project** (Runbook A) — create the project, then put `SUPABASE_URL`
   and `SUPABASE_ANON_KEY` into `Config/Secrets.xcconfig` (gitignored, never
   committed). Unblocks Prompt 13's live DB round-trip.
2. **Stripe account, Connect enabled in test mode** (Runbook B) — provides the
   test keys stored as *server-side* Supabase secrets (never in the app).
   Unblocks Prompt 14's live charge flow.
3. **Apple Developer account** — signing/provisioning for archiving and
   TestFlight/App Store upload at the end of Prompt 16.

After you complete 1 & 2, run the follow-up prompt Claude hands you to execute the
live verification and finalize `SupabaseBackend`/Stripe wiring.

## 🧪 Aside: making it easy to see & test the app end-to-end

Independent of the backend work: see `docs/E2E_TESTABILITY_PROMPT.md` — a
paste-and-go prompt to build a DEBUG-only demo/testability harness (screen
catalog, scenario + role switcher, on-demand mock-data generation, controllable
clock and payment outcomes) so the whole app can be exercised and eyeballed on
mock data with zero production constraints.
