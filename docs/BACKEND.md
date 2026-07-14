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

## Payments

Payments are behind a `PaymentGateway` protocol (`DataInterfaces`), the same seam
pattern as every other repository: `Features` depends only on `var paymentGateway:
any PaymentGateway` (vended by `Backend`), never on a concrete payment provider. Two
methods — `charge(engagementID:amountCents:currency:)` and
`refund(paymentID:)` — cover the mock payment lifecycle end to end (see
docs/DATA_MODEL.md's `Payment`/`PaymentStatus`).

### Mock today: `MockPaymentGateway`

`InMemoryBackend+PaymentGateway.swift` implements `PaymentGateway` directly on
`InMemoryBackend`, mirroring how it implements every other repository protocol.
Every charge succeeds immediately (no real card entry, no network) and persists a
`.succeeded` `Payment` with `stripePaymentIntentID == nil`; refund flips a payment to
`.refunded`. The platform fee is computed by the adapter itself from a fixed,
documented constant (`platformFeeBasisPoints = 1_000`, i.e. 10%) rather than passed
in by the caller — the same convention seeded fixture payments already use
(`MockData.mockPayment`, `amountCents / 10`).

### The real plan: Stripe Connect Express (Prompt 14, deferred)

This mock is a placeholder for a real Stripe integration that is explicitly
**deferred to Prompt 14** (see docs/ROADMAP.md) because it requires a live server —
until Prompt 13 (`SupabaseBackend`) exists, there is nothing to run Stripe's
server-side calls from. The plan, so it's not lost:

- **Stripe Connect Express** for professionals: each coach onboards a Connect
  Express account (Stripe-hosted onboarding UI, minimal PII collected by Ascend
  itself) before they can accept payments. Their `ProfessionalProfile` gains a
  Stripe Connect account id once onboarded.
- **Server-created PaymentIntents**: the app never creates a PaymentIntent or talks
  to Stripe directly. A client-side "charge" call invokes a Supabase Edge Function,
  which creates the PaymentIntent server-side (with the client's saved payment
  method, or a fresh card entry via Stripe's `PaymentSheet`) and returns only what
  the client needs to confirm it (an ephemeral client secret for that single
  PaymentIntent — never an API key).
- **Platform fee via `application_fee_amount`**: the same fee this mock computes
  from `platformFeeBasisPoints` gets computed server-side and passed as Stripe's
  `application_fee_amount` on the PaymentIntent, created `on_behalf_of` the coach's
  Connect account — Stripe splits the charge automatically, crediting the
  platform's fee and the coach's net to the right accounts. `Features` code is
  unaffected: it still just calls `paymentGateway.charge(...)` and gets back a
  `Payment` with the fee already reflected in `platformFeeCents`.
- **Real card entry + webhooks require the server.** Card entry uses Stripe's
  client-side SDK (`PaymentSheet`) talking directly to Stripe, never touching
  Ascend's server with raw card data (PCI scope stays minimal). Payment status
  changes (`succeeded`, `failed`, a later async `refunded`) are driven by Stripe
  webhooks landing on a Supabase Edge Function, which writes the `Payment` row —
  not by the client optimistically guessing the outcome. Both of these need a
  running server, so both land with the rest of the Stripe work in Prompt 14, after
  `SupabaseBackend` (Prompt 13) exists.
- **No Stripe secret keys ever touch the app.** Reinforcing the point made above:
  Stripe secret keys (and the Connect platform's restricted keys) live only in
  Supabase's server-side secrets (Edge Functions / `vault`), reachable only from
  server-side code. The app only ever holds short-lived, single-use client secrets
  scoped to one PaymentIntent.
- **Adapter-only swap.** Because `Features` depends on `PaymentGateway`, not a
  concrete provider, replacing `MockPaymentGateway` with a server-backed
  `StripeGateway` (implementing the exact same two methods against the Edge
  Functions above) is exactly the kind of adapter swap docs/ARCHITECTURE.md
  describes for every other repository — no `Features` code changes.
