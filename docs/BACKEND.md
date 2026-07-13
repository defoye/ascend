# Backend

## Default backend

`DEBUG` builds default to `InMemoryStore.seeded()` — a fully in-memory adapter with
realistic mock data. No network, no cost, and the whole app (screens, previews, unit
tests) runs against it. See docs/TESTING.md.

Supabase is the production backend. Until Prompt 13 the project has no live backend
integration at all, so cost is **$0**. After Prompt 13, Supabase's free tier covers
early development and testing.

## Configuration

Backend configuration (URLs, anon keys) lives in `Config/Secrets.xcconfig`, which is
**gitignored** and never committed:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

No secrets live in code or in git history. Stripe **secret** keys never touch the
app at all — they live in Supabase's server-side secrets (Edge Functions /
`vault`), reachable only from server-side code, never bundled into the client.

## Selecting a backend

Because `Features` only depends on `DataInterfaces` protocols, the concrete backend
is selected in exactly one place: the `Ascend` App target (the composition root — see
docs/ARCHITECTURE.md). Which adapter gets constructed there can be driven by the
active xcconfig / build configuration.

## Offline strategy

All writes go through repository protocols defined in `DataInterfaces`. The
`InMemoryStore` adapter simply mutates in memory. The Supabase adapter is
responsible for its own offline-write queue:

- Queue contract (to be implemented alongside the Supabase adapter, ~Prompt 13):
  - Writes made while offline (or while a request fails transiently) are appended to
    a durable, ordered, on-device queue keyed by entity id.
  - The queue is drained in order as connectivity returns; a write for an entity is
    never reordered ahead of an earlier write for the same entity.
  - Repository read methods (including the `AsyncStream` live views) reflect queued,
    not-yet-synced local writes optimistically, so the UI never "reverts" a change
    the user just made.
  - Failed writes (rejected by the server, not just offline) surface back through the
    repository's error channel rather than being silently dropped from the queue.

This section documents the contract now so Features code can be written against the
protocol without knowing whether it's talking to `InMemoryStore` or a
queue-backed Supabase adapter.
