# Doc Audit — Session 1 Inventory (Phases 0–2)

Self-contained input for Session 2 (Opus, Phases 3–4). Read this file and nothing
else from Session 1. No edits were made in this session — Phases 0–2 are read-only
by design.

---

## Phase 0 — What's actually loaded

### Starting-directory finding

Session launched from the repo root: `/Users/erniedefoy/Code/Ascend`. Implication:
root `CLAUDE.md` loaded at launch; any subdirectory `CLAUDE.md` would load only on
demand as files under it are touched (none exist in this repo — see Phase 1); skills
load from every directory level touched during the session, plus user/enterprise
level. `.claude/settings.json` loads only from the starting directory — moot here
since neither the project nor any subdirectory has one (see Settings check below).

### `/doctor` — captured verbatim (ran live this session)

Scan window: 50 most-recent transcript files (of 240 total across all projects on
this machine), all dated 2026-07-17 11:11–19:29 — a thin, single-day window. Lifetime
usage counters (`skillUsage`/`pluginUsage`) were used alongside it where the window
alone would mislead.

**Summary:** installation healthy (native install, no leftovers, up to date at
2.1.212, no broken configs, no colliding/broken agent definitions — none exist).
Found 5 unused extensions safe to remove (3 skills, 2 plugins) worth ~215 est.
tokens/session, plus general clutter. Default permission mode is not `auto`. No
CLAUDE.md bloat, no slow hooks (none configured), nothing worth pre-approving (only
3 denials in-window, all `AskUserQuestion` calls the user declined).

| Component | Type | Scope | Uses (total since install) | Used in window? | Est. resident tokens | Verdict |
|---|---|---|---|---|---|---|
| mobile-app-design | Skill | user | 0 | No | ~91 | remove |
| apple-intelligence | Skill | user | 0 | No | ~23 | remove |
| autonomous | Skill | user | 0 | No | ~56 | remove (explicit-invocation-only by design, but never actually invoked) |
| ios-developer-pro | Skill | user | 4 | No (last used 2026-07-15) | ~66 | keep — real intermittent use |
| swift-lsp@claude-plugins-official | Plugin (LSP) | user | 1528 | Yes | deferred (~0) | keep |
| typescript-lsp@claude-plugins-official | Plugin (LSP) | user | 60 | Yes | deferred (~0) | keep |
| context7@claude-plugins-official | Plugin (MCP) | user | 0 | No (0-count → `lastUsedAt` is just enable-seed time) | deferred (~0) | remove — decluttering, not a token save |
| swiftui-pro@swiftui-agent-skill | Plugin (Skill) | user | 0 | No (same seed caveat); **but see correction below** | ~45 | flagged by user as a possible false negative — trigger plausibly matches recent SwiftUI work; not auto-applied |
| xcodebuild | MCP server | user | n/a (no counter) | Yes — heavy tool-call evidence | deferred (~0) | keep |

Proposed but **NOT applied** (parked at the user's request, mid-session redirect back
to this audit):
- `~/.claude/settings.json`: `skillOverrides.mobile-app-design = "off"`,
  `skillOverrides.apple-intelligence = "off"`, `skillOverrides.autonomous = "off"`,
  `enabledPlugins["context7@claude-plugins-official"] = false`,
  `enabledPlugins["swiftui-pro@swiftui-agent-skill"] = false`
- `~/.claude/settings.json`: `permissions.defaultMode = "auto"` (currently unset;
  no managed policy, no `disableAutoMode`)

No findings for: install health, local/checked-in CLAUDE.md dedup, derivable-content
trim, lazy-loading migration, slow hooks, version currency, read-only-command
pre-approval.

**Cross-reference for Phase 3 judgment (not a `/doctor` finding):** `~/.claude/CLAUDE.md`
has a "Plan / Build Separation" section mandating plan-mode-style read-then-write
discipline. The audit's own background section names "any instruction mandating plan
mode" as the canonical example of a rule that's now obsolete post-4.6. Flagging for
Phase 3's harness-review lens rather than resolving here.

**Correction discovered after `/doctor` ran:** the `/doctor` skill counted
`product-evaluation`, `feature-design`, `wrap-session`, `design-brief`, `new-product`
as this machine's own extensions when computing its report framing, but they are not
locally authored — see the cross-repo pollution finding in Phase 1. This doesn't
change `/doctor`'s verdicts above (none of those five appear in its table — its scope
was unused-extension detection, not provenance), but it matters for Phase 1's picture
of what's actually in `~/.claude/skills` and `~/.claude/commands`.

### `/context` — captured verbatim (user-run)

```
Context Usage
Model: claude-sonnet-5
Tokens: 119k/967k (12%)

Estimated usage by category:
  System prompt: 9.6k tokens (1.0%)
  System tools: 15k tokens (1.6%)
  Memory files: 2.4k tokens (0.3%)
  Skills: 2.7k tokens (0.3%)
  Messages: 89.5k tokens (9.3%)
  Free space: 814.8k (84.3%)
  Autocompact buffer: 33k tokens (3.4%)

MCP tools: all listed as deferred (loaded on-demand via /mcp), including
mcp__claude_ai_Gmail__*, mcp__claude_ai_Google_Calendar__*, mcp__claude_ai_Google_Drive__*,
mcp__plugin_context7_context7__*, and all mcp__xcodebuild__* (63 tools total).
Per-tool token costs in the full breakdown ranged ~75–1.3k tokens each (these are the
COST IF LOADED, not currently resident — the Skills row category total of 2.7k is
the honest resident number).

Memory files (all loaded):
  ~/.claude/CLAUDE.md: 1.3k tokens
  CLAUDE.md (project root): 1.1k tokens
  ~/.claude/projects/-Users-erniedefoy-Code-Ascend/memory/MEMORY.md: 65 tokens

Skills (resident listing):
  User: Mobile App Design Standards ~120, product-evaluation ~100, feature-design ~100,
        ios-developer-pro ~90, autonomous ~70, apple-intelligence ~30, new-product ~30,
        wrap-session ~30, design-brief ~20
  Plugin (swiftui-pro): swiftui-pro ~60
  Built-in: dataviz ~380, claude-api ~360, update-config ~240, verify ~150,
            code-review ~140, schedule ~130, run ~120, loop ~120,
            artifact-capabilities ~90, keybindings-help ~80,
            fewer-permission-prompts ~60, simplify ~60, security-review ~30,
            review ~30, artifact-design ~20, init ~20
```

No discrepancy between what `/context` reports as loaded and what Phase 1's file
inventory found — see the symlink resolution below for why 5 of the 9 "User" skills
don't correspond to files physically inside `~/.claude/skills`.

### `/memory` — could not capture verbatim

`/memory` opens an interactive view rather than emitting clean stdout, so it isn't
capturable as text output in this session. Substituted with equivalent evidence:
`/context`'s "Memory files" section (above, confirms exactly 3 files load: the two
CLAUDE.md files and this repo's auto-memory index) plus a manual `ls` the user ran in
`~/.claude/projects/-Users-erniedefoy-Code-Ascend/memory/`, which confirmed the
directory contains only `MEMORY.md` and one topic file, `launch-hardening-plan.md` —
matching what `MEMORY.md`'s index points to. No discrepancy found: nothing believed
loaded is missing, and nothing unexpected is present.

---

## Phase 1 — Inventory

### Root-tier and instruction files

| File | Scope | Lines | Notes |
|---|---|---|---|
| `CLAUDE.md` (repo root) | project, checked in | 43 | Only checked-in instruction file in the repo. |
| `.claude/CLAUDE.md` | project | — | Does not exist. |
| `CLAUDE.local.md` | project | — | Does not exist (root or any ancestor). |
| Nested `CLAUDE.md` (any subdirectory) | project | — | None found anywhere in the tree. |
| `~/.claude/CLAUDE.md` | user, global | 59 | Loads in every repo on this machine. |
| `~/.claude/rules/**` | user, global | — | Does not exist. |
| `.claude/rules/**` | project | — | Does not exist. |
| `.claude/skills/**` | project | — | Does not exist. |
| `.claude/agents/**` | project | — | Does not exist. |
| `~/.claude/agents/**` | user, global | — | Does not exist. |
| `.claude/hooks/**` | project or user | — | Does not exist at either level; confirmed via `/doctor`'s hook-transcript scan (zero hook runs recorded) and `jq '.hooks'` on `~/.claude/settings.json` (`[]`). |
| README (repo root) | project | — | Does not exist. |
| `AGENTS.md` / `.cursorrules` / other agent configs | project | — | Do not exist. |

### `~/.claude/skills/` — user-level skills (global, loads in every repo)

| Name | Real or symlink | Target | Provenance |
|---|---|---|---|
| `mobile-app-design` | real directory | — | Locally authored/installed |
| `ios-developer-pro` | real directory | — | Locally authored/installed |
| `apple-intelligence` | real directory | — | Locally authored/installed |
| `autonomous` | real directory | — | Locally authored/installed |
| `product-evaluation` | **symlink** | `/Users/erniedefoy/code/ai_product_builder/.claude/skills/product-evaluation/` | **Cross-repo pollution** — belongs to a different, unrelated project |
| `feature-design` | **symlink** | `/Users/erniedefoy/code/ai_product_builder/.claude/skills/feature-design/` | **Cross-repo pollution** — same source project |

### `~/.claude/commands/` — user-level commands (global, loads in every repo)

| Name | Real or symlink | Target | Provenance |
|---|---|---|---|
| `wrap-session.md` | **symlink** | `/Users/erniedefoy/code/ai_product_builder/.claude/commands/wrap-session.md` | **Cross-repo pollution** |
| `design-brief.md` | **symlink** | `/Users/erniedefoy/code/ai_product_builder/.claude/commands/design-brief.md` | **Cross-repo pollution** |
| `new-product.md` | **symlink** | `/Users/erniedefoy/code/ai_product_builder/.claude/commands/new-product.md` | **Cross-repo pollution** |

**Finding for Phase 3 judgment:** five extensions (2 skills, 3 commands) are
deliberately symlinked in from `~/code/ai_product_builder`, a separate, unrelated
project. `/context` reports them as ordinary "User" scope skills with no visual
distinction from locally-authored ones — the symlink is invisible from inside a
session. These consume skill-listing budget in **every** repo on this machine,
including this iOS repo, where "evaluate a product idea" and "scaffold a new
product" are irrelevant triggers. This is exactly the cross-repo pollution the audit
background section warns about ("Flag anything project-specific — that's cross-repo
pollution. A global skill consumes listing budget in every repo even when it never
fires."). `/doctor`'s usage counters corroborate real but foreign usage: `skillUsage`
records `"ai_product_builder:product-evaluation"` (namespaced to its origin repo),
confirming it fires there, not here.

### `.claude/skills/` — project-level skills

Does not exist. No project-scoped skills.

### `.claude/agents/**`

Does not exist at project or user level. `/doctor`'s broken/colliding-definition
scan found nothing to report (there's nothing to scan).

### Settings files

| File | Exists? | Parses? | Governs |
|---|---|---|---|
| `~/.claude/settings.json` | Yes | OK | User scope, every repo |
| `.claude/settings.json` (project) | No | — | — |
| `.claude/settings.local.json` (project) | No | — | — |
| `~/.claude.json` | Yes | OK | User-level app state (usage counters, MCP config, plugin config) |
| `.mcp.json` (project) | No | — | — |

No multi-level settings conflict to flag — the project has no settings files of its
own, so there's nothing for a user-scope setting to silently fail to override.

**Settings check** (`~/.claude/settings.json`, `~/.claude.json`):
- `autoMemoryDirectory`: unset (default — repo-unique, no cross-repo sharing risk)
- `claudeMdExcludes`: unset
- `skillListingBudgetFraction`: unset (default ~1%)
- `skillListingMaxDescChars`: unset (default 1,536)
- `skillOverrides`: unset — nothing currently disabled
- `permissions.defaultMode`: unset — not `auto` (see `/doctor` finding above)
- No managed-policy settings files found on this machine.

### MCP servers

| Server | Scope | Deferred? | Configured via |
|---|---|---|---|
| `xcodebuild` | user | Yes (`alwaysLoad: false`) | `~/.claude.json` top-level `mcpServers` |
| `mcp__plugin_context7_context7__*` | plugin (context7) | Yes | plugin config |
| `mcp__claude_ai_Gmail__*`, `Google_Calendar`, `Google_Drive` | claude.ai connectors | Yes | — |

No project-scoped MCP servers (`.mcp.json` absent).

### Auto memory (`~/.claude/projects/-Users-erniedefoy-Code-Ascend/memory/`)

Two files:

**`MEMORY.md`** (index, 1 entry, well under the 200-line/25KB budget):
```
# Memory index

- [Launch hardening plan](launch-hardening-plan.md) — 9-slice post-audit fix sequence (2026-07-16), status tracked per slice
```
Note: the index line says "9-slice" but the topic file it points to actually
documents **11** slices (LH-1 through LH-11) — the index summary itself has drifted
from its own topic file. Minor, but a concrete inaccuracy to flag for Phase 3.

**`launch-hardening-plan.md`** (project memory, type: project):
Documents an 11-slice launch-hardening execution plan from 2026-07-16. All 11 slices
show `[x]` done **except slice 6, "Workout draft persistence,"** which is still
`[ ]` pending — this is a real open item, not stale content; distinct from the doc
files' staleness issues found in Phase 2. The memory's own closing line ("ALL 11
SLICES COMPLETE") technically contradicts the `[ ]` on slice 6 — internal
inconsistency worth flagging for Phase 3 (auto memory contradiction check).

### Global tier (`~/.claude/`)

Already covered above: `CLAUDE.md` (59 lines, generic engineering discipline, no
project-specific content detected — nothing here reads as Ascend-specific), 4
locally-authored skills, 5 symlinked-in cross-repo skills/commands, no rules
directory, no agents directory, one settings file (parses clean, mostly-default
values).

---

## Phase 2 — Staleness triage

Delegated to two subagents (read-heavy, small-output). Findings below are compiled
from their reports; both did file:line-level verification against actual code and
git history rather than trusting doc prose.

### Group A — architecture/data docs

| File | Verdict | What's wrong (if drifted) |
|---|---|---|
| `docs/ARCHITECTURE.md` | **DRIFTED** | The dependency-rule diagram (its central claim, lines 9–17) omits the `SupabaseBackend` module entirely, even though `Project.swift:4-11,70-77` and the doc's own prose (line 28) both acknowledge it exists as a real dependency of the `Ascend` app target. All other module-boundary claims (`Domain -> Foundation`, `DataInterfaces -> Domain`, etc.) verified CURRENT against `Project.swift:122-190`. |
| `docs/DATA_MODEL.md` | CURRENT | All documented Domain types verified to exist with matching names in `Modules/Domain/Sources/`. `EngagementInvite.generateCode()` and its alphabet verified verbatim. Progress-photo "data layer ships dark" claim corroborated by commit `0173de9`. |
| `docs/BACKEND.md` | CURRENT | Freshest of the four — `InMemoryStore.seeded()`, `SupabaseBackend.paymentGateway` → `NoOpPaymentGateway`, migration counts, `SignUpOutcome`/`AuthGatewayError.emailNotConfirmed`, and device-token push wiring all verified against exact file:line locations, matching the LH-1 through LH-11 sequence. |
| `docs/CONVENTIONS.md` | DRIFTED (minor) | Line's example feature-folder path (`Modules/Features/Sources/Engagements/...`) references a folder that doesn't exist. Actual folders: `Auth`, `Clients`, `CoachRoot`, `ConsumerRoot`, `Messaging`, `Programs`, `Progress`, `ProofProfile`, `PushSupport`, `RoleActivity`, `Schedule`, `Settings`, `Today`, `PreviewSupport`. The organizing principle stated is still true; only the named example is stale. |

### Group B — product/roadmap/testing/design docs

| File | Verdict | What's wrong (if drifted) |
|---|---|---|
| `docs/PRODUCT.md` | CURRENT | Few checkable claims; the one concrete pointer (marketplace ~Prompt 15) is internally consistent with ROADMAP.md. |
| `docs/ROADMAP.md` | CURRENT | All 11 "Launch hardening" checkboxes (LH-1…LH-11) are ticked, matching the 11 real commits — each commit updated the checkbox atomically. Prompt 13's migration count and DP-1/DP-2's filename references verified correct. |
| `docs/TESTING.md` | **DRIFTED** | Points to a root `README` for exact test-invocation syntax — no `README.md` exists at repo root. Lists 4 test targets (`DomainTests`, `DataInterfacesTests`, `InMemoryStoreTests`, `FeaturesTests`); `Project.swift` now also defines `DesignSystemTestsTarget`, `SupabaseBackendTestsTarget`, `SupabaseBackendIntegrationTests`, `AscendTests`, `AscendUITests`. File predates `SupabaseBackend`'s introduction and was never updated (last touched 2026-07-12, before Prompt 13). |
| `docs/TESTABILITY.md` | CURRENT | Demo-harness file list, `UserDefaults` key, and the LH-9 payment-outcome-control removal all verified exactly. |
| `docs/BUILD_STATUS.md` | **DRIFTED — most stale file in the repo** | (1) Dangling cross-reference to a "Launch hardening" section that doesn't exist anywhere in the file. (2) Header still says "Last updated 2026-07-14 (through Prompt 13)" despite substantial later edits (last real git touch 2026-07-16) and content that goes past Prompt 13. (3) Of 11 LH commits, only LH-9 gets a passing mention — the doc's stated purpose is "the at-a-glance done/next/needs-you view," and it's missing most of what's actually happened. (4) Runbook D says `db push` "creates all 19 tables" — LH-3 and LH-11 added 2 more migrations since; actual current count is 21 tables across 15 migration files. |
| `docs/E2E_TESTABILITY_PROMPT.md` | CURRENT | A paste-to-execute prompt template, already executed; all its doc cross-references resolve to real files. |
| `docs/PRIVACY_POLICY.md` | **DRIFTED — highest user-facing consequence** | Cites `EngagementProgressView+Photos.swift` as evidence of no-consent/no-photo-UI behavior — that file was deleted in commit `0173de9` (LH-8), ~7 minutes after this doc's last edit, never reconciled. More substantively: both this doc (lines 15, 25-28) and its in-app mirror `PrivacyPolicyView.swift` still describe progress-photo sharing as a live, user-facing consent flow, but LH-8 hid the photo UI for launch — users have no way to exercise the consent flow this document describes. |
| `docs/design/CLAUDE_DESIGN_BRIEF.md`, `DESIGN_SPEC.md`, `SCREEN_INVENTORY.md` | CURRENT (light check — untracked, brand-new) | Referenced paths all exist. Minor: `SCREEN_INVENTORY.md` labels the coach messaging tab "Inbox"; actual code label is "Messages" (`CoachRootView.swift:87`). Cosmetic. |
| `docs/design/handoff/HANDOFF_README.md` | **DRIFTED (mechanical)** | Refers to the canvas file as `Ascend Screens.dc.html` (with a space) in two places; actual filename on disk is `AscendScreens.dc.html` (no space) — an internal typo, inconsistent with ROADMAP.md's own correct references. Also references `support.js` as "DC runtime (reference only)" — this file does not exist anywhere in the repo or in `ascend-claude-design-bundle.zip`. Phantom file reference. |

### Untracked / not-yet-committed content

`docs/design/*` (except `mockups.html`, which is inside the zip) and `docs/plans/*`
are new, untracked files (`git status` showed them `??` at session start) — no git
history to check drift against; verified by direct content/path inspection instead
(see table above). `supabase/` at repo root is also untracked but contains only
Supabase CLI local cache (`linked-project.json`, version files) — not documentation,
not covered by this audit's doc-staleness scope.

### Summary

| File | Verdict |
|---|---|
| `docs/ARCHITECTURE.md` | DRIFTED |
| `docs/DATA_MODEL.md` | CURRENT |
| `docs/BACKEND.md` | CURRENT |
| `docs/CONVENTIONS.md` | DRIFTED (minor) |
| `docs/PRODUCT.md` | CURRENT |
| `docs/ROADMAP.md` | CURRENT |
| `docs/TESTING.md` | DRIFTED |
| `docs/TESTABILITY.md` | CURRENT |
| `docs/BUILD_STATUS.md` | DRIFTED (most stale) |
| `docs/E2E_TESTABILITY_PROMPT.md` | CURRENT |
| `docs/PRIVACY_POLICY.md` | DRIFTED (highest user-facing consequence) |
| `docs/design/CLAUDE_DESIGN_BRIEF.md` | CURRENT |
| `docs/design/DESIGN_SPEC.md` | CURRENT |
| `docs/design/SCREEN_INVENTORY.md` | CURRENT (minor cosmetic drift) |
| `docs/design/handoff/HANDOFF_README.md` | DRIFTED (mechanical) |
| `CLAUDE.md` (root) | Not doc-staleness-checked in Phase 2 (it's process, not product/architecture) — see Phase 0/1 notes and the plan-mode cross-reference above for Phase 3 judgment. |

**END SESSION 1.**
