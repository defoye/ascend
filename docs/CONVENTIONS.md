# Conventions

## Language & concurrency

- Swift 6 strict concurrency (complete checking) everywhere.
- Value types by default (`struct`/`enum`); reach for `class` only when reference
  semantics are actually required.
- View models are `@MainActor @Observable`.
- Repositories are `async`/`throwing`; live data is exposed via `AsyncStream` (see
  docs/ARCHITECTURE.md).
- No force-unwraps (`!`) outside of test code. Prefer `guard let`, `if let`, or
  explicit error handling.
- SwiftLint must run clean — see `.swiftlint.yml` and `Scripts/lint.sh`.

## File organization

- One type per file for public Domain types (e.g. `Engagement.swift` defines
  `Engagement` and nothing else public).
- Features are organized in feature folders per screen area (e.g.
  `Modules/Features/Sources/Engagements/...`), not by technical layer.

## Previews

Every SwiftUI component and screen ships with previews in **both** light and dark
appearance, using `InMemoryStore` mock data (`MockData`, see docs/TESTING.md) rather
than hand-rolled preview fixtures. This keeps previews honest about what real data
looks like and keeps them free (no backend calls).

## Commit / roadmap convention

After completing a prompt:

1. Update the relevant code/tests/docs.
2. Tick that prompt's checkbox in `docs/ROADMAP.md`.
3. Commit with a message referencing the prompt (e.g. `Prompt 1: Domain data model`).
4. Push to `origin`.

See the "Execution Protocol" in `CLAUDE.md` for how future prompts are dispatched.
