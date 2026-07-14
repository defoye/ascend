# Build Status

A running snapshot of where the Ascend build sequence stands: what has shipped,
what is next, and what is blocked on external accounts you (the owner) must set
up. Prompt numbers follow the source build sequence (`Ascend-Build-Prompts.md`).
`docs/ROADMAP.md` remains the detailed per-prompt checklist; this file is the
at-a-glance "done / next / needs-you" view.

_Last updated: 2026-07-14 (through Prompt 16 — tagged `v0.1.0`; + free-first rollout plan)._

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
| 15 | Consumer/client experience slice | `ConsumerRootView` (4-tab: Today, Progress, Coach, Me), workout player + progress logging, "My Progress" dashboard w/ milestones, outcome-sharing consent toggle (Invariant-1 proof both directions), goal-first onboarding intake — all on `InMemoryStore`, reachable via a demo role switch |
| 16 | Polish, accessibility, App Store readiness (code) | a11y sweep (VoiceOver/Dynamic Type/44pt targets/reduce-motion), `ErrorBanner` error/empty/loading coverage, app icon + launch screen + `Assets.xcassets`, `PrivacyInfo.xcprivacy` + privacy-policy stub, `AnalyticsTracking` seam (no-PII, mockable), `SettingsView` w/ in-app account deletion (`AccountDeletionEffect`), Debug **and** Release build clean, full suite green (179 tests), SwiftLint `--strict` 0 violations. **Archive/upload to App Store still needs the owner's Apple account — see action items below.** |

> Note: `docs/ROADMAP.md` carries a stray unchecked "Prompt 10 — Progress logging
> capture UI" line that duplicates work already delivered in Prompt 9 (a
> renumbering artifact). No separate work is owed for it.

## 🔜 Next — remaining build prompts

| # | Prompt | Can be done now (by Claude) | Blocked on you |
|---|--------|------------------------------|----------------|
| 13 | `SupabaseBackend` adapter | Adapter code, SQL migrations, config wiring, build clean on `InMemoryStore` default, skippable integration test | **Supabase project** + `SUPABASE_URL`/`SUPABASE_ANON_KEY` in `Config/Secrets.xcconfig` → then the live round-trip |
| 14 | Server: Stripe Connect + edge functions | Edge-function code (TS/Deno), `SupabaseBackend`'s `PaymentGateway` wiring, outcomes view/derivation, deploy+secrets docs | **Stripe (Connect test mode) + Supabase** deploy → live charge that writes a `Payment` row |
| 16 | Polish, accessibility, App Store readiness | ✅ **Done + tagged `v0.1.0`**: a11y, error/empty states, privacy manifest, analytics seam, settings + in-app account deletion, Debug+Release build clean, full suite green, SwiftLint clean | **Apple Developer account** → archive + TestFlight/App Store upload (Runbook C below) |

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
   TestFlight/App Store upload. Prompt 16's *code* is done and tagged
   `v0.1.0` (a11y, privacy manifest, settings + account deletion, Debug &
   Release build clean, full suite green). The only remaining Prompt 16 work
   is the archive/upload, which Claude cannot do — it needs your Apple
   account and signing identity. Follow **Runbook C** below.

After you complete 1 & 2, run the follow-up prompt Claude hands you to execute the
live verification and finalize `SupabaseBackend`/Stripe wiring.

## 🧭 Rollout strategy — free first, monetize later

Deliberate decision: **launch free (no live payments), validate a two-sided
userbase, then flip payments on.** Rationale:

- Stripe Connect (Prompt 14) is the most complex, highest-liability part of the
  system — coach KYC/onboarding, payouts, webhooks, refunds/disputes, tax
  (1099s). Deferring it removes that weight from v1 and speeds App Review (a free
  app has no IAP/payment review surface).
- It costs almost nothing to add back later, because payments already sit behind
  the `PaymentGateway` protocol and the gateway is selected in one place (the
  composition root). Turning payments on is a config flip, not a rewrite.

**The catch we're handling deliberately (Option B — "Tracked → Verified"):** the
product's differentiator, `VerifiedOutcome`, requires a *succeeded payment* as one
of its four pillars (see docs/DATA_MODEL.md). With payments off, no outcome is
"Verified". Rather than lose the moat in v1, the free phase surfaces the same
journeys labeled **"Tracked results"** (relationship + activity + consent +
progress, honestly *not* claiming the payment pillar), and the **"Verified" badge
only lights up once real payments are on**. This keeps the badge's integrity and
turns "turn on payments" into an upgrade coaches *want*. Crucially, this does NOT
change the Domain invariant: a `VerifiedOutcome` is still only ever constructed via
`Domain.derive` (all four pillars); a "Tracked" journey is a separate,
clearly-labeled Features-level view type, never a `VerifiedOutcome`.

**The switch:** a `PaymentsMode` flag (`.free` default / `.live`) read in the
composition root. `.free` hides charge/pay flows and renders outcomes as
"Tracked"; `.live` restores the mock/Stripe charge flows and "Verified" outcomes.
Flipping to `.live` is one line once Prompt 14 lands.

**Status: implemented.** `PaymentsMode` (`DataInterfaces/Sources/PaymentsMode.swift`)
is a two-case enum (`.free`/`.live`) alongside `PaymentGateway` — both `App`
and `Features` already depend on `DataInterfaces`, so it's visible everywhere
it's needed without either side depending on a concrete backend. The
composition root's single switch is `AppContainer.paymentsMode`
(`App/Sources/AppContainer.swift`), a `static let` defaulted to `.free`;
`AppContainer.makeBackend(paymentsMode:)` wraps whichever concrete backend it
builds in `PaymentsModeBackend` (`App/Sources/PaymentsModeBackend.swift`), a
`Backend` decorator that forwards every repository through unchanged and
swaps `paymentGateway` for `DataInterfaces.NoOpPaymentGateway` (always
throws) while `.free`, or the wrapped backend's real gateway while `.live`.
`RootView` passes `container.paymentsMode` down into `CoachRootView` /
`ConsumerRootView`, which thread it into the view models/views that branch
on it: `TodayViewModel`/`TodayView` (revenue snapshot hidden + never fetched
while `.free`), `CoachProfileView` (the whole "Business" section — pricing,
charge, payment history — skipped while `.free`), and `ProofProfileViewModel`/
`ProofProfileView` (Verified journeys via `Domain.VerifiedOutcome.derive`
while `.live`; "Tracked results" via the new pure `TrackedJourneySummaries`
— mirrors `derive`'s non-payment pillars verbatim, never constructs a
`VerifiedOutcome` — while `.free`, rendered with a distinct `TrackedBadge`
instead of `VerifiedBadge`). The client-facing consent screen
(`ConsentView`) and "Me" tab copy are mode-aware too, for cohesiveness. A
DEBUG-only *runtime* toggle in Settings was considered but skipped: making
`paymentsMode` reactively togglable would require `Backend.paymentGateway`
(a `nonisolated` synchronous requirement) to read `@MainActor`-isolated
state, which Swift 6 strict concurrency disallows without `await`. Both
directions are still fully previewable — every affected View has paired
`.live`/`.free` `#Preview`s — and switching modes for real is the
documented one-line change to `AppContainer.paymentsMode`.

| Phase | Ships | Cost | Payments | Backend |
|---|---|---|---|---|
| **1 — Private beta** | `v0.1.0` on TestFlight | Apple $99/yr + Supabase free | **Off** (`PaymentsMode.free`), outcomes = "Tracked" | Supabase (Prompt 13) — a runnable Release backend is required; `InMemoryStore` is DEBUG-only mock data |
| **2 — Public launch** | Same app, App Store | + Supabase Pro $25/mo *if* you outgrow free | Still off — grow both sides | Supabase |
| **3 — Monetize** | Flip `PaymentsMode` to `.live` + build Prompt 14 (Stripe) | Stripe per-transaction only (2.9% + \$0.30; Connect ~\$2/mo per active coach) | **On** — "Verified" activates, platform fee collected | Supabase + Stripe edge functions |

Client-facing app code doesn't change between phases 2→3 — you build the Stripe
adapter behind the existing protocol and flip the flag.

## 🚀 Runbook C — Archive → TestFlight → App Store (owner-run, needs your Apple account)

The app currently runs on `InMemoryStore` in DEBUG and `fatalError`s in a
Release *run* because no production backend is wired yet (Prompt 13). So
this runbook gets a **TestFlight build up the pipeline and validates
signing/upload plumbing now**; a public App Store release waits until
`SupabaseBackend` (Prompt 13) is the Release backend. Do it on the machine
that has this repo and Xcode.

**One-time setup**
1. Enroll in the **Apple Developer Program** ($99/yr) and sign in to Xcode:
   Xcode ▸ Settings ▸ Accounts ▸ **＋** ▸ Apple ID.
2. In **App Store Connect** (appstoreconnect.apple.com) ▸ Apps ▸ **＋** ▸
   New App: Platform **iOS**, Bundle ID **`com.ascend.Ascend`** (create it
   under Certificates, Identifiers & Profiles ▸ Identifiers first if it
   isn't listed), SKU `ascend-ios`, name "Ascend".
3. In the generated Xcode project, select the **Ascend** target ▸ Signing &
   Capabilities ▸ enable **Automatically manage signing** and pick your
   **Team**. (Signing lives on the generated target; because the project is
   Tuist-generated, set your team via `TUIST_` xcconfig or the Xcode UI on
   each `tuist generate` — do **not** hand-edit `.xcodeproj` and commit it.)

**Every release**
4. `tuist generate` (regenerate the workspace).
5. Bump the build number if re-uploading: `CFBundleVersion` in
   `Project.swift` (`appInfoPlist`), then `tuist generate` again.
   `CFBundleShortVersionString` is `0.1.0`.
6. Open `Ascend.xcworkspace` in Xcode. Set the run destination to **Any iOS
   Device (arm64)** (not a simulator — archives require a device SDK).
7. **Product ▸ Archive.** When the Organizer opens, select the archive ▸
   **Distribute App** ▸ **TestFlight & App Store** (or **TestFlight Internal
   Only** to validate plumbing without review) ▸ **Upload** ▸ accept
   automatic signing ▸ **Upload**.
   - CLI equivalent, if you prefer scripting it:
     ```
     xcodebuild -workspace Ascend.xcworkspace -scheme Ascend \
       -configuration Release -destination 'generic/platform=iOS' \
       -archivePath build/Ascend.xcarchive archive
     xcodebuild -exportArchive -archivePath build/Ascend.xcarchive \
       -exportOptionsPlist ExportOptions.plist -exportPath build/export
     ```
     (`ExportOptions.plist` with `method = app-store-connect` and your team
     id; or use `xcrun altool`/`notarytool`/**Transporter.app** to upload the
     resulting `.ipa`.)
8. In App Store Connect ▸ your app ▸ **TestFlight**: the build appears in a
   few minutes as "Processing". Once processed, complete **Export Compliance**
   (Ascend uses only standard HTTPS/OS crypto → typically "no" to the
   proprietary-encryption question), then add internal testers and install
   via the **TestFlight** app on device.
9. **App Store submission (do after Prompt 13 makes Release run on a real
   backend):** App Store Connect ▸ **App Store** tab ▸ fill in the privacy
   questionnaire to match `App/Resources/PrivacyInfo.xcprivacy` (Name,
   Fitness, Photos, Other User Content — all "app functionality", no
   tracking), add screenshots + description, attach the processed build,
   and **Submit for Review**.

**Common gotchas**: "No account for team" → add your Apple ID in Xcode
Settings ▸ Accounts. "Bundle identifier not available" → the App Store
Connect app record's bundle id must exactly equal `com.ascend.Ascend`.
Archive menu greyed out → destination is a simulator; switch to **Any iOS
Device**.

## 🧪 Aside: making it easy to see & test the app end-to-end

Independent of the backend work: see `docs/E2E_TESTABILITY_PROMPT.md` — a
paste-and-go prompt to build a DEBUG-only demo/testability harness (screen
catalog, scenario + role switcher, on-demand mock-data generation, controllable
clock and payment outcomes) so the whole app can be exercised and eyeballed on
mock data with zero production constraints.
