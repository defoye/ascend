# Doc Audit — Session 3 Verification (Phase 6)

Self-contained record of what was executed in Session 3 (Phases 5–6) and what
was empirically verified afterward. Read alongside `doc-audit-plan.md` (what
was supposed to happen) and `doc-audit-inventory.md` (the Session 1 baseline).

---

## 1. `/doctor`, `/context`, `/memory` — could not be re-invoked this session

These are interactive CLI meta-commands the user runs directly; Session 3 has
no tool that invokes them programmatically, so I cannot produce a live
before/after diff the way Phase 6 asks for. Fabricating their output would
violate "report only observed results" — flagging this rather than guessing.

What I verified instead, directly against the filesystem:

| Tier | Session 1 baseline | After Session 3 |
|---|---|---|
| Root `CLAUDE.md` | 43 lines, ~1.1k tok (per Session 1's `/context` capture) | 47 lines (`wc -l` confirmed) |
| `.claude/rules/` | did not exist | 3 files, all `paths:`-scoped: `project-structure.md` (35 lines), `swift-conventions.md` (45 lines), `privacy-sync.md` (14 lines) |
| `.claude/skills/` (project) | did not exist | 2: `execute-roadmap-prompt/SKILL.md` (26 lines, model+user invocable), `release-deploy/SKILL.md` (124 lines, `disable-model-invocation: true`) |
| `docs/` (top-level `.md`) | 15 files, ~2,181 lines per Session 1's Phase 1 inventory | 12 files, 1,192 lines (`wc -l docs/*.md`) — 3 deleted (`BUILD_STATUS.md`, `CONVENTIONS.md`, `E2E_TESTABILITY_PROMPT.md`), 1 renamed (`TESTABILITY.md` → `DEMO_HARNESS.md`), rest trimmed/refreshed |
| Auto memory | 2 files, 2 known contradictions (9-vs-11-slice index drift; slice-6 checkbox vs "ALL COMPLETE" line) | 2 files, both contradictions fixed (see §5) |

**Someone should re-run `/doctor` and `/context` in a fresh session** to get
the authoritative post-audit resident-token numbers — the `.claude/rules/`
and `.claude/skills/` directories didn't exist when Session 1 captured its
baseline, so there is no way to diff their listing-budget cost from inside
this session (see §2 for why a fresh session matters here specifically, not
just for this report).

## 2. Path-scoped rule verification

**Glob expansion (confirmed against the real tree):**

| Rule | Globs | Matches |
|---|---|---|
| `project-structure.md` | `Project.swift`, `Modules/**` | `Project.swift` (1 file); `Modules/**` → 317 files |
| `swift-conventions.md` | `**/*.swift` | 324 `.swift` files repo-wide |
| `privacy-sync.md` | `docs/PRIVACY_POLICY.md`, `**/PrivacyPolicyView.swift`, `**/PrivacyInfo.xcprivacy` | all three resolve to exactly one real file each: `docs/PRIVACY_POLICY.md`, `Modules/Features/Sources/Settings/PrivacyPolicyView.swift`, `App/Resources/PrivacyInfo.xcprivacy` |

No glob matched zero files; no stray bracket expressions in any of the three.

**Read-a-matching-file / read-a-non-matching-file (inconclusive — flagging,
not asserting):**

I read `Modules/DesignSystem/Sources/AscendHaptics.swift` and
`Modules/Domain/Sources/Engagement.swift` (both should match
`project-structure.md` and `swift-conventions.md`) and `docs/PRODUCT.md`
(should match none of the three rules). No rule content surfaced as a
system-reminder after either Read call.

This is **not proof the rules are broken** — the three rule files were
authored earlier in this same session, and rule indexing may only happen at
session start rather than being rescanned live. I did not register an
`InstructionsLoaded` hook to get a definitive answer: doing so requires
editing `.claude/settings.json`, which Phase 5's constraints reserve for
changes the approved plan explicitly calls for (the plan found "no project
settings changes required"), and Session 3 shouldn't add one unilaterally
mid-verification. **Recommend**: re-open a fresh session in this repo and
repeat this exact check (read a matching `.swift` file, confirm the rule
surfaces; read a non-matching file, confirm it doesn't) before trusting that
these rules are live.

## 3. Path existence

Every path referenced in the new root `CLAUDE.md` and the three rules
resolves to a real file/directory — checked individually with `ls`/`test -e`:
all 8 `docs/*.md` pointers, `docs/design`, all 3 rule files, both skill
`SKILL.md` files, `Project.swift`, `.swiftlint.yml`, `Scripts/lint.sh`, and
all three `privacy-sync.md` targets. Zero misses.

## 4. Command verification

- `tuist generate` — ran clean, regenerated `Ascend.xcworkspace` (6.4s).
- `xcodebuild test -workspace Ascend.xcworkspace -scheme Ascend -destination
  'platform=iOS Simulator,id=<iPhone 16 sim>'` — **TEST SUCCEEDED**. 21
  `AscendTests` (Swift Testing) + 1 `AscendUITests` (XCTest,
  `DemoHarnessUITests`) all passed.
- `bash Scripts/lint.sh` — **0 violations across 263 files.**

**Finding — doc inaccuracy in `.claude/rules/swift-conventions.md` (written
this session, caught verifying it):** the rule currently claims "This one
scheme covers every module's `<Module>Tests` target." That's false. Checked
via `xcodebuild -workspace Ascend.xcworkspace -list`: the `Ascend` scheme's
only testables are `AscendTests` and `AscendUITests` (confirmed against
`Ascend.xcodeproj/xcshareddata/xcschemes/Ascend.xcscheme`'s `<Testables>`
block). `DomainTests`, `DataInterfacesTests`, `InMemoryStoreTests`,
`SupabaseBackendTests`, `DesignSystemTests`, and `FeaturesTests` each run
under their own module scheme (`Domain`, `DataInterfaces`, `InMemoryStore`,
`SupabaseBackend`, `DesignSystem`, `Features` — all present in the scheme
list). This is corroborated by the auto-memory record itself: the LH-11 entry
in `launch-hardening-plan.md` lists per-target counts from that slice's own
verification ("InMemoryStore 45 / Features 195 / DataInterfaces 5 / Ascend
21+1UI"), meaning the actual historical practice was running each module
scheme separately, not one aggregate. Per this session's instructions
("report anything that failed verification rather than quietly fixing it"),
I'm leaving `swift-conventions.md` as written and flagging this rather than
silently rewriting it. **Suggested fix for next session:** either (a) list
all 7 module schemes as the real full-suite invocation, or (b) explicitly
scope the documented command to "smoke-test the app + its own unit/UI tests"
and separately note the other 6 schemes for full coverage.

## 5. Contradiction sweep

Read root `CLAUDE.md`, all three rules, and both auto-memory files side by
side. No contradictions found between them:

- `CLAUDE.md` doesn't restate the dependency rule or the test command — both
  correctly deferred to the rules, so there's nothing to drift out of sync
  with.
- `swift-conventions.md`'s file-organization note and `project-structure.md`'s
  Tuist-workflow note don't overlap.
- `privacy-sync.md` doesn't conflict with `docs/PRIVACY_POLICY.md`'s content.
- Auto memory: `MEMORY.md`'s index now says "11-slice" (was "9-slice");
  `launch-hardening-plan.md`'s slice 6 is now `[x]` with a note explaining the
  correction (verified `WorkoutSessionDraftStore.swift` +
  `WorkoutSessionDraftTests.swift` exist in
  `Modules/Features/Sources/ConsumerRoot/` and `Modules/Features/Tests/`).
  The "ALL 11 SLICES COMPLETE" closing line is now consistent with every
  checkbox above it.

(Global `~/.claude/` tier intentionally out of scope per the plan — deferred
to Session 4's separate gate.)

## 6. Map test — three plausible tasks

| Task | Routes to | Correct? |
|---|---|---|
| "Add a field to an `Engagement`" | `docs/DATA_MODEL.md` (doc map: "Read before touching `Domain` types...") + `.claude/rules/swift-conventions.md` (fires automatically on any `.swift` edit; its file-organization note is exactly relevant) | Yes |
| "Wire a new backend call" | `docs/BACKEND.md` (doc map: "Read when working on persistence, sync, payments, or the Supabase adapter") + `.claude/rules/project-structure.md` (fires on `Modules/**`, which is where the new adapter code would live; its dependency rule is exactly what a new backend call must respect) | Yes |
| "Change privacy copy" | `docs/PRIVACY_POLICY.md` (doc map: "Read when data collection changes") + `.claude/rules/privacy-sync.md` (fires on the policy doc itself, `PrivacyPolicyView.swift`, or `PrivacyInfo.xcprivacy` — the exact three-way sync this task risks breaking) | Yes |

All three route correctly *assuming the rules actually fire live* — see §2's
open question. The `CLAUDE.md` doc-map pointers themselves are confirmed
correct independent of that; rule triggering is the one piece of this
routing that needs a fresh-session re-check.

## Deletions and repointing performed (for reference)

- Deleted: `docs/E2E_TESTABILITY_PROMPT.md`, `docs/BUILD_STATUS.md`,
  `docs/CONVENTIONS.md` (all after salvaging their live content — runbooks
  into `release-deploy`, rollout-strategy rationale into `docs/BACKEND.md`,
  conventions into `.claude/rules/swift-conventions.md` and
  `execute-roadmap-prompt`).
- Renamed: `docs/TESTABILITY.md` → `docs/DEMO_HARNESS.md` (brainstorm section
  dropped; "what shipped" + "how to use it" kept).
- Repointed every dangling cross-reference found by grep, including 14
  Swift-file doc comments citing `docs/BUILD_STATUS.md`,
  `docs/CONVENTIONS.md`, or `docs/TESTABILITY.md` — not just the `docs/`
  cross-references the plan explicitly named. This went slightly beyond the
  plan's enumerated grep targets (root `CLAUDE.md` + doc cross-refs) but
  matches its stated intent ("Grep the repo for `X` references and repoint
  them") followed literally rather than narrowly.
- `docs/ROADMAP.md` gained an "Owner actions outstanding" section (folding
  `BUILD_STATUS.md`'s "What needs you" list, updated with LH-11's newer
  owner actions) and a note on the stray unchecked Prompt 10 entry (previously
  only explained in the now-deleted `BUILD_STATUS.md`).
- Auto memory: `MEMORY.md` and `launch-hardening-plan.md` both corrected (see
  §5).

**END SESSION 3.**
