# Testability — a DEBUG-only demo/exploration harness

This documents the brainstorm and the shipped answer to
`docs/E2E_TESTABILITY_PROMPT.md`: how to make the whole app reachable and
exercisable on mock data, with zero production constraints, and how the
owner flips it on from inside the running app.

## PHASE 1 — Brainstorm

### Screen inventory

Every screen currently in the app, and the data states worth seeing:

| Area | Screens | Populated | Empty | Error/loading |
|---|---|---|---|---|
| Coach Today | `TodayView` | upcoming sessions, revenue, activity feed | no sessions/activity, `.free` hides revenue | load failure banner |
| Clients | `ClientsListView`, `ClientDetailView`, `AddClientView` | 8 clients across every `EngagementStatus` | zero clients | list/detail load failure |
| Programs | `ProgramsListView`, `ProgramBuilderView`, `AssignProgramView`, `ExercisePickerView` | authored programs, nested week/workout tree | zero programs | load failure |
| Schedule | `ScheduleView`, `BookSessionView`, `AvailabilityEditorView` | past + upcoming sessions, every `SessionStatus` | zero sessions | load failure |
| Progress | `EngagementProgressView`/`ClientProgressView`, `LogProgressView` | multi-point charts per metric | zero entries | load failure |
| Messaging | `ConversationsListView`, `MessageThreadView` | threads with unread counts | zero conversations | stream/send failure |
| Proof Profile | `ProofProfileView` | verified journeys (`.live`) / tracked journeys (`.free`) | zero eligible engagements | load failure |
| Payments | `ServicePricingView`, `ChargeClientView`, `PaymentHistoryView`, `ClientPayView` | succeeded + refunded payments | zero payments/services | charge failure |
| Settings | `SettingsView`, `PrivacyPolicyView` | account, role switch, notifications, deletion | — | deletion failure |
| Consumer | `ConsumerHomeView`, `WorkoutPlayerView`, `ConsumerMeView`, `ConsentView`, `ConsumerOnboardingView` | active engagement, assigned program, consent granted | no coach yet (`ConsumerRootView`'s own empty state) | load failure |

All of this already exists as a complete, tab-navigable app running on
`InMemoryStore.seeded()`. The gap isn't missing screens — it's *reaching*
the less-common states (empty, error, refunded, consent-withheld, a
brand-new coach) without hand-editing fixture code or relaunching.

### Options considered

**(a) In-app DEBUG Developer/Demo menu — a full screen catalog.**
A navigable list that constructs every screen directly, bypassing normal
taps. Reaches everything in one place, but every leaf screen needs its own
resolved IDs (engagement, program, conversation) hand-wired here *in
addition to* the wiring `CoachRootView`/`ConsumerRootView` already do —
duplicate surface that has to be kept in sync as new screens land.

**(b) A runtime scenario switcher — named `InMemoryStore`/`Backend`
fixtures swappable without relaunch.** Low surface area (a handful of
fixture-builder functions using only `Backend` protocol calls), and instead
of hand-authoring every state, it *reuses the existing seeded data's
natural variety* (`MockData` already spans every `EngagementStatus`, a
consent-withheld client, and multiple metrics) plus small protocol-level
patches (e.g. one real `PaymentGateway.refund` call) to fill the remaining
gaps.

**(c) A role switcher (coach ↔ consumer).** Already exists
(`DemoRole` in `AscendApp.swift`, wired into both roots' "Switch role"
affordance) — reuse it rather than re-invent it.

**(d) Exposing the injectable clock and `MockPaymentGateway` outcome as
live controls.** Needed for anything time-based (upcoming vs. past
sessions) and for exercising charge/refund/decline UI deterministically.
Both are small, targeted decorators over the existing seams
(`@Sendable () -> Date` closures, `PaymentGateway`) — no protocol changes.

**(e) A general mock-data generator/factory for arbitrary graphs.**
Powerful but large surface area (a mini fixture DSL) for marginal benefit
over (b): the seeded fixture already covers nearly every state the product
cares about; only a couple of gaps (a refunded payment, a from-scratch
empty coach) need bespoke construction, and both are cheap to write as
one-off scenario builders instead of a general generator.

**(f) Comprehensive SwiftUI Previews / snapshot tests.** Already the norm
per `docs/CONVENTIONS.md` (every component ships light/dark previews) and
a good second net, but previews don't let *the owner* poke at the running
app on a simulator, switch scenarios live, or force a payment outcome —
doesn't satisfy the "launch it and drive it" requirement on its own.

### Recommendation

**(b) scenario switcher + (c) role switch + (d) live clock/payment
controls, wired through the app's own tab navigation, plus a lightweight
screen catalog ((a), trimmed) for the handful of flows that sit a few taps
deep or need a specific resolved id.** This is the combination that reaches
the most UI for the least new surface area: the existing `CoachRootView`/
`ConsumerRootView` tab bars already reach nearly every top-level screen, so
switching *scenario* and *role* underneath them — rather than
reimplementing navigation to each leaf screen — gets most of the coverage
for free and keeps working as later prompts add screens (a new tab or a new
`NavigationLink` inside an existing screen is automatically in scope; only
genuinely new *roots* need a new catalog entry). The screen catalog fills
the small remaining gap: `AddClientView`, `ProgramBuilderView` (new),
`ChargeClientView`, `PaymentHistoryView`, `ConsentView`, and a few others
that aren't a root tab and benefit from a direct jump.

## What shipped (PHASE 2)

### The toggle

- A small circular button (wrench icon) floats in the bottom-right corner
  of the app in **every DEBUG build**, regardless of whether demo mode is
  on — this is the discoverable affordance the E2E prompt requires. Tap it
  to open **Demo Mode**.
- The very first control is an **on/off switch** for demo mode itself,
  default **off**. Its state is written to `UserDefaults` (`com.ascend.demo.isEnabled`)
  on every change, so it survives a relaunch: flip it on, quit and
  relaunch the app, and it comes back up already in demo mode. Flip it off
  and a relaunch goes back to the ordinary seeded coach dashboard exactly
  as before this harness existed.
- Everything in this file is compiled only under `#if DEBUG`. A Release
  build has no wrench button, no `Demo` source group in the binary, and no
  code path that can reach it.

### Scenarios (`DemoScenario`)

| Scenario | What it is |
|---|---|
| `richDemo` | The unmodified `InMemoryStore.seeded()` backend — 8 clients across every `EngagementStatus`, verified outcomes, messages, payments. |
| `showcase` | `richDemo` plus one seeded payment refunded via the real `PaymentGateway.refund` (the only gap in the seeded fixture) — guarantees a verified outcome, consent granted *and* withheld, an empty (`.pending`, no activity) client, a refunded payment, upcoming + past sessions, and unread messages all exist at once. |
| `emptyCoach` | A brand-new backend: `AuthGateway.signUp` creates the coach, then a `Person`/`ProfessionalProfile` are upserted through the normal repository protocols — zero clients, programs, or sessions. Exercises every screen's empty state. |
| `errorStates` | `richDemo` wrapped in `DemoErrorInjectingBackend`, which makes every repository read/write throw and every live stream finish empty — exercises every screen's `ErrorBanner`/retry path. `auth`/`analytics` pass through untouched so the harness itself keeps working. |

Switching scenarios rebuilds the backend live (no relaunch) via a
`.task(id:)` keyed on the selection.

### Role, clock, and payment controls

- **Role**: the same `DemoRole` switch the app already had — coach ↔
  consumer — now also selectable from the panel, in addition to each
  root's own "Switch role" row.
- **Clock**: a `DatePicker` plus "seeded reference date" / "now" presets.
  Backed by a lock-protected `DemoClockBox` rather than an `@Observable`
  class, because the `@Sendable () -> Date` closures `CoachRootView`/
  `ConsumerRootView` accept are synchronous and non-isolated — the same
  constraint documented in `docs/BUILD_STATUS.md` for why `PaymentsMode`
  isn't a `@MainActor`-backed runtime toggle. The lock sidesteps it instead
  of fighting it.
- **Payment outcome**: succeed / succeed-then-refund / fail, backed by a
  `DemoPaymentOutcomeController` actor and a `DemoPaymentGateway` decorator
  that only ever calls through to the real `MockPaymentGateway`'s
  `charge`/`refund` — it never hand-constructs a `Payment`.

### Screen catalog

A flat, resolved-at-runtime list (`DemoScreenCatalogView`) of direct jumps
into ~20 coach and consumer screens, using whichever engagement/program the
active scenario actually has (entries that need data the current scenario
doesn't have — e.g. "Client Detail" under `emptyCoach` — simply don't
appear, which is itself a demonstration of that scenario's empty state).

### Dependency rule

Every new file lives in `App/Sources/Demo/` (the composition root) and is
`#if DEBUG`-only. It depends on `Features`, `DesignSystem`, `DataInterfaces`,
`Domain`, and `InMemoryStore` — all already-allowed App dependencies — and
touches zero lines of `Domain`, `Features`' production code, or any
repository protocol's contract. Scenario construction uses only `Backend`
protocol calls (`upsert`, `signUp`, `refund`, ...), never `InMemoryBackend`
internals, so it stays exactly as portable as the rest of the composition
root.

## How to use it

1. Run the app in DEBUG (simulator or device).
2. Tap the wrench button, bottom-right.
3. Flip **Demo Mode** on. The dashboard swaps to the `richDemo` scenario
   immediately.
4. Pick a **Scenario** to see empty/error/showcase states; pick a **Role**
   to see the consumer side; move the **Clock** to see upcoming sessions
   become past ones; set **Payment outcome** before tapping "Charge" in the
   coach's Payments screen to see the decline/refund UI.
5. Open **Screen catalog** to jump straight to a specific screen/state
   without navigating tab-by-tab.
6. Flip Demo Mode off (or force-quit and relaunch with it left on — it
   persists) to compare against the ordinary app.
