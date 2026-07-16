-- Device tokens (LH-11): registration of a signed-in person's APNs device
-- token, so the `notify-message` edge function (invoked by a Database
-- Webhook on `messages` INSERT — see that function's header comment) knows
-- which device(s) to push a message notification to. Backs
-- `DataInterfaces.DeviceTokenRepository` / `SupabaseBackend
-- +DeviceTokenRepository.swift`.
--
-- Reviewed-only, like every other migration in this schema (see
-- `20260716120000_engagement_invites.sql`'s header): this environment has no
-- Docker/Postgres tooling, so this has not been run locally. The owner
-- applies it with `supabase db push` (from `Server/supabase/`).

create table if not exists public.device_tokens (
    id uuid primary key default gen_random_uuid(),
    person_id uuid not null references public.people (id) on delete cascade,
    token text not null unique,
    platform text not null,
    updated_at timestamptz not null default now()
);

create index if not exists device_tokens_person_id_idx on public.device_tokens (person_id);

-- ===== RLS =====
--
-- Self-only, in every direction: a person may only see, register, update, or
-- remove their own device tokens. `notify-message` reads across every
-- person's tokens from a service-role client, which bypasses RLS entirely —
-- these policies only govern what the app's anon-key client can do.

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_self" on public.device_tokens
    for select
    using (person_id = auth.uid());

create policy "device_tokens_insert_self" on public.device_tokens
    for insert
    with check (person_id = auth.uid());

create policy "device_tokens_update_self" on public.device_tokens
    for update
    using (person_id = auth.uid())
    with check (person_id = auth.uid());

create policy "device_tokens_delete_self" on public.device_tokens
    for delete
    using (person_id = auth.uid());
