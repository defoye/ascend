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

### `SupabaseBackend.paymentGateway`: `NoOpPaymentGateway` until Prompt 14

`SupabaseBackend.paymentGateway` (`Modules/SupabaseBackend/Sources/SupabaseBackend.swift`)
vends `DataInterfaces.NoOpPaymentGateway` — every method throws
`GatewayError.paymentsNotEnabled` rather than fabricating a `Payment`. There is
no Stripe-backed `SupabaseBackend` gateway yet; that lands with Prompt 14. This
matters because `VerifiedOutcome.derive` requires a *succeeded payment* as one
of its four pillars (see docs/DATA_MODEL.md) — a gateway that silently wrote a
fake `.succeeded` `Payment` row would falsely satisfy that pillar if
`PaymentsMode` were ever flipped to `.live` against `SupabaseBackend` before
Stripe exists. A live-mode charge must fail loudly instead. In practice launch
ships with `PaymentsMode.free` (see docs/BUILD_STATUS.md "Rollout strategy —
free first, monetize later"), so `PaymentsModeBackend` substitutes
`NoOpPaymentGateway` ahead of this ever being reached anyway.

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

## Invite-based client onboarding

`InviteRepository` (`var invites: any InviteRepository` on `Backend`) is how every
coaching relationship starts — see docs/DATA_MODEL.md's "Engagement invites" for the
full semantics (`createInvite`/`pendingInvites`/`revokeInvite`/`claimInvite`, the
`InviteError` cases, and the role-add-on-claim behavior). It replaced a coach-creates-
a-`Person` "Add client" flow that could never work against real Supabase RLS
(`people` inserts require `id == auth.uid()`); a coach cannot create another
person's account row under any circumstances, so onboarding has to run through a
code the client claims themselves.

`InMemoryBackend` implements it entirely in memory
(`InMemoryBackend+InviteRepository.swift`). `SupabaseBackend` implements it
(`SupabaseBackend+InviteRepository.swift`) against a schema that now exists as SQL
— `Server/supabase/migrations/20260716120000_engagement_invites.sql` (LH-3), the
13th migration:

- Table `engagement_invites`: `id uuid` (pk), `code text`, `professional_id uuid`,
  `suggested_client_name text`, `created_at timestamptz`, `claimed_by uuid`,
  `claimed_at timestamptz`, `engagement_id uuid`. `createInvite`/`revokeInvite` are
  plain `SupabaseTable<EngagementInviteRow>` upsert/delete; `pendingInvites` filters
  `professional_id eq` + `claimed_by is null`.
- RPC `claim_invite(invite_code text) returns <engagement row shape>`: must run as
  the authenticated caller (`auth.uid()` is authoritative for who's claiming — the
  Swift adapter's `clientID` parameter is accepted for protocol symmetry but
  otherwise unused), and implement the exact claim semantics documented in
  docs/DATA_MODEL.md (invalid/already-claimed/own-invite checks, `Engagement`
  creation, marking the invite claimed, granting `.consumer` on the claimer).
  Distinguishable failures must `RAISE EXCEPTION` with a message of exactly
  `"invalid_code"`, `"already_claimed"`, or `"cannot_claim_own_invite"` — the Swift
  adapter maps those three strings to the matching `InviteError` case and rethrows
  anything else as-is.

The migration has been reviewed and applied locally to the extent this environment
allows — no Docker/Postgres tooling was available to actually run `supabase db
reset` here, so it is unexecuted against a real Postgres instance and syntax has
only been reviewed by hand, not verified by the planner. The owner still needs to
run `supabase db push` (from `Server/supabase/`) against the live project to apply
it — until then, `SupabaseBackend`'s invite methods compile and are wired into
`Backend`, but calling them against a real project fails (no such table/function),
the same "adapter exists, SQL doesn't yet" state every other Supabase-backed
repository passed through before its own migration landed.

## Account deletion (LH-7)

`AccountDeletionEffect` anonymizes the `people` row rather than deleting it
(FK cascades off `people` would otherwise wipe the other party's shared
engagement history — see that type's doc comment) and ends, rather than
deletes, the person's engagements. Anonymizing the row doesn't remove the
**auth identity** itself, so `AuthGateway` gains `deleteAccount()`, which
does that separately.

`SupabaseBackend`'s `deleteAccount()` invokes the `delete-account` Edge
Function (`Server/supabase/functions/delete-account/index.ts`) rather than
calling `auth.admin.deleteUser` from the client — that call requires the
service-role key, which never ships in the app. The function reads the
caller's JWT, resolves the user with an anon-key client, then uses a
service-role client (`SUPABASE_SERVICE_ROLE_KEY`, a Supabase server-side
secret) to delete the auth user. The client never passes an id — the
function derives the target entirely from the caller's own session.

Same "reviewed-only" state as the invite RPC above: no Docker/Postgres
tooling here means it hasn't run locally. The owner needs to run
`supabase functions deploy delete-account` (from `Server/supabase/`) against
the live project before `SettingsViewModel.deleteAccount()` can succeed
against `SupabaseBackend`.

## Email confirmation (LH-10)

Hosted Supabase's "Confirm email" project setting is supported either way: `AuthGateway.signUp` returns a `SignUpOutcome` (`.signedIn` or `.confirmationRequired`) instead of `Void`, so the auth screen can show a check-your-email notice when a session isn't created immediately, and an unconfirmed `signIn` throws `AuthGatewayError.emailNotConfirmed` instead of a generic error.

## Message push notifications (LH-11)

`DeviceTokenRepository` (`DataInterfaces`) — `register(token:platform:)` /
`unregister(token:)` — is the same seam pattern as every other repository:
`Backend` vends `var deviceTokens: any DeviceTokenRepository`, with a
`Backend` protocol extension defaulting it to `NoOpDeviceTokenRepository` so
every existing conformer (preview/test stub `Backend`s included) keeps
compiling without change. `InMemoryBackend` implements it directly
(`InMemoryBackend+DeviceTokenRepository.swift`), deriving the person from its
own `currentAuthState` rather than taking one as a parameter — a signed-out
`register` is a silent no-op, matching every other repository's "adapter
resolves identity from its own session" convention.
`SupabaseBackend+DeviceTokenRepository.swift` writes/deletes `device_tokens`
rows as direct, best-effort Postgres calls (not routed through
`OfflineWriteQueue` — losing a registration while offline just means this
device re-registers on next launch, not worth the queue's replay complexity).

Registration itself is wired at the App composition root
(`App/Sources/AppDelegate.swift`, `App/Sources/AscendApp.swift`): a
`UIApplicationDelegate` (`AppDelegate`) owns the only code path that can
obtain a real APNs token (`didRegisterForRemoteNotificationsWithDeviceToken`)
and bridges it into `Features`' `DeviceTokenStore` (a plain `@Observable`
holder — Foundation/Observation only, no UIKit, so `Features` still never
depends on a concrete push API). `RootView` calls
`UIApplication.shared.registerForRemoteNotifications()` once signed in and
registers the resulting token via `backend.deviceTokens.register` once both
a signed-in person and a token are available. This deliberately reuses the
existing `SettingsView`/`LiveSessionReminderScheduler` notification-
permission flow (docs/ROADMAP.md Prompt 8) rather than adding a second,
launch-time permission prompt — `registerForRemoteNotifications()` itself
does not prompt; it only yields a token once permission already exists.
`SettingsViewModel.signOut()`/`deleteAccount()` unregister the current
device's token (while the session is still valid) before destroying it, so a
signed-out device stops receiving pushes for the account that left it.

### Server side: reviewed-only, not run locally

Same "reviewed-only" state as every other Supabase artifact in this repo (no
Docker/Postgres/Deno tooling in this environment): the
`device_tokens` migration
(`Server/supabase/migrations/20260716122000_device_tokens.sql` — a
self-only-RLS table, mirroring `engagement_invites`) and the
`notify-message` Edge Function
(`Server/supabase/functions/notify-message/index.ts`) have been reviewed by
hand but not executed against a real project. `notify-message` is invoked by
a Supabase Database Webhook on `public.messages` INSERT (dashboard-
configured, not a SQL migration — webhook config is project-specific and
isn't portable the way a `pg_net` trigger would pretend to be); it resolves
the message's recipient (the engagement party who isn't the author — a pure,
`deno test`-covered helper in `recipient.ts`), fetches their device tokens,
and sends each an APNs push using token-based (`.p8`) auth: an ES256 JWT
built with Web Crypto, no external APNs library. A `410` response from Apple
for a given token deletes that row — it's no longer registered.

**Owner actions** (everything else — Swift, SQL, Deno, the entitlement — is
done):
1. Create an APNs Auth Key (`.p8`) in the Apple Developer portal; note its
   Key ID and Team ID.
2. Enable the Push Notifications capability on the App ID, and provisioning.
3. Set the Edge Function's secrets (`supabase secrets set`, from
   `Server/supabase/`): `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`
   (the full `.p8` PEM contents), `APNS_BUNDLE_ID=com.ascend.Ascend`, and
   `SUPABASE_SERVICE_ROLE_KEY` if not already auto-provided.
4. `supabase db push` (from `Server/supabase/`) to apply the
   `device_tokens` migration.
5. `supabase functions deploy notify-message`.
6. Configure a Database Webhook in the Supabase dashboard: table
   `public.messages`, event `INSERT`, type "Supabase Edge Functions",
   pointing at `notify-message`.

The app-side entitlement (`App/Ascend.entitlements`, `aps-environment =
development`) is wired via `Project.swift`; a distribution build needs
`aps-environment = production`, which Xcode/App Store Connect set
automatically from the release provisioning profile at archive/export time
once step 2 above is done.
