# Documentation Audit & Restructure

⚠ EXECUTION CONTROL — READ FIRST
This file describes a FOUR-SESSION sequence. Execute ONLY the session you were
told to execute. Stop at its end. Do not continue into the next session. The
/clear and /model boundaries between sessions are handled by the human, not by
you. If you were not told which session to run, ask.

Goal: audit, refresh, and restructure this repository's documentation and Claude
Code configuration into a properly tiered, self-discovering system — then extract
whatever is genuinely portable so future repos inherit it.

## The sequence

  Session 1 — Phases 0–2 — SONNET — inventory + staleness verification
  Session 2 — Phases 3–4 — OPUS   — classify + routing plan      [APPROVAL GATE]
  Session 3 — Phases 5–6 — SONNET — execute + verify
  Session 4 — Phases 7–8 — OPUS   — report + portable layer      [APPROVAL GATE]

The boundaries are load-bearing. This task is context-bound, not
capability-bound: a large audit crammed into one session degrades regardless of
model, which is the exact problem this exercise exists to fix. Phases 0–2 and 5–6
are mechanical and high-volume (git log, path checks, careful edits against an
approved plan). Phases 3–4 and 7–8 are judgment (delete-vs-demote, routing,
what's vestigial, what generalizes) — that's where the stronger model earns its
cost, and it's the minority of the work.

Each session writes its output to docs/plans/ so the next starts from the
artifact and none of the exploration.

Use auto mode. Sessions 1 and 2 are read-only by design; Sessions 3 and 4 execute
against an approved plan and stop at explicit gates. Do not use plan mode — the
gates already serve that purpose, and current models plan implicitly.

---

# BACKGROUND — the model we're building toward

The governing constraint is context. Every always-loaded line is a tax on every
session, and adherence degrades as context fills. The test for any piece of
documentation is not "is this true?" but "does its absence cause a mistake?"

Content routes by LOAD FREQUENCY, not importance. Valuable-but-occasional
knowledge sitting in an always-loaded file is what makes the always-loaded file
useless. Demote, don't delete.

| Tier                             | Loads                                      | Contents                                 |
|----------------------------------|--------------------------------------------|------------------------------------------|
| Root CLAUDE.md                   | Always; survives compaction                | Pointers + critical gotchas. <200 lines. |
| .claude/rules/*.md (no paths:)   | Always, at root priority                   | Should be nearly empty — see TRAP        |
| .claude/rules/*.md (with paths:) | When Claude reads matching files           | Scoped constraints                       |
| Nested <dir>/CLAUDE.md           | At launch if started there; else on demand. NOT re-injected after compaction | Local commands/conventions |
| Skills                           | Description always; body on invoke, then persists | Procedures, workflows             |
| Skill supporting files           | Only when SKILL.md points at them          | Long reference material                  |
| docs/                            | Only when explicitly read                  | Decisions, rationale, plans              |
| Auto memory (MEMORY.md)          | First 200 lines / 25KB, every session      | Claude's own accumulated notes           |
| Hooks                            | Deterministically                          | Non-negotiables                          |

**TRAP**: a rule WITHOUT `paths:` loads at launch at the same priority as root
CLAUDE.md. Identical in cost, harder to notice. This tier should be nearly empty.
Every rule should have `paths:` unless you can articulate why the constraint
truly applies to every file in the repo.

Mechanics to respect throughout:

- **RULES vs SKILLS**: rules are CONSTRAINTS — declarative, glob-triggered, never
  invoked, no body loaded. Skills are PROCEDURES — invocable, and once invoked the
  body persists in context for the rest of the session. "Always do X when
  touching Y" is a rule. Anything with phases, scripts, or that you run is a
  skill. NOTE: skills also support `paths:` — scoping is NOT the distinction.
  Invocability and body-loading is.
- **RULES vs NESTED CLAUDE.md**: both target part of the tree. The distinction is
  ownership and locality, not capability:
    - Nested CLAUDE.md — lives with the code, versioned alongside it, natural
      when a directory has an owner maintaining its conventions.
    - Path-scoped rule — lives centrally in root .claude/rules/. Right when you
      want all conventions in one place, or the same rule applies to many
      scattered paths.
  For a solo repo, centralizing in rules/ is usually better — one place to audit,
  and it survives compaction where nested CLAUDE.md doesn't. But say why, per
  case. Do not assert rules are more capable; they aren't.
- Skill bodies are a RECURRING cost once loaded. Keep SKILL.md under 500 lines;
  push detail into supporting files referenced from SKILL.md.
- Skill DESCRIPTIONS are always in context, budgeted at ~1% of the context window
  (`skillListingBudgetFraction`). On overflow, Claude Code drops descriptions
  starting with the least-used skills — silently. Each description + `when_to_use`
  caps at 1,536 chars (`skillListingMaxDescChars`). Key use case first.
- `@path` imports load at launch. ORGANIZATION tool, not context reduction. Do
  not use them to fake tiering.
- Nested CLAUDE.md is NOT re-injected after compaction. Root CLAUDE.md is.
  Anything that must survive belongs in root or .claude/rules/.
- CLAUDE.md and rules are context, not enforcement. Anything that MUST happen is
  a hook.
- Auto memory is keyed on the git repository and is machine-local. It does not
  leak across repos by default.

---

# SESSION 1 — Phases 0–2 — SONNET

Mechanical inventory and verification. Delegate reading to subagents so
exploration stays out of main context.

## Phase 0 — Establish what's actually loaded

Do not reinvent checks that already exist.

1. **FIRST** — record where I launched this session (repo root or subdirectory)
   and state what it implies. This determines everything downstream:
   - From a subdirectory: loads that directory's CLAUDE.md plus every ancestor's;
     skills from that dir, every parent to repo root, plus user/enterprise level.
   - From repo root: root CLAUDE.md at launch, subdirectory files on demand as
     Claude reads there; skills from EVERY subdirectory Claude touches during the
     session — which can accumulate into the hundreds.

   Note: `.claude/settings.json` loads ONLY from the starting directory and is NOT
   inherited from parent directories the way CLAUDE.md is. Flag this if the repo
   has settings files at multiple levels — root settings silently don't apply when
   starting from a subdirectory.

2. Run `/doctor`. It proposes trims for a checked-in CLAUDE.md — cutting content
   derivable from the codebase (directory layouts, dependency lists, architecture
   overviews) and keeping pitfalls, rationale, and conventions that differ from
   tool defaults. It also diagnoses skill-listing budget overflow and which skills
   are affected. Capture verbatim.

3. Run `/context`. The Skills row reports listing size AFTER the budget is applied
   — what the model actually receives. Record every category's consumption. This
   is the honest baseline; /doctor alone isn't.

4. Run `/memory`. List every instruction file actually loaded. Anything you
   believe is loaded but isn't listed is NOT in context — report the discrepancy
   explicitly. Common and invisible failure.

Report all four before your own analysis.

## Phase 1 — Inventory

Enumerate with line counts:

- Root CLAUDE.md, ./.claude/CLAUDE.md, CLAUDE.local.md
- Every nested CLAUDE.md in the tree
- `.claude/rules/**` — flag which have `paths:` and which don't. Every one WITHOUT
  `paths:` is a finding, not a neutral fact.
- `.claude/skills/**` at every level including nested — frontmatter (description,
  when_to_use, paths, user-invocable, disable-model-invocation, context, model),
  SKILL.md line counts, presence of supporting files
- `.claude/agents/**`
- EVERY `.claude/settings.json` and `settings.local.json` in the tree, at every
  level. Note which directory each governs and whether it would load given where I
  actually start sessions.
- `.claude/hooks/**` if present
- Everything under docs/ or equivalent
- Any README functioning as agent instructions
- AGENTS.md / .cursorrules / other agent configs

**AUTO MEMORY**: read `~/.claude/projects/<this-repo>/memory/MEMORY.md` and its
topic files. First 200 lines of MEMORY.md load into EVERY session — uninspected
context. Report contents.

**GLOBAL TIER**: `~/.claude/CLAUDE.md`, `~/.claude/rules/`, `~/.claude/skills/`.
These load in EVERY repo on this machine. Flag anything project-specific — that's
cross-repo pollution. A global skill consumes listing budget in every repo even
when it never fires.

**SETTINGS CHECK**: `autoMemoryDirectory` (confirm unset or repo-unique — two
repos pointed at one path would share memory), `claudeMdExcludes`,
`skillListingBudgetFraction`, `skillListingMaxDescChars`, `skillOverrides`.

Output a table. No edits.

## Phase 2 — Staleness triage

Determine whether each doc still describes reality. Do not trust the doc. Verify
against code:

- git log: doc last touched vs. code it describes last moved
- Do named files/paths exist? Do documented commands exist in package.json /
  Makefile / scripts? Do described interfaces match actual signatures?
- Flag every claim you cannot verify

Classify: CURRENT / DRIFTED (state exactly what's wrong) / UNVERIFIABLE.

Delegate to subagents. This phase reads the most and should pollute main context
the least.

**END SESSION 1** — Write Phases 0–2 to `docs/plans/doc-audit-inventory.md`,
self-contained: the next session starts from this file and nothing else. Include
/doctor, /context, /memory output verbatim, and the starting-directory finding.
Then stop.

---

# SESSION 2 — Phases 3–4 — OPUS

Fresh session. Read `docs/plans/doc-audit-inventory.md`. This is the judgment
work. Ends at an approval gate.

## Phase 3 — Classify

Every doc, and every line of root CLAUDE.md, gets one verdict:

- **DELETE** — derivable from code (directory tours, file-by-file descriptions,
  structure narration, dependency lists, architecture overviews), self-evident,
  superseded, or a standard convention the model already follows.
  Directory-structure docs are the #1 offender: they bloat AND rot, and the tree
  is never stale.
- **DEMOTE** — true and valuable but not needed every session → rules/, skills/,
  docs/
- **CONVERT** — must always hold → hook candidate (flag, don't build)
- **KEEP** — passes "would removing this cause a mistake?"

Harness-review lens: flag any rule written around an older model's limitation
that's now pure friction. Two canonical examples:
  - "break every refactor into single-file changes" — obsolete once models handle
    cross-file edits
  - **any instruction mandating plan mode** — plan mode was important for Opus 4
    through 4.5; from 4.6 on, models plan implicitly and the step is overhead
Note anything else vestigial.

Auto memory: flag anything stale, wrong, or contradicting CLAUDE.md.
Contradictions are corrosive — if two instructions conflict, Claude may pick one
arbitrarily.

Be willing to conclude a doc should simply not exist. The bias in an audit is to
find a home for everything; resist it.

## Phase 4 — Propose the target structure  ← STOP FOR MY APPROVAL

Full routing plan: every surviving piece of content, its destination, and why.

**Routing rules:**

- Root CLAUDE.md becomes a MAP, not a knowledge base. Pointers and critical
  gotchas only. Target <200 lines. Every pointer gets: where it is, what's in it,
  and WHEN TO GO READ IT. That third part is what makes discovery self-triggering
  rather than something I invoke by hand.
- Default destination for scoped constraints is `.claude/rules/` WITH `paths:`. A
  rule without `paths:` needs explicit justification for why it applies to every
  file in the repo — otherwise it's root CLAUDE.md with extra steps.
- For each rule vs nested CLAUDE.md decision, state the reason in terms of
  ownership/locality vs centralization — not capability. Both can scope.
- Skills: apply the rules-vs-skills test (constraint vs procedure). For each:
  - `paths:` — scope it if it only applies to certain files
  - `when_to_use` — trigger phrases; appends to description, counts toward the
    same 1,536-char cap
  - `user-invocable: false` — pure background knowledge that isn't a meaningful
    command
  - `disable-model-invocation: true` — anything with side effects (deploy, commit,
    release) where I control timing. NOTE: this also removes the description from
    Claude's context entirely, freeing listing budget.
  - `context: fork` — only for skills with an actual task; never for
    reference-only content (a forked reference skill returns nothing useful)
  - `model:` — pin only where genuinely needed; don't scatter these
- **SKILL SCOPING**: default to project (`.claude/skills/`) — committed,
  versioned, visible to collaborators. Promote to `~/.claude/skills/` ONLY if the
  skill encodes ZERO facts about this repo. Erring global is worse than erring
  project: a global skill fires in unrelated repos AND eats listing budget
  everywhere. When ambiguous: project. Same test for `~/.claude/rules/` and
  `~/.claude/CLAUDE.md`.
- **SETTINGS**: if the inventory found settings.json at multiple levels, or root
  settings that don't load given where I start sessions, propose the fix.
- **Auto memory**: propose deletions for stale/contradictory entries. Anything
  that's durable project policy should be promoted to a versioned file — auto
  memory isn't committed and teammates never see it.
- **CONSOLIDATE**. Fewer, larger, sharply-named docs route better than many small
  fuzzy ones — for me, for you, and for the listing budget. Consolidation is a
  discovery strategy, not tidiness.
- **RENAME** so filenames encode trigger conditions and answer greps.
  `docs/decisions/server-authority.md` self-triggers; `docs/adr-007.md` never
  will.
- **SHALLOW** tree. Root map → destination. Not root → index → sub-index. Every
  hop is a chance not to take it.

**Also report:**

- Skill-listing budget: count of skills, descriptions near/over 1,536 chars, what
  /context showed the listing actually costs, and what it will cost after. If over
  budget, say which skills are currently being silently truncated.
- Hook candidates (list; do not build).
- A proposed Stop hook for doc maintenance: a Stop hook receives the session
  transcript path when Claude finishes, so a script can review the session and
  PROPOSE CLAUDE.md/rules updates while the gap is fresh. Propose as a review step
  surfacing suggestions I accept — never silent writes. Flag it; don't build it.
  (If I later build it: exit 1 does NOT block; policy hooks must exit 2. Note this
  in the proposal.)
- Optional: the OTEL `skill_activated` event records every skill invocation and
  `invocation_trigger` records what invoked it — the only real way to find unused
  skills. Mention if the skill count warrants it.

Before/after line counts per tier, plus projected always-loaded total.

**END SESSION 2** — WAIT FOR MY APPROVAL. Then write
`docs/plans/doc-audit-plan.md`, specific enough that a fresh session executes it
without re-deriving judgment: exact source → destination per item, exact
frontmatter per rule and skill, exact deletions, exact settings changes. Then
stop.

---

# SESSION 3 — Phases 5–6 — SONNET

Fresh session. Read `docs/plans/doc-audit-plan.md` and execute it. The judgment is
made — do not relitigate it. Where the plan is wrong or ambiguous, STOP AND ASK
rather than deciding.

## Phase 5 — Execute

1. Delete what's marked DELETE.
2. REFRESH survivors: correct every DRIFTED claim against actual code. Rewrite
   copies as pointers — "auth lives in src/auth/" survives a refactor that a
   description of the auth flow doesn't. Never paste code; point at the exemplar
   file. High-churn facts become references to the source of truth, not
   duplicates.
3. Move content to target tiers. Write rules/ with correct `paths:` globs. Write
   skill frontmatter per plan.
4. Rewrite root CLAUDE.md as the map.
5. Rewrite every skill description as a TRIGGER CONDITION, not a summary:
   - BAD: "Poker engine documentation"
   - GOOD: "Use when modifying hand evaluation, pot splitting, or anything
     touching the game engine's public interface"

   Describe what I'm DOING, not what the doc CONTAINS — you match against a task,
   not a library. Lead with words a real request would contain. Key use case
   FIRST; text truncates at 1,536 chars.
6. Apply settings changes per plan.
7. Prune auto memory per plan.

**Constraints:**
- Do not invent documentation for undocumented things.
- Do not write hooks.
- Do not delete anything not on the approved list.
- Do not write to `~/.claude/` in this session.
- Preserve human-facing README content — that's for people. Don't fold it into
  CLAUDE.md.
- Use HTML comments for maintainer notes in CLAUDE.md: they're stripped before
  injection into context, so they cost zero tokens.
- Write imperatively and concretely enough to verify: "Use 2-space indentation"
  not "format code properly." Ambiguity costs adherence.

## Phase 6 — Verify empirically

Do not assert the new structure works. Demonstrate it.

1. Re-run `/doctor`, `/context`, `/memory`. Show the before/after diff in reported
   context cost against the Phase 0 baseline. /context's Skills row is the honest
   number.
2. **PATH-SCOPED RULE VERIFICATION** — the part most likely to be silently wrong.
   For each path-scoped rule, do BOTH:
   - a. Expand its glob against the actual tree and list matching files.
   - b. Actually read a file that should match and one that shouldn't, and confirm
     the rule fires and doesn't, respectively.

   If available, register an `InstructionsLoaded` hook — it logs exactly which
   instruction files are loaded, when, and why, and exists specifically for
   debugging path-specific rules. Use it, report the log, then remove it.

   A glob that matches nothing fails silently. Also: a malformed bracket
   expression matches nothing while the rule's other patterns keep working — check
   for a stray opening square bracket.
3. Confirm every path referenced in new docs exists.
4. Confirm every command referenced actually runs.
5. Contradiction sweep across root CLAUDE.md, rules/, nested CLAUDE.md, auto
   memory, and global `~/.claude/` files. Conflicting instructions are worse than
   missing ones.
6. Test the map: pick three tasks I'd plausibly ask for. For each, state which docs
   the root map would route you to and whether that's correct. If a pointer
   wouldn't fire, the "when to read it" line is wrong.

**END SESSION 3** — Write results to `docs/plans/doc-audit-verify.md`. Report
anything that failed verification rather than quietly fixing it. Then stop.

---

# SESSION 4 — Phases 7–8 — OPUS

Fresh session. Read the three plan artifacts. Phase 8 is the only step reaching
outside this repo. Ends at a gate.

## Phase 7 — Report

- Before/after line counts per tier and total always-loaded context, from the
  /context numbers, not estimates.
- What moved where; what was deleted.
- What was stale and got corrected — this is what I most want to see.
- What failed verification.
- Hook candidates, unbuilt.
- The Stop-hook doc-maintenance proposal, unbuilt.
- Anything unverifiable, and why.
- **"How to maintain this":**
  - Diagnostics: Claude violates a rule that exists → file too long, rule got
    buried. Claude asks something the docs answer → phrasing ambiguous. A rule that
    doesn't measurably change behavior is dead weight — test by removing it and
    watching.
  - Add-trigger: I correct the same thing twice → that's a missing line. Add the
    shortest concrete instruction that would have prevented it. Write the fix down
    rather than re-prompting: a conversational correction fixes one run, a written
    rule fixes every future run.
  - Review in PRs, like any other doc change.
  - Cadence: every 3–6 months and after every major model release. Model releases
    are the important trigger — plan mode is the proof: correct advice for a year,
    then overhead.

## Phase 8 — Extract the portable layer  ← SEPARATE APPROVAL GATE

⚠ This is the only step affecting every repository on this machine. A mistake here
is invisible — it degrades unrelated work and I won't know which repo it's
hurting. PROPOSE ONLY. Do not write to `~/.claude/` without explicit approval, and
list exactly what would be created/modified so it's trivially reversible.

⚠ CONTEXT MINIMALISM: Anthropic's current guidance is that today's models need
less scaffolding, not more — give the model a lean brief and a way to fetch what
it needs, then get out of the way. A meta-skill IS scaffolding. Build the smallest
thing that transmits the decision procedure. If the honest answer is that most of
this doesn't need to generalize, say so — that's a real result.

1. Identify every rule or skill encoding ZERO facts about this repository. Apply
   the scoping test strictly: when ambiguous, it stays project-scoped. High bar.

2. Portable CONSTRAINTS → propose `~/.claude/rules/` files WITH `paths:` scoped to
   the relevant language/filetype, so they cost nothing in repos where they don't
   apply. (Swift conventions scoped to Swift files fire in every Swift repo,
   silent in a TypeScript one.) A global rule without `paths:` is a serious
   mistake — it loads at root priority in every repo forever.

3. Portable PROCEDURES → propose `~/.claude/skills/` entries. Note the cost: every
   global skill's description occupies listing budget in every repo, competing with
   that repo's own skills, and on overflow the least-used descriptions get dropped
   silently. A rarely-used global skill can push out a frequently-used project one.

4. Author `~/.claude/skills/docs-architecture/SKILL.md` — a meta-skill applying
   this architecture to a NEW repo. This is the one case where global scope is
   unambiguously correct: zero facts about any repo.

   Contents:
   - Tier table + load-frequency routing principle
   - The rules-vs-skills test (constraint vs procedure), correctly stated: both
     support `paths:`; the difference is invocability and body-loading
   - The rules-vs-nested-CLAUDE.md test (ownership/locality vs centralization)
   - The no-`paths:`-rule trap
   - The scoping test (project by default; global only for zero-repo-facts)
   - "Does its absence cause a mistake?"
   - The DELETE list (directory tours, structure narration, derivable content)
   - Trigger-condition phrasing; key use case first; 1,536-char cap
   - Root CLAUDE.md as map: where / what / when to read it
   - The Opus-plans / Sonnet-executes split with /clear boundaries, so a future
     audit runs the way this one did
   - Diagnostics and review cadence, with model releases as the key trigger

   Description as a trigger condition, e.g.: "Set up or audit Claude Code
   documentation structure — CLAUDE.md, .claude/rules/, and skills — using
   context-tiered routing. Use when starting a new repo, when CLAUDE.md has grown
   past ~200 lines, or when auditing existing docs for staleness."

   Keep SKILL.md under 500 lines. Push the audit procedure and templates into
   supporting files referenced from SKILL.md so they load only when needed:

       ~/.claude/skills/docs-architecture/
       ├── SKILL.md       # tiering model + routing rules
       ├── audit.md       # the phased audit procedure, for existing repos
       └── templates/
           ├── root-claude-md.md
           └── rule-example.md

   The description is the only part costing anything in every repo. Make it short.

5. Report the proposal and confirm each entry passes the zero-repo-facts bar. List
   what you considered and REJECTED, with why — I want to see the rejections. A
   short list here is a good sign. If the honest answer is "only the meta-skill
   generalizes," say so; that's a real result, not a failure.

6. Note that the global layer is itself a harness and rots the same way — same 3–6
   month / post-model-release review, arguably more urgent, since a stale global
   rule degrades every repo at once.

Do not write to `~/.claude/` without my approval.
