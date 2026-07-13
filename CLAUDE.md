# CLAUDE.md

Guidance for Claude Code (and any future orchestrator) working in this repository.

## How to work here

- Read `docs/` first: `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`,
  `docs/DATA_MODEL.md`, `docs/BACKEND.md`, `docs/CONVENTIONS.md`,
  `docs/TESTING.md`, and `docs/ROADMAP.md`. They are the source of truth; this file
  is about process, not product/architecture detail.
- The dependency rule (enforced by Tuist module boundaries — do not violate it):
  - `Domain` -> Foundation only.
  - `DataInterfaces` -> `Domain`.
  - `InMemoryStore` -> `DataInterfaces`, `Domain`.
  - `DesignSystem` -> (none).
  - `Features` -> `DesignSystem`, `DataInterfaces`, `Domain`.
  - `Ascend` (App) is the **only** composition root — the only target allowed to
    depend on a concrete backend adapter and wire it in.
- Add/remove files by editing `Project.swift` globs, then regenerate with
  `tuist generate`. **Never** hand-edit `.xcodeproj` / `.xcworkspace` internals —
  they are generated and gitignored.
- `InMemoryStore` is the default backend: `DEBUG` builds use
  `InMemoryStore.seeded()`. The whole app, its previews, and its unit tests run
  against it with zero backend cost (see docs/BACKEND.md, docs/TESTING.md).
- Convention after each prompt: update code/tests/docs, tick the prompt's box in
  `docs/ROADMAP.md`, commit, and push to `origin`.

## Execution Protocol

You are the Opus orchestrator. Do not implement features yourself. (1) Read the docs
the prompt names — this CLAUDE.md is already in context. (2) Write a short execution
plan. (3) Dispatch ONE fresh-context Sonnet subagent to execute: Agent tool,
subagent_type 'general-purpose', model 'sonnet', run_in_background false; give it a
complete self-contained brief (plan + task + doc pointers + Definition of Done).
Tell it to: add/remove files via Project.swift globs; regenerate with
`tuist generate`; NEVER hand-edit .xcodeproj internals; ACTUALLY BUILD AND TEST so
the code genuinely works — run `tuist generate`, then `xcodebuild build` and
`xcodebuild test` on an iOS simulator (or `swift test` for pure-Swift modules) plus
SwiftLint; fix compile/test failures and iterate until the build is clean and tests
pass; tick this prompt's box in docs/ROADMAP.md; commit; and `git push` to origin.
(4) Confirm the build succeeded, tests passed, and the commit is pushed to GitHub,
then report status. If short (build errors/failing tests), dispatch another Sonnet
subagent with the gap.
