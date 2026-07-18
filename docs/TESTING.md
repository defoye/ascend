# Testing

## The app runs on no backend

The entire app runs fully on `InMemoryStore` + `MockData`, with no backend
whatsoever. Unit tests and SwiftUI previews both use it. "Add mock data" means
extending `MockData` inside `InMemoryStore` — it's pure Swift, so it costs nothing
and requires no server.

## What gets tested

- **Domain rules** are unit-tested directly, especially `VerifiedOutcome.derive`
  (see docs/DATA_MODEL.md) — every branch of its eligibility logic (missing
  consent, no completed session, no successful payment, fewer than two
  time-separated progress points, relationship not established) has a test that
  asserts it returns `nil`, plus a happy-path test that asserts it returns a
  correctly-computed outcome.
- **Critical flows** get view-model tests (e.g. "starting an engagement," "logging
  progress," "deriving an outcome after a completed paid session").
- A small number of **UI tests** cover the most critical end-to-end paths, not full
  screen coverage.

## Test targets

Each module with logic worth testing has a corresponding `<Module>Tests` target —
see `Project.swift` for the current list rather than an enumeration here, which
would drift the next time a target is added. Run them with `xcodebuild test`
against an iOS simulator; see `.claude/rules/swift-conventions.md` for the
exact invocation.
