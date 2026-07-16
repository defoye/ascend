# Architecture

Clean / hexagonal architecture. The dependency rule is enforced structurally by
Tuist module boundaries, not just by convention.

## Dependency rule

```
App (composition root)
 └─> Features, DesignSystem, InMemoryStore, DataInterfaces, Domain

Domain          -> Foundation only
DataInterfaces  -> Domain
InMemoryStore   -> DataInterfaces, Domain
DesignSystem    -> (none)
Features        -> DesignSystem, DataInterfaces, Domain   (never a concrete backend)
```

`Domain` imports **only** Foundation — no SwiftUI, no Combine, no backend SDKs. This
keeps the core business types portable and trivially testable.

## Backend behind protocols

All persistence and networking is behind protocols defined in `DataInterfaces`.
Concrete adapters implement those protocols:

- `InMemoryStore` — dev/tests, and the **default** backend.
- `SupabaseBackend` — production.
- Future: `FirebaseBackend`, `AWSBackend`, or others, implementing the exact same
  protocols.

`Features` depends on `DataInterfaces` (protocols) and `Domain` (types) — never on a
concrete adapter. This is what makes the backend swappable.

## Composition root

The `Ascend` App target is the **only** composition root. It is the one place in the
codebase that imports a concrete backend adapter and wires it into the view models
Features exposes. Swapping backends (e.g. InMemoryStore -> SupabaseBackend) is a
one-line change there — see docs/BACKEND.md.

## Portability

Porting Ascend to a different backend provider is: write a new adapter module that
implements the `DataInterfaces` protocols, plus a data migration script. `Domain`,
`Features`, `DesignSystem`, and their test suites are untouched by a backend port.

## Realtime & extensibility

Repository protocols expose live data via `AsyncStream`, alongside a one-shot
throwing fetch for callers that only need a snapshot (see `SessionRepository`'s
`fetchSessions`/`sessions` pairing). The one-shot fetch is the one that must fail
loudly: an `AsyncStream` has no throwing channel, so a subscriber who awaits its
first value stalls forever on a connectivity failure instead of ever seeing an
error — this is why every load path that only needs a snapshot goes through the
throwing fetch, never a stream. Realtime behavior lives entirely in the adapter
layer — Domain and Features code consumes a stream regardless of whether the
underlying adapter is in-memory or a websocket-backed remote store. Messaging in
particular is built **stream-first** from the start for its live view (a genuine
Supabase Realtime subscription, not bolted on later), and pairs it with the same
one-shot `fetchMessages` every other repository has, for exactly the reason above.

## Concurrency

Swift 6 strict concurrency (complete checking) across the whole project:

- Domain types are `Sendable`.
- Repository implementations are actors or otherwise `Sendable`.
- View models are `@MainActor @Observable`.
