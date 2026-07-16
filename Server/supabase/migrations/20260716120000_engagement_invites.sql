-- Engagement invites: how a coaching relationship is actually created (see
-- docs/DATA_MODEL.md "Engagement invites" and docs/BACKEND.md "Invite-based
-- client onboarding"). A coach can never insert another person's
-- `public.people` row directly — RLS requires `people.id = auth.uid()` on
-- insert, so any "add client" flow that fabricates a client id is dead on
-- arrival. Instead a coach creates an `engagement_invites` row carrying a
-- short human-shareable `code`, shares it out-of-band, and the client claims
-- it under their own authenticated session via the `claim_invite` RPC below,
-- which creates the `engagements` row on their behalf.

create table if not exists public.engagement_invites (
    id uuid primary key,
    code text not null,
    professional_id uuid not null references public.people (id) on delete cascade,
    suggested_client_name text,
    created_at timestamptz not null default now(),
    claimed_by uuid references public.people (id),
    claimed_at timestamptz,
    engagement_id uuid references public.engagements (id)
);

comment on table public.engagement_invites is
    'Domain.EngagementInvite — a coach-issued, client-claimed invite code; the only way a new public.engagements row is created.';

-- Codes are generated and stored normalized/uppercase by the client
-- (`EngagementInvite.generateCode()`/`.normalize(_:)`), and `claim_invite`
-- re-normalizes its input before matching — this index just needs a plain
-- unique equality lookup, not a case-insensitive one.
create unique index if not exists engagement_invites_code_idx on public.engagement_invites (code);
create index if not exists engagement_invites_professional_id_idx on public.engagement_invites (professional_id);

-- ===== RLS =====
--
-- Divergence from this schema's usual convention: every other table's RLS
-- policies live together in `20260714121100_rls_policies.sql`, applied last,
-- once every table those policies cross-reference exists (see that file's
-- own header comment for why). This migration's timestamp is already after
-- that file's, and the only tables its policies touch — `public.people` and
-- `public.engagements` — already exist by the time it runs, so splitting
-- these policies into a separate later file would buy nothing but scatter
-- one feature's security model across two places. Defining them here, right
-- next to the table they govern, is the same "keep it together unless
-- ordering forces otherwise" reasoning, just landing on the opposite answer
-- because the ordering constraint that motivated the split doesn't apply.

alter table public.engagement_invites enable row level security;

-- Only the owning professional ever reads invite rows directly. A claimer
-- never needs to (and, per the absence of any policy granting it, cannot)
-- read an invite row directly — they interact with invites exclusively
-- through `claim_invite`, which is `security definer` and so looks up the
-- row under the function owner's privileges, bypassing RLS entirely for
-- that one lookup.
create policy "engagement_invites_select_owner" on public.engagement_invites
    for select
    using (professional_id = auth.uid());

create policy "engagement_invites_insert_owner" on public.engagement_invites
    for insert
    with check (professional_id = auth.uid());

create policy "engagement_invites_delete_owner" on public.engagement_invites
    for delete
    using (professional_id = auth.uid());

-- Deliberately no update policy. Claiming an invite (setting claimed_by /
-- claimed_at / engagement_id) happens exclusively through `claim_invite`,
-- which runs `security definer` and so is not subject to RLS at all. With no
-- update policy defined, a direct `update public.engagement_invites ...` is
-- rejected outright for every role, including the owning professional — the
-- RPC is the only path that can ever move an invite from unclaimed to
-- claimed.

-- ===== claim_invite RPC =====
--
-- Runs with the caller's own identity for `auth.uid()` (there is no
-- "impersonate another user" surface here — `auth.uid()` always reflects the
-- signed-in session that issued the RPC call), but with the function
-- owner's table privileges (`security definer`) for row access: it reads and
-- updates `engagement_invites` rows the caller's own RLS policies above
-- would never let them see or touch, and inserts an `engagements` row on the
-- caller's behalf.
--
-- The three `raise exception` messages below are a load-bearing contract,
-- not incidental text: `SupabaseBackend+InviteRepository.swift`
-- (`mapClaimInviteError`) pattern-matches the exact strings
-- `'invalid_code'`, `'already_claimed'`, and `'cannot_claim_own_invite'` out
-- of the resulting `PostgrestError.message` to produce the matching
-- `InviteError` case; any other error message is rethrown unmapped. Do not
-- reword these without updating that adapter to match.
create or replace function public.claim_invite(invite_code text)
returns public.engagements
language plpgsql
security definer
set search_path = public
as $$
declare
    v_invite public.engagement_invites%rowtype;
    v_engagement public.engagements%rowtype;
    v_normalized_code text;
begin
    if auth.uid() is null then
        raise exception 'claim_invite requires an authenticated caller';
    end if;

    v_normalized_code := upper(trim(invite_code));

    -- Lock the row for the duration of this transaction so two concurrent
    -- claims of the same code can't both observe claimed_by is null: the
    -- second waits for the first's transaction to commit, then sees
    -- claimed_by already set and raises already_claimed.
    select * into v_invite
    from public.engagement_invites
    where code = v_normalized_code
    for update;

    if not found then
        raise exception 'invalid_code';
    end if;

    if v_invite.claimed_by is not null then
        raise exception 'already_claimed';
    end if;

    if v_invite.professional_id = auth.uid() then
        raise exception 'cannot_claim_own_invite';
    end if;

    insert into public.engagements (
        id, client_id, professional_id, status, started_at, ended_at,
        consent_granted, photo_consent_granted
    ) values (
        gen_random_uuid(), auth.uid(), v_invite.professional_id, 'active', now(), null,
        false, false
    )
    returning * into v_engagement;

    update public.engagement_invites
    set claimed_by = auth.uid(),
        claimed_at = now(),
        engagement_id = v_engagement.id
    where id = v_invite.id;

    -- Role-gated UI depends on `people.roles` being truthful (see
    -- docs/DATA_MODEL.md "Claim semantics") — grant `consumer` on claim if
    -- the claiming person doesn't already have it. A no-op, not an error, if
    -- the person row doesn't exist for some reason: the `where` simply
    -- matches zero rows.
    update public.people
    set roles = array_append(roles, 'consumer')
    where id = auth.uid()
      and not ('consumer' = any(roles));

    return v_engagement;
end;
$$;

-- Lock the RPC down to signed-in users only: anonymous/public callers have
-- no `auth.uid()` to claim as (the function itself also guards against a
-- null auth.uid(), but revoking execute here rejects the call outright
-- before it even runs, matching how every other write path in this schema
-- requires `authenticated`).
revoke execute on function public.claim_invite(text) from public, anon;
grant execute on function public.claim_invite(text) to authenticated;
