# Handoff prompt — make Ascend easy to see & test end-to-end (brainstorm + execute)

Paste the fenced block below into Claude Code at the repo root
(`/Users/erniedefoy/Code/Ascend`). It follows the repo's Execution Protocol
(Opus orchestrates → fresh Sonnet executes), first **brainstorming** the best way
to make the app fully explorable/testable on mock data with no production
constraints, then **implementing** the chosen approach (build + test + commit).

It is intentionally scoped to DEBUG-only tooling: it must not change the shipping
product, the domain model, or any invariant — only add a demo/testability layer
on top of the existing `InMemoryStore` backend.

---

```
Execute this using the Execution Protocol in CLAUDE.md.

GOAL: make the Ascend app end-to-end explorable and testable on mock data with ZERO production
constraints — no real payments, no real users, no network, no live backend. I want to launch the
app (simulator) and: reach EVERY screen/state, switch roles (coach/consumer), generate/vary mock
data on demand, force payment outcomes (success/refund/fail), move the clock, and eyeball that the
whole app looks right and works correctly end-to-end.

Read docs/PRODUCT.md, docs/ARCHITECTURE.md, docs/DATA_MODEL.md, docs/BACKEND.md, docs/CONVENTIONS.md,
docs/TESTING.md, docs/ROADMAP.md, docs/BUILD_STATUS.md, and docs/design/DESIGN_SPEC.md. Then inspect
the existing app: the composition root in App/Sources, InMemoryStore (`InMemoryStore.seeded()`,
`referenceDate`, `MockData*`), MockPaymentGateway, and the Features screens/view models already built
(Today, Clients, Programs, Schedule, Progress, Messaging, ProofProfile, Payments).

=== PHASE 1 — BRAINSTORM (write this up before coding) ===
Produce a short design note (in the response, and as docs/TESTABILITY.md) that:
- Inventories every screen/flow currently in the app and what data state each needs to look "full"
  (populated, empty, error/loading, edge cases).
- Proposes 3–5 concrete approaches to make all of it reachable and variable on mock data, with
  tradeoffs. Consider at least: (a) an in-app DEBUG-only Developer/Demo menu that is a navigable
  catalog of every screen wired to seeded data; (b) a runtime scenario switcher that swaps between
  named `InMemoryStore` fixtures (e.g. "rich demo", "brand-new empty coach", "error states",
  "verified-outcome showcase") without relaunch; (c) a role switcher (coach ↔ consumer) so
  role-gated UI is reachable even before/after the consumer slice exists; (d) exposing the injectable
  clock (`referenceDate`) and MockPaymentGateway outcome (succeed/refund/fail) as live demo controls;
  (e) a mock-data generator/factory to synthesize arbitrary Person/Engagement/Session/Progress/
  Payment/Outcome graphs on demand; (f) comprehensive SwiftUI Previews (light/dark, Dynamic Type)
  and optionally snapshot tests as a second coverage net.
- Recommends ONE approach (or a minimal combination) as the default, justified by effort vs. coverage.
  Bias toward something that reaches the MOST UI for the LEAST new surface area and stays maintainable
  as later prompts add screens (esp. the Prompt 15 consumer slice).

=== PHASE 2 — EXECUTE the recommended approach (this is the real deliverable) ===
Implement it for real — not a stub. Hard requirements:
- DEBUG-only. None of this ships in Release builds (guard with `#if DEBUG` / a debug build config).
  Do not alter the production launch path or default UX for a normal run.
- Respect the dependency rule (CLAUDE.md): Features -> DesignSystem/DataInterfaces/Domain only, never
  a concrete backend; App is the sole composition root that may wire a backend/fixtures. Put
  mock-data generation/fixtures where they belong (InMemoryStore/MockData), the demo-menu UI in
  Features or App as the boundary allows, and any backend/fixture swapping in the App target.
- Do NOT change Domain, the invariants, or any repository protocol semantics. Verified outcomes must
  still only appear via `Domain.derive`. Payments must still only flow through the `PaymentGateway`.
  This is a testability layer, not a product change.
- Make EVERY existing screen reachable from the demo entry point, each with at least a populated state
  and (where meaningful) an empty and an error/loading state. Include a role switch so consumer UI is
  reachable (if the consumer slice isn't built yet, leave clearly-labeled placeholders that later
  prompts fill — do not fake product functionality).
- Wire the injectable clock and the MockPaymentGateway outcome as adjustable demo controls so
  time-based and payment UI can be exercised deterministically.
- Add at least one named "showcase" fixture guaranteeing one of every important state exists (a
  verified outcome present, consent on AND off, an empty client, a refunded payment, upcoming +
  past sessions, unread messages, etc.).

=== BUILD & VERIFY (must actually pass) ===
- `tuist generate`; build + test on an available iOS Simulator (`xcrun simctl list devices available`)
  with `xcodebuild build` and `xcodebuild test`; run `bash Scripts/lint.sh` (SwiftLint --strict).
- Fix all compile/test/lint failures and iterate until BUILD SUCCEEDED, tests green, 0 lint violations.
- Prove it works: launch the app in the simulator and confirm the demo entry point appears and lets
  you navigate to the screens/states (screenshot or describe the verified navigation). Do not claim
  success on a red build.

=== DONE ===
- docs/TESTABILITY.md written (the brainstorm + the "how to use the demo harness" guide).
- The DEBUG demo/testability harness is implemented, reachable, and exercises the app end-to-end on
  mock data with adjustable role/scenario/clock/payment controls; Release build is unaffected.
- Clean build, green tests, 0 lint violations. Commit with a clear message and `git push` to origin.
  Do not commit Config/Secrets.xcconfig or generated .xcodeproj/.xcworkspace.

REPORT BACK: the chosen approach + why; files added/changed; how to open and drive the demo harness;
the simulator destination + build/test/lint results; the commit SHA + push confirmation.
```
