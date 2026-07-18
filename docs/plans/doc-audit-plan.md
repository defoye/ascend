# Doc Audit — Execution Plan (Phases 5–6 input)

Self-contained plan for Session 3 (Sonnet, execute + verify). Read this file and
nothing else. Judgment is already made — do NOT relitigate it. Where this plan is
wrong or ambiguous, STOP AND ASK.

**Scope decision (from the approval gate):** PROJECT-ONLY. Do not touch
`~/.claude/` anything (global CLAUDE.md, global skills, global settings, the
cross-repo symlinks). Those are deferred to Session 4's separate gate. Auto memory
under `~/.claude/projects/-Users-erniedefoy-Code-Ascend/memory/` IS in scope — it
is repo-keyed, not global.

**Design docs decision:** KEEP EVERYTHING under `docs/design/`. Delete none. Fix
only the mechanical drift called out below.

---

## 0. Target tree after execution

```
CLAUDE.md                         # rewritten as a MAP (~35 lines)
.claude/
  rules/
    project-structure.md          # paths: Project.swift, Modules/**
    swift-conventions.md          # paths: **/*.swift
    privacy-sync.md               # paths: privacy trio
  skills/
    execute-roadmap-prompt/SKILL.md   # model+user invocable
    release-deploy/SKILL.md           # disable-model-invocation: true
docs/
  PRODUCT.md            (keep)
  ARCHITECTURE.md       (trim + refresh)
  DATA_MODEL.md         (trim + refresh)
  BACKEND.md            (trim + refresh; runbooks extracted)
  TESTING.md            (fix + keep short)
  ROADMAP.md            (becomes single status source of truth)
  DEMO_HARNESS.md       (renamed from TESTABILITY.md, trimmed)
  PRIVACY_POLICY.md     (refresh)
  RUNBOOKS.md           (NEW — only if you choose not to put runbooks in the skill; see §4)
  design/               (KEEP ALL — fix mechanical drift only)
  plans/                (this audit's artifacts — leave)
DELETED:
  docs/E2E_TESTABILITY_PROMPT.md
  docs/BUILD_STATUS.md              (status half deleted; runbooks salvaged first)
  docs/CONVENTIONS.md               (content → swift-conventions rule + skill)
```

---

## 1. Deletions (exact)

1. `docs/E2E_TESTABILITY_PROMPT.md` — DELETE. Consumed one-shot dispatch prompt;
   superseded by `docs/DEMO_HARNESS.md` (the renamed TESTABILITY.md). Nothing to
   salvage.
2. `docs/CONVENTIONS.md` — DELETE **after** its content is written into
   `.claude/rules/swift-conventions.md` (§3) and the commit/roadmap ritual into the
   `execute-roadmap-prompt` skill (§4). Grep the repo for `CONVENTIONS.md`
   references and repoint them (root CLAUDE.md, any doc cross-refs).
3. `docs/BUILD_STATUS.md` — DELETE **after** salvaging its two runbooks (§4). Its
   Done/Next tables are an admitted duplicate of ROADMAP.md (BUILD_STATUS.md itself
   says "docs/ROADMAP.md remains the detailed per-prompt checklist; this file is the
   at-a-glance view"). Fold anything genuinely current from its "What needs you"
   owner-action list into ROADMAP.md's open items before deleting. Grep for
   `BUILD_STATUS` and repoint (BACKEND.md cross-references it).

No other deletions. **Do not delete anything under `docs/design/`.**

---

## 2. Root `CLAUDE.md` → rewrite as a map (~35 lines)

Replace the whole file. Keep it a MAP: pointers + when-to-read + the three critical
gotchas. Everything currently in "Execution Protocol" (lines 28–43) and the
dependency-rule block (11–18) moves out (to the skill and the rule respectively).

Required content:

- **Three critical gotchas** (kept in root because their absence causes a mistake
  every session):
  1. `DEBUG` builds run on `InMemoryStore.seeded()` — the whole app, previews, and
     unit tests run with zero backend. (rationale: docs/BACKEND.md)
  2. Add/remove files by editing `Project.swift` globs then `tuist generate`. NEVER
     hand-edit `.xcodeproj`/`.xcworkspace` — generated and gitignored. (full rule:
     `.claude/rules/project-structure.md`)
  3. Module dependency rule is enforced by Tuist; only the `Ascend` app target may
     wire a concrete backend. (full rule: `.claude/rules/project-structure.md`)
- **Doc map** — each pointer gets *where / what / WHEN TO READ IT*:
  - `docs/PRODUCT.md` — strategy + the two invariants — read before any product,
    copy, or scope decision.
  - `docs/ARCHITECTURE.md` — why the module boundaries and the backend-behind-
    protocols seam exist — read before changing module structure or the backend
    seam.
  - `docs/DATA_MODEL.md` — domain semantics (invite claim rules, VerifiedOutcome
    eligibility, consent gating) — read before touching Domain types or engagement/
    invite/outcome logic.
  - `docs/BACKEND.md` — backend selection, offline queue, payments seam — read when
    working on persistence, sync, payments, or the Supabase adapter.
  - `docs/TESTING.md` — testing philosophy + how to run tests — read before writing
    or running tests.
  - `docs/ROADMAP.md` — what shipped / what's next — read when picking up work or
    asking "why does X exist."
  - `docs/DEMO_HARNESS.md` — the DEBUG demo/scenario harness — read only when
    extending that harness.
  - `docs/PRIVACY_POLICY.md` — user-facing privacy text — read when data collection
    changes (see `privacy-sync` rule).
  - `docs/design/` — design tokens, spec, and the design-pass handoff bundle — read
    when touching DesignSystem or building screens from the design pass.
- **Pointer to the workflow skill:** running a roadmap prompt end-to-end is the
  `execute-roadmap-prompt` skill; releasing/deploying is `release-deploy`.

Use HTML comments (`<!-- -->`) for any maintainer notes — they are stripped before
injection and cost zero tokens. Do not paste code. Do not restate the module tree.

---

## 3. `.claude/rules/` (create the directory; all rules `paths:`-scoped)

### 3a. `.claude/rules/project-structure.md`
```
---
paths:
  - Project.swift
  - Modules/**
---
```
Body (single source of truth — this replaces the dep-rule text in root CLAUDE.md
AND the duplicated diagram in ARCHITECTURE.md):
- The dependency rule, verbatim from the current root CLAUDE.md lines 11–18:
  `Domain` → Foundation only; `DataInterfaces` → `Domain`; `InMemoryStore` →
  `DataInterfaces`, `Domain`; `DesignSystem` → (none); `Features` → `DesignSystem`,
  `DataInterfaces`, `Domain`; `Ascend` (app) is the only composition root and the
  only target allowed to depend on a concrete backend adapter.
- **REFRESH while writing:** the current ARCHITECTURE.md dep diagram omits
  `SupabaseBackend`. Add it: `SupabaseBackend` → `DataInterfaces`, `Domain`;
  depended on only by `Ascend`. Verify the exact edges against
  `Project.swift:122-190` and `Project.swift:4-11,70-77` before writing — do not
  copy this line blindly.
- Tuist workflow: add/remove files via `Project.swift` globs → `tuist generate`;
  never hand-edit `.xcodeproj`/`.xcworkspace`.

### 3b. `.claude/rules/swift-conventions.md`
```
---
paths:
  - "**/*.swift"
---
```
Body — port from `docs/CONVENTIONS.md`, imperatively and concretely:
- Language & concurrency conventions (Swift 6; the actual concurrency stance stated
  in CONVENTIONS.md — read it, don't invent).
- No force-unwraps; value types by default (as stated in CONVENTIONS.md).
- File organization pattern (as stated in CONVENTIONS.md).
- Previews run on `InMemoryStore` (as stated in CONVENTIONS.md).
- **How to run tests** (fixes the TESTING.md drift that points at a nonexistent root
  README): state the actual command. Verify it first — `xcodebuild test` on an iOS
  simulator for module/UI targets, `swift test` for pure-Swift modules. Confirm the
  scheme/target names against `Project.swift` and record the exact invocation.

Do NOT put the commit/roadmap ritual here (it's a per-prompt workflow, not a
per-Swift-file constraint) — it goes in the skill (§4).

### 3c. `.claude/rules/privacy-sync.md`
```
---
paths:
  - docs/PRIVACY_POLICY.md
  - "**/PrivacyPolicyView.swift"
  - "**/PrivacyInfo.xcprivacy"
---
```
Body: one constraint — these three describe the same policy and MUST change
together; editing one without reconciling the other two ships a contradiction.
(Confirm the two Swift/plist paths exist via glob before finalizing; PRIVACY_POLICY.md
line 3 names all three.)

**No `paths:`-less rules.** The root-priority rule tier stays empty.

---

## 4. `.claude/skills/` (create the directory)

### 4a. `.claude/skills/execute-roadmap-prompt/SKILL.md`
Frontmatter:
```
---
name: execute-roadmap-prompt
description: Use when implementing a numbered prompt from docs/ROADMAP.md end-to-end — build the feature, run build + tests + SwiftLint until green, tick the ROADMAP box, commit, and push. Not for one-off edits.
---
```
(user-invocable and model-invocable — leave both defaults on; no `disable-model-invocation`, no `context: fork`.)

Body — MODERNIZED port of the current root "Execution Protocol" (lines 28–43).
Keep the durable value, DROP the vestigial rigidity:
- KEEP: work from the docs the prompt names; deliver working code (no stubs);
  ACTUALLY build + test + lint before claiming done — `tuist generate`, then
  `xcodebuild build`/`xcodebuild test` on an iOS simulator (or `swift test` for
  pure-Swift modules) plus SwiftLint; iterate until clean; then the commit ritual
  below.
- KEEP the commit/roadmap ritual (ported from CONVENTIONS.md): after the prompt is
  green — update code/tests/docs, tick the prompt's box in `docs/ROADMAP.md`,
  commit, push to `origin`.
- DROP (harness-review, per approval): the "You are the Opus orchestrator. Do not
  implement features yourself. Dispatch ONE fresh-context Sonnet subagent…" mandate.
  Replace with judgment guidance: *delegate a large, self-contained slice to a
  fresh-context subagent when it would otherwise bury the main thread; otherwise
  implement directly.* Delegation is a context-hygiene tool, not a required step for
  every prompt.

### 4b. `.claude/skills/release-deploy/SKILL.md`
Frontmatter:
```
---
name: release-deploy
description: Use when cutting a release or deploying backend changes — Supabase migrations (db push), Edge Function deploy, APNs/push setup, and Archive → TestFlight → App Store. Owner-run; has side effects.
disable-model-invocation: true
---
```
(`disable-model-invocation: true` — side effects, human controls timing; this also
removes the description from Claude's always-loaded listing, freeing budget.)

Body — SALVAGE and consolidate the runbooks before their source docs are deleted/
trimmed:
- From `docs/BUILD_STATUS.md`: Runbook D (Supabase migrations: `supabase login` /
  `link` / `db push`) and Runbook C (Archive → TestFlight → App Store, the
  `xcodebuild archive`/`-exportArchive` steps).
- From `docs/BACKEND.md`: the owner-action runbooks (APNs key setup, `supabase
  functions deploy delete-account`, `supabase secrets set`).
- REPLACE rotting hardcoded values with a lookup instruction, not the literal:
  the project ref (`zrpkrknqcxmgibizrisg`) and the simulator UUID
  (`562AA1B2-…`) must become "look up the current project ref via `supabase
  projects list`" / "pick a booted simulator UUID via `xcrun simctl list`". Do not
  paste the old literals.

If you judge a skill is the wrong home for these runbooks, the fallback is
`docs/RUNBOOKS.md` with identical content — but the skill is preferred (loads only
on invoke, description removed from context). Pick one; do not create both.

---

## 5. Doc refreshes (fix every DRIFTED claim against actual code)

- `docs/ARCHITECTURE.md` — remove the dep-rule diagram body (now owned by the
  `project-structure` rule); leave a one-line pointer to that rule. KEEP the
  rationale (Foundation-only, stream-vs-fetch, portability contract). This closes
  the DRIFT (missing SupabaseBackend) by moving the canonical edges to the rule
  where they're refreshed in §3a.
- `docs/DATA_MODEL.md` — thin the mechanical field-by-field enumerations that just
  mirror `Modules/Domain/Sources/` down to a pointer ("field-level types live in
  Modules/Domain/Sources/…"); KEEP the semantics that are NOT derivable: invite
  claim rules, `VerifiedOutcome.derive` eligibility, consent gating, RLS notes.
  DELETE the vestigial line 3 "Prompt 1 implements this."
- `docs/BACKEND.md` — strip the LH-3/LH-7/LH-10/LH-11 "reviewed-only, not run
  locally" changelog accretion (that history lives in ROADMAP.md). KEEP the durable
  seam/rationale (why `NoOpPaymentGateway`, why anonymize-not-delete, why an Edge
  Function). Runbooks move to the `release-deploy` skill (§4b). Repoint its
  BUILD_STATUS cross-reference (that file is being deleted).
- `docs/TESTING.md` — keep it short; keep the "runs on no backend / InMemoryStore"
  gotcha. FIX the drift: it points at a root README that does not exist for test
  invocation — point instead at `.claude/rules/swift-conventions.md` (which now
  carries the verified command). Update its test-target list only if you can verify
  the current targets against `Project.swift` (Session 1 found it missing
  `DesignSystemTests`, `SupabaseBackendTests`, `SupabaseBackendIntegrationTests`,
  `AscendTests`, `AscendUITests`) — or replace the enumerated list with a pointer to
  `Project.swift` so it can't rot again.
- `docs/ROADMAP.md` — becomes the single status source of truth. Fold in any current
  owner-action items from the deleted BUILD_STATUS.md. Add the one open
  launch-hardening item (slice 6, "Workout draft persistence") as a tracked,
  versioned entry — see §7. Verify slice 6's real status against code before
  writing its checkbox state.
- `docs/TESTABILITY.md` → RENAME to `docs/DEMO_HARNESS.md`. DELETE the PHASE 1
  brainstorm / options-considered / rejected-options section (process history).
  KEEP "What shipped" + the "How to use it" tap-through guide + the scenario/screen
  catalog. Repoint any references to the old filename.
- `docs/PRIVACY_POLICY.md` — REFRESH: remove the citation of
  `EngagementProgressView+Photos.swift` (deleted in commit `0173de9`); reconcile the
  progress-photo consent-flow description with reality (LH-8 hid the photo UI for
  launch — the consent flow it describes is not user-reachable). Make the present
  tense match the current build. Keep it user-facing.
- `docs/design/handoff/HANDOFF_README.md` — MECHANICAL fixes only (design docs are
  kept): correct `Ascend Screens.dc.html` (with space) → `AscendScreens.dc.html`
  (actual filename, two occurrences); remove the phantom `support.js` "DC runtime"
  reference (file does not exist). Optionally repoint its duplicated token table at
  `docs/design/DESIGN_SPEC.md` as the source of truth — but do NOT delete content.
- `docs/design/SCREEN_INVENTORY.md` — KEEP (per decision). Optional cosmetic fix:
  it labels the coach messaging tab "Inbox"; actual code label is "Messages"
  (`CoachRootView.swift:87`). Fix only if trivially confirmed.

Constraints (from the audit): do not invent docs for undocumented things; never
paste code (point at the exemplar file); rewrite high-churn facts as pointers, not
duplicates; preserve human-facing content.

---

## 6. Settings

No project `.claude/settings.json` changes required. (The `/doctor`-proposed
`defaultMode=auto` and unused-skill disables are GLOBAL and out of scope for this
project-only plan.)

---

## 7. Auto memory (repo-keyed; in scope)

Directory: `~/.claude/projects/-Users-erniedefoy-Code-Ascend/memory/`.

- `MEMORY.md` — the index line says "9-slice"; the topic file documents 11 slices.
  Correct "9-slice" → "11-slice."
- `launch-hardening-plan.md` — internal contradiction: closing line "ALL 11 SLICES
  COMPLETE" vs slice 6 ("Workout draft persistence") still `[ ]`. Verify slice 6's
  real state against code. If done, tick it and the closing line is correct; if
  open, remove/soften the "ALL COMPLETE" line. Then PROMOTE the open item into
  `docs/ROADMAP.md` (versioned, teammate-visible) so it doesn't live only in
  uncommitted machine-local memory. After promotion, this transient tracker can be
  retired once all slices are truly done.

---

## 8. Phase 6 verification (do, don't assert)

1. Re-run `/doctor`, `/context`, `/memory`; diff reported context cost vs the
   Phase 0 baseline (Memory files 2.4k, Skills 2.7k). `/context`'s Skills row is the
   honest number. Expect: always-loaded roughly flat-to-slightly-down (root map ↓,
   path-scoped rules cost ~0 until a match is read, +1 skill description, the
   `release-deploy` description removed via `disable-model-invocation`). Report the
   real numbers, not this estimate.
2. **Path-scoped rule verification** — for EACH of the three rules: (a) expand its
   glob against the real tree and list matches; (b) actually read a file that should
   match and one that shouldn't and confirm the rule fires / doesn't. Watch for a
   glob that matches nothing (silent failure) and stray `[` bracket expressions.
   If an `InstructionsLoaded` hook is available, register it, capture the log,
   report it, then remove it.
3. Confirm every path referenced in the new root map and rules exists.
4. Confirm the test command in `swift-conventions.md` actually runs.
5. Contradiction sweep across root CLAUDE.md, the three rules, and auto memory
   (skip global `~/.claude/` — out of scope this session).
6. Test the map: pick three plausible tasks (e.g. "add a field to an Engagement",
   "wire a new backend call", "change privacy copy") and state which pointers/rules
   would fire and whether that's correct. If a pointer wouldn't fire, its "when to
   read it" line is wrong — fix it.

Write results to `docs/plans/doc-audit-verify.md`. Report anything that fails
verification rather than quietly fixing it.

---

## Projected tiers (before → after)

| Tier | Before | After |
|---|---|---|
| Root `CLAUDE.md` | 43 lines, ~1.1k tok always-loaded | ~35-line map, ~0.85k tok |
| `.claude/rules/` | none | 3 files, all `paths:`-scoped → ~0 always-loaded until a match is read |
| `.claude/skills/` (project) | none | 2 (one with description hidden via `disable-model-invocation`) → +~60 tok listing |
| `docs/` | 15 files / ~2,181 lines (on-demand) | ~10 files / ~1,300 lines (on-demand; deletions + trims) |
| Auto memory | 2 files, 2 contradictions | 2 files, reconciled |

Always-loaded net: roughly flat-to-slightly-down. The project layer's wins are
correctness (drift fixed), routing (right content loads on the right trigger), and
rot-surface reduction — not raw token count. (The larger token wins live in the
global tier, deferred to Session 4.)

**END SESSION 2.**
