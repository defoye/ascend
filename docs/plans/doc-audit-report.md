# Doc Audit — Session 4 Report & Portable-Layer Proposal (Phases 7–8)

Final session (Opus). Phase 7 reports what the four-session audit did and what it
found. Phase 8 **proposes** the portable global layer — nothing has been written
to `~/.claude/`; the proposal is staged in-repo at
`docs/plans/portable-layer-proposal/` and stops at the approval gate.

Grounded in observed state re-measured live this session (not trusting the prior
artifacts): `wc -l`, glob expansion, and live rule-firing tests.

---

# Phase 7 — Report

## Before / after, per tier

| Tier | Before (Session 1 baseline) | After (measured this session) |
|---|---|---|
| Root `CLAUDE.md` | 43 lines | 47 lines — rewritten as a pure map (pointers + 3 gotchas) |
| `.claude/rules/` | did not exist | 3 files, all `paths:`-scoped, 94 lines total: `project-structure.md` (35), `swift-conventions.md` (45), `privacy-sync.md` (14). Cost ~0 always-loaded until a matching file is read. |
| `.claude/skills/` (project) | did not exist | 2: `execute-roadmap-prompt` (26 lines; model+user invocable) and `release-deploy` (124 lines; `disable-model-invocation: true` → description removed from the listing budget entirely) |
| `docs/` (top-level `.md`) | 15 files / ~2,181 lines | 8 files / 1,192 lines — 3 deleted, 1 renamed, rest trimmed/refreshed |
| Auto memory | 2 files, 2 internal contradictions | 2 files, both reconciled |
| Project `.claude/settings.json` | none | none (correctly unchanged — the `/doctor` proposals were global and out of scope) |

**On the "from /context numbers, not estimates" requirement:** `/doctor`,
`/context`, and `/memory` are interactive commands the human runs; no tool
invokes them programmatically, so I cannot produce a live authoritative
resident-token diff from inside a session. The line-count and structural diff
above is fully observed; the resident-token confirmation needs a human-run
`/context` in a fresh session. Structurally the always-loaded total is
**flat-to-slightly-down**: the root map is ~the same size, the three rules cost
~0 until matched, `+1` skill description enters the listing, and `release-deploy`
removes its own description via `disable-model-invocation`. The real wins are
correctness, routing, and reduced rot-surface — not raw token count. (The larger
token win is in the global tier — see Phase 8.)

## What moved where

- Module dependency rule + Tuist workflow: root `CLAUDE.md` → `.claude/rules/project-structure.md` (`paths: Project.swift, Modules/**`), as the single source of truth (also removed from the ARCHITECTURE.md diagram).
- Swift conventions + test/lint invocation: deleted `docs/CONVENTIONS.md` → `.claude/rules/swift-conventions.md` (`paths: **/*.swift`).
- Privacy three-way-sync constraint: new `.claude/rules/privacy-sync.md` (`paths:` the policy doc + `PrivacyPolicyView.swift` + `PrivacyInfo.xcprivacy`).
- Roadmap build/test/lint/commit ritual: root `CLAUDE.md` "Execution Protocol" → `.claude/skills/execute-roadmap-prompt/`, modernized (dropped the mandatory Opus-orchestrator/Sonnet-subagent rigidity; delegation is now judgment, not a required step).
- Runbooks (Supabase migrations, Edge Function deploy, APNs, Archive→TestFlight→App Store): salvaged from deleted `BUILD_STATUS.md` + `BACKEND.md` → `.claude/skills/release-deploy/`, with rotting literals (project ref, sim UUID) replaced by lookup instructions.

## What was deleted

- `docs/E2E_TESTABILITY_PROMPT.md` — consumed one-shot dispatch prompt, superseded.
- `docs/BUILD_STATUS.md` — admitted duplicate of ROADMAP.md; runbooks salvaged first, owner-action items folded into ROADMAP.md.
- `docs/CONVENTIONS.md` — content became the swift-conventions rule + the roadmap skill.
- `docs/TESTABILITY.md` — **renamed** to `docs/DEMO_HARNESS.md` (brainstorm/options-considered history dropped; "what shipped" + "how to use it" kept).

## What was stale and got corrected — the most valuable output

- **`ARCHITECTURE.md` dependency diagram omitted `SupabaseBackend`** (its central claim was wrong). Fixed by moving the canonical edges to `project-structure.md` and adding `SupabaseBackend -> DataInterfaces, Domain` (depended on only by `Ascend`), verified against `Project.swift`.
- **`TESTING.md` pointed at a root `README` that does not exist** for test invocation, and listed only 4 of the real test targets. Repointed to `swift-conventions.md`, which now carries a verified command.
- **`PRIVACY_POLICY.md` cited `EngagementProgressView+Photos.swift`** — deleted in `0173de9` (LH-8) — and described progress-photo consent sharing as a live user-facing flow when LH-8 hid that UI for launch. Reconciled to the current build.
- **`BACKEND.md`** carried LH-3/7/10/11 "reviewed-only" changelog accretion that belongs in ROADMAP.md; stripped, durable seam rationale kept, dead `BUILD_STATUS.md` cross-reference repointed.
- **`DATA_MODEL.md`** — dropped the vestigial "Prompt 1 implements this" line and thinned field-by-field enumerations to a pointer at `Modules/Domain/Sources/`.
- **`handoff/HANDOFF_README.md`** — `Ascend Screens.dc.html` (with space) → actual `AscendScreens.dc.html`; removed the phantom `support.js` reference.
- **Auto memory** — `MEMORY.md` index "9-slice" → "11-slice"; `launch-hardening-plan.md` slice-6 checkbox reconciled with its "ALL 11 SLICES COMPLETE" closing line (slice 6's `WorkoutSessionDraftStore.swift` + tests confirmed to exist).

## What failed / is still open in verification

1. **`swift-conventions.md` false test command — FIXED (closeout).** It claimed
   the single `Ascend` scheme "covers every module's `<Module>Tests` target."
   Verified false: inspecting the generated scheme Testables blocks shows the
   `Ascend` scheme runs only `AscendTests` + `AscendUITests`, while Tuist's
   auto-generated **`Ascend-Workspace`** scheme aggregates all nine test targets
   (the six module `*Tests`, `AscendTests`, `AscendUITests`, and
   `SupabaseBackendIntegrationTests`). Session 3's two proposed workarounds were
   unnecessary — the fix is a single scheme-name change to `Ascend-Workspace`.
   The rule now documents `Ascend-Workspace` as the full-suite scheme and `Ascend`
   as the fast app-smoke-test scheme. Grounded in the scheme `.xcscheme`
   Testables (definitional), not a full test run.

2. **Path-scoped rule firing — Session 3 could not confirm; NOW CONFIRMED live
   this session.** Reading `Modules/Domain/Sources/Engagement.swift` surfaced
   both `swift-conventions.md` and `project-structure.md` as system-reminders;
   reading `App/Resources/PrivacyInfo.xcprivacy` surfaced `privacy-sync.md`
   *alone*; docs files surfaced none. All three rules are live and correctly
   scoped (no over-match, no silent-zero glob). This resolves the largest open
   item from `doc-audit-verify.md` §2.

3. **Live `/doctor` / `/context` / `/memory` re-run** still needs the human (see
   Phase 7 note above). Everything else in `doc-audit-verify.md` (path existence,
   `tuist generate`, `xcodebuild test` = TEST SUCCEEDED, `Scripts/lint.sh` = 0
   violations, contradiction sweep, map test) was verified there and re-confirmed
   structurally here.

## Hook candidates (unbuilt — flagged only)

- **Privacy-sync as enforcement.** `privacy-sync.md` is context, not enforcement.
  If the three privacy artifacts drifting apart is a real ship-blocker, a
  pre-commit/PR hook that fails when one of the trio changes without the others
  is the deterministic version. (A policy hook must `exit 2` to block; `exit 1`
  does not.)
- **SwiftLint in CI/pre-commit.** `Scripts/lint.sh --strict` is currently a
  convention in the roadmap skill; a hook makes "must run clean" non-negotiable.

Neither built, per the audit's "flag, don't build" rule.

## Stop-hook doc-maintenance proposal (unbuilt — flagged only)

A `Stop` hook receives the session transcript path when Claude finishes, so a
script can review the just-completed session and **propose** `CLAUDE.md` / rules
updates while the gap is fresh — surfaced as suggestions the human accepts, never
silent writes. This directly serves the "add a trigger when you correct the same
thing twice" maintenance loop. If built later: `exit 1` does NOT block (it's
advisory), so this is the right exit code for a suggestion-only hook; reserve
`exit 2` for true policy blocks. Not built.

## Anything unverifiable, and why

- Resident-token `/context` numbers — interactive command, human-run only (above).
- The `.dc.html` design-canvas rendering and the `ascend-claude-design-bundle.zip`
  contents were checked for path/filename existence only, not rendered — outside
  a doc-staleness audit's reach.

## How to maintain this

- **Diagnostics.** Claude violates a rule that exists → the file grew too long or
  the rule got buried; shorten or resurface it. Claude asks something the docs
  answer → the phrasing is ambiguous; make it concrete. A rule that doesn't
  measurably change behavior is dead weight — test by deleting it and watching.
- **Add a trigger when you correct the same thing twice.** That's a missing line.
  Write the shortest concrete instruction that would have prevented it — a
  conversational correction fixes one run; a written rule fixes every future run.
- **Review in PRs**, like any other doc change.
- **Cadence: every 3–6 months and after every major model release.** Model
  releases are the key trigger — plan mode is the proof: correct advice for a
  year, then overhead. (The existing global `~/.claude/CLAUDE.md` "Plan / Build
  Separation" section is a live instance of exactly this — see Phase 8.)

---

# Phase 8 — Portable layer proposal  ← APPROVAL GATE

> **RESOLUTION (closeout).** The user chose to hold this session's proposal and
> compare against a parallel session running the same Phase 8 in another repo.
> That session installed its own `docs-architecture` meta-skill to the global
> slot `~/.claude/skills/docs-architecture/`. On review it was the stronger
> version (leaner SKILL.md that better practices the minimalism it preaches, a
> cleaner principle/procedure split, and two superior pieces of content: the
> living-vs-dated root-CLAUDE.md template and the "cross-cutting method" section
> in audit.md). **Decision: keep the installed version; this session's staged
> proposal was NOT installed and has been deleted** (`docs/plans/portable-layer-proposal/`
> removed in closeout). The portable Swift rule (item 2 below) was parked and
> not installed. **This session wrote nothing to `~/.claude/`.** The proposal
> detail below is retained as the record of what was considered and rejected.

⚠ This is the only part reaching outside the repo. Every proposed file was staged
in-repo (since deleted) rather than written to `~/.claude/` directly; the global
slot it targeted was ultimately filled by the parallel session's version, not
this one.

**Context minimalism** (Anthropic's current guidance): today's models need less
scaffolding, not more. The honest result of applying the zero-repo-facts bar
strictly is a **short** list — one unambiguous skill, one borderline rule.
Everything else in this repo's project layer encodes Ascend facts and stays put.

## Proposed — install on approval

### 1. `~/.claude/skills/docs-architecture/` — the meta-skill (UNAMBIGUOUS global)

The one case where global scope is unambiguously correct: it encodes zero facts
about any repo. Applies this whole tiering architecture to a *new* repo or a
future audit. Staged files:

| Staged path | → installs to | Lines |
|---|---|---|
| `…/skills/docs-architecture/SKILL.md` | `~/.claude/skills/docs-architecture/SKILL.md` | 174 |
| `…/skills/docs-architecture/audit.md` | `~/.claude/skills/docs-architecture/audit.md` | 140 |
| `…/skills/docs-architecture/templates/root-claude-md.md` | same under `~/.claude/…` | 38 |
| `…/skills/docs-architecture/templates/rule-example.md` | same under `~/.claude/…` | 29 |

SKILL.md (174 < 500 cap) carries the tier table, the two tests (rules-vs-skills,
rules-vs-nested-CLAUDE.md), the no-`paths:` trap, the scoping test, the DELETE
list, trigger-condition phrasing + the 1,536-char cap, root-CLAUDE.md-as-map, the
Opus-plans/Sonnet-executes split with `/clear` boundaries, and the maintenance
cadence. The phased audit procedure and templates live in supporting files so
they load only on invoke. **Only the description costs anything in every repo** —
it is a trigger condition, short:

> "Set up or audit Claude Code documentation structure — CLAUDE.md,
> .claude/rules/, and skills — using context-tiered routing. Use when starting a
> new repo, when CLAUDE.md has grown past ~200 lines, or when auditing existing
> docs for staleness."

### 2. `~/.claude/rules/swift-conventions.md` — portable Swift rule (BORDERLINE)

Staged at `…/rules/swift-conventions.md` (23 lines incl. an install comment).
`paths: **/*.swift`, so it costs **nothing** in a non-Swift repo and fires in
every Swift one. Contains ONLY the zero-repo-fact subset:

- Swift 6 strict concurrency (complete checking).
- Value types by default; `class` only for real reference semantics.
- No force-unwraps outside test code.

This is the one genuinely borderline call. It passes the test (paths-scoped, no
repo facts) and the audit prompt itself names "Swift conventions scoped to Swift
files" as the canonical portable rule. But it is *opinionated personal style*,
not a universal — so it is proposed, not assumed. **If you'd rather keep even
this project-local, that is the more conservative and defensible choice; say so
and I'll drop it.** Deliberately EXCLUDED from the global rule (kept
project-local in Ascend, re-decide per repo): `@MainActor @Observable` view
models + `AsyncStream` repositories (an architecture preference referencing
Ascend's ARCHITECTURE.md), previews-on-`InMemoryStore`/`MockData` (repo fixture
wiring), and the test/lint invocation (100% Ascend).

## Considered and REJECTED (a short list is the goal)

| Candidate | Verdict | Why |
|---|---|---|
| `execute-roadmap-prompt` skill | **project-only** | ROADMAP.md, `tuist`, `xcodebuild`, SwiftLint, this repo's commit ritual — saturated with Ascend facts. |
| `release-deploy` skill | **project-only** | Supabase, TestFlight, App Store, this app's Edge Functions — entirely Ascend. |
| `project-structure.md` rule | **project-only** | Module names, Tuist, Supabase seam — 100% Ascend. |
| `privacy-sync.md` rule | **project-only** | Names three specific Ascend files. |
| Ascend `swift-conventions.md` in full | **project-only** | Only the 3-line subset above is repo-neutral; the rest references Ascend architecture/fixtures/commands. |
| Auto-memory `launch-hardening-plan.md` | **project-only** | Ascend's launch sequence; repo-keyed by design, never global. |

## Adjacent global-tier observations (from the inventory — NOT extractions; flagged, not acted on)

These concern the *existing* global layer, not extraction from this repo. Noted
because the global layer rots too and this audit surfaced them; each is a
separate decision, none touched here:

- **`~/.claude/CLAUDE.md` "Plan / Build Separation" (59-line file).** Mandates
  plan-mode-style read-then-write discipline. The audit's own harness-review lens
  names "any instruction mandating plan mode" as the canonical obsolete-post-4.6
  rule. Candidate for a trim on the next global review — recommend, don't act.
- **Cross-repo pollution:** 5 extensions (`product-evaluation`, `feature-design`
  skills; `wrap-session`, `design-brief`, `new-product` commands) are symlinked
  into `~/.claude/` from `~/code/ai_product_builder`. They eat listing budget in
  *every* repo, including this iOS one where their triggers are irrelevant.
  Cleanup is a global-hygiene decision for that other project's owner.
- **Parked `/doctor` proposals** (still not applied, at your request):
  `skillOverrides` off for 3 never-invoked user skills (`mobile-app-design`,
  `apple-intelligence`, `autonomous`) and `permissions.defaultMode = "auto"`.

## Maintenance note for the global layer itself

The global layer is a harness and rots the same way — same 3–6 month /
post-model-release review, arguably more urgent, since a stale global rule
degrades every repo at once. The `docs-architecture` skill's own "Maintaining
this" section applies to it recursively.

---

## Gate decisions — RESOLVED (closeout)

1. **`docs-architecture` meta-skill** — installed by the parallel session (its
   version won the comparison); this session's staged copy deleted. No global
   write from here.
2. **Portable Swift rule** — parked, not installed; kept project-local.
3. **False test command in `.claude/rules/swift-conventions.md`** — FIXED this
   closeout (now points at the `Ascend-Workspace` aggregate scheme; see Phase 7
   item 1).

Closeout scope was project-level only; nothing in `~/.claude/` was touched by
this session. **END SESSION 4.**
