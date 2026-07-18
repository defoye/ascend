---
name: execute-roadmap-prompt
description: Use when implementing a numbered prompt from docs/ROADMAP.md end-to-end — build the feature, run build + tests + SwiftLint until green, tick the ROADMAP box, commit, and push. Not for one-off edits.
---

# Execute a roadmap prompt

1. Read the docs the prompt names. `docs/ROADMAP.md` is the checklist; consult
   `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`,
   `docs/BACKEND.md`, and `docs/TESTING.md` as the prompt touches
   product/architecture/data/backend/testing concerns.
2. Delegate a large, self-contained slice to a fresh-context subagent when it
   would otherwise bury the main thread; otherwise implement directly.
   Delegation is a context-hygiene tool, not a required step for every prompt.
3. Deliver working code — no stubs, no placeholders, no TODOs.
4. Actually build and test so the code genuinely works:
   - `tuist generate`
   - `xcodebuild build` and `xcodebuild test` on an iOS simulator (or `swift
     test` for a pure-Swift module) — see
     `.claude/rules/swift-conventions.md` for the exact invocation.
   - `bash Scripts/lint.sh` (SwiftLint `--strict`)
   - Fix every compile/test/lint failure and iterate until all three are
     clean. Do not report done on an unverified green.
5. Once green: update the relevant code/tests/docs, tick that prompt's
   checkbox in `docs/ROADMAP.md`, commit with a message referencing the prompt
   (e.g. `Prompt 1: Domain data model`), and push to `origin`.
