# Demo harness — a DEBUG-only demo/exploration harness

How the whole app is made reachable and exercisable on mock data, with zero
production constraints, and how the owner flips it on from inside the running
app.

## What shipped

### The toggle

- A small circular button (wrench icon) floats in the bottom-right corner
  of the app in **every DEBUG build**, regardless of whether demo mode is
  on. Tap it to open **Demo Mode**.
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
| `showcase` | `richDemo` plus one seeded payment refunded via the real `PaymentGateway.refund` — guarantees a verified outcome, consent granted *and* withheld, an empty (`.pending`, no activity) client, a refunded payment, upcoming + past sessions, and unread messages all exist at once. |
| `emptyCoach` | A brand-new backend: `AuthGateway.signUp` creates the coach, then a `Person`/`ProfessionalProfile` are upserted through the normal repository protocols — zero clients, programs, or sessions. Exercises every screen's empty state. |
| `errorStates` | `richDemo` wrapped in `DemoErrorInjectingBackend`, which makes every repository read/write throw and every live stream finish empty — exercises every screen's `ErrorBanner`/retry path. `auth`/`analytics` pass through untouched so the harness itself keeps working. |

Switching scenarios rebuilds the backend live (no relaunch) via a
`.task(id:)` keyed on the selection.

### Role and clock controls

- **Role**: the same `DemoRole` switch the app already had — coach ↔
  consumer — now also selectable from the panel, in addition to each
  root's own "Switch role" row.
- **Clock**: a `DatePicker` plus "seeded reference date" / "now" presets.
  Backed by a lock-protected `DemoClockBox` rather than an `@Observable`
  class, because the `@Sendable () -> Date` closures `CoachRootView`/
  `ConsumerRootView` accept are synchronous and non-isolated — the same
  constraint that keeps `PaymentsMode` a build-time, not runtime, toggle
  (see docs/BACKEND.md). The lock sidesteps it instead of fighting it.

(A **payment outcome** control — succeed / succeed-then-refund / fail,
backed by a `DemoPaymentOutcomeController` actor and a `DemoPaymentGateway`
decorator — existed here to exercise the coach's charge/pay UI. Both the UI
and this control were removed pre-launch alongside the rest of the dark
payments surface (LH-9, docs/ROADMAP.md) and return together with Prompt 14's
real Stripe gateway.)

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
   become past ones.
5. Open **Screen catalog** to jump straight to a specific screen/state
   without navigating tab-by-tab.
6. Flip Demo Mode off (or force-quit and relaunch with it left on — it
   persists) to compare against the ordinary app.
