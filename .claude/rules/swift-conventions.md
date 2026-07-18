---
paths:
  - "**/*.swift"
---

# Language & concurrency

- Swift 6 strict concurrency (complete checking) everywhere.
- Value types by default (`struct`/`enum`); reach for `class` only when
  reference semantics are actually required.
- View models are `@MainActor @Observable`.
- Repositories are `async`/`throwing`; live data is exposed via `AsyncStream`
  (see docs/ARCHITECTURE.md).
- No force-unwraps (`!`) outside of test code. Prefer `guard let`, `if let`, or
  explicit error handling.

# File organization

- One type per file for public `Domain` types (e.g. `Engagement.swift` defines
  `Engagement` and nothing else public).
- Features are organized in feature folders per screen area (e.g.
  `Modules/Features/Sources/Engagements/...`), not by technical layer.

# Previews

Every SwiftUI component and screen ships previews in **both** light and dark
appearance, using `InMemoryStore` mock data (`MockData`) rather than
hand-rolled preview fixtures. This keeps previews honest about what real data
looks like and keeps them free (no backend calls).

# Running tests and lint

- Regenerate first: `tuist generate`.
- Run the full suite against a booted iOS simulator with the aggregate
  workspace scheme: `xcodebuild test -workspace Ascend.xcworkspace -scheme
  Ascend-Workspace -destination 'platform=iOS Simulator,name=<device>'` — pick
  an available device name/OS via `xcrun simctl list devices available`. The
  `Ascend-Workspace` scheme aggregates every test target (`DomainTests`,
  `DataInterfacesTests`, `InMemoryStoreTests`, `SupabaseBackendTests`,
  `DesignSystemTests`, `FeaturesTests`, `AscendTests`, `AscendUITests`,
  `SupabaseBackendIntegrationTests`). The `Ascend` scheme (for running the app)
  tests only `AscendTests`/`AscendUITests` — use it for a fast app smoke test,
  not full coverage. `SupabaseBackendIntegrationTests` self-skips unless
  `ASCEND_TEST_SUPABASE_URL`/`ASCEND_TEST_SUPABASE_ANON_KEY` are set in the
  environment.
- Lint: `bash Scripts/lint.sh` (SwiftLint `--strict`, config in
  `.swiftlint.yml`). Must run clean.
