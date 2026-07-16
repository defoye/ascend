-- Launch-hardening pass (LH-4): closes three RLS holes found in a
-- pre-release security audit of `20260714121100_rls_policies.sql`. Each
-- section below names the hole it closes; see docs/ROADMAP.md's "Launch
-- hardening" entry for the summary.

-- ===== Hole 1: exercises was world-writable =====
--
-- The original policy (`exercises_read_write_any_authenticated`, `for all
-- ... using (true) with check (true)`) let any authenticated user UPDATE or
-- DELETE every row in the shared exercise library -- rename "Back Squat" to
-- anything, in every coach's programs, or delete it out from under them.
-- `exercises` only ever needs to grow (new named exercises get added, never
-- edited/removed via the app), so the fix is: any signed-in user may read or
-- add new exercises, but nobody gets UPDATE/DELETE -- not even the row's
-- "creator," since the table carries no creator column to scope an owner
-- policy to. `SupabaseBackend+ProgramRepository+Assemble.swift`'s
-- `replaceChildren` used to upsert (insert-or-update) every exercise a
-- program references; the adapter changes alongside this migration to
-- insert only the exercises not already present, since an UPDATE-on-conflict
-- against a row with no UPDATE policy would otherwise be rejected outright.

drop policy if exists "exercises_read_write_any_authenticated" on public.exercises;

create policy "exercises_select_any_authenticated" on public.exercises
    for select
    to authenticated
    using (true);

create policy "exercises_insert_any_authenticated" on public.exercises
    for insert
    to authenticated
    with check (true);

-- Deliberately no update/delete policy: with none defined, both are
-- rejected outright for every role, the same "absence of a policy is the
-- lockdown" convention `engagement_invites` (LH-3) uses for claiming.

-- ===== Hole 2: any user could insert an engagement naming any professional =====
--
-- The original `engagements_write_party` was `for all` using the "either
-- party" rule for both `using` and `with check` -- which for INSERT means any
-- authenticated user could insert a row with `professional_id` set to any
-- coach's id (enumerable via `professional_profiles_select_any_authenticated`)
-- and `client_id = auth.uid()`, self-enrolling into that coach's roster
-- without the coach's knowledge or an invite. The real client-onboarding
-- path is `claim_invite` (LH-3), a `security definer` RPC that bypasses RLS
-- entirely and is the only way a client-side engagement row gets created.
-- So the RLS-visible INSERT surface is now restricted to the professional
-- adding an engagement directly.

drop policy if exists "engagements_write_party" on public.engagements;

-- engagements_select_party (defined above, unchanged) already covers reads.

create policy "engagements_insert_professional" on public.engagements
    for insert
    with check (professional_id = auth.uid());

create policy "engagements_update_party" on public.engagements
    for update
    using (client_id = auth.uid() or professional_id = auth.uid())
    with check (client_id = auth.uid() or professional_id = auth.uid());

create policy "engagements_delete_party" on public.engagements
    for delete
    using (client_id = auth.uid() or professional_id = auth.uid());

-- The update policy alone still lets either party rewrite the *other*
-- party's id (swap themselves out of the engagement) or flip the other
-- party's consent grants -- a row-level `using`/`with check` can't express
-- "this column may change, that one may not, and only if the caller is a
-- specific party," so a column-level guard needs a trigger.
create or replace function public.guard_engagement_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.client_id is distinct from old.client_id
        or new.professional_id is distinct from old.professional_id then
        raise exception 'engagement parties are immutable';
    end if;

    if (new.consent_granted is distinct from old.consent_granted
        or new.photo_consent_granted is distinct from old.photo_consent_granted)
        and auth.uid() is distinct from old.client_id then
        raise exception 'consent_client_only';
    end if;

    return new;
end;
$$;

create trigger guard_engagement_columns
    before update on public.engagements
    for each row
    execute function public.guard_engagement_columns();

-- ===== Hole 3: consent flips were party-writable =====
--
-- `consent_granted`/`photo_consent_granted` belong to the client alone (see
-- `..._engagements.sql`'s header comment: "revocable at any time by the
-- client") but the old `engagements_write_party` let the professional flip
-- either one too; the trigger above now blocks that at the row-update level.
-- But `SupabaseBackend+EngagementRepository.swift`'s
-- `setConsent`/`setPhotoConsent` did a read-modify-write whole-row `upsert`
-- (`INSERT ... ON CONFLICT (id) DO UPDATE`) -- and Postgres RLS checks an
-- upsert against an existing row against *both* the INSERT policy's `with
-- check` and the UPDATE policy's `using`/`with check`, even though it only
-- ever updates. Under the new `engagements_insert_professional` policy, a
-- CLIENT calling that upsert to flip their own consent would fail the
-- insert check (`professional_id = auth.uid()` is false for a client). So
-- consent changes move to two dedicated `security definer` RPCs that
-- authenticate the caller themselves instead of leaning on the table's
-- INSERT policy.

create or replace function public.set_consent(check_engagement_id uuid, granted boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_engagement public.engagements%rowtype;
begin
    if auth.uid() is null then
        raise exception 'set_consent requires an authenticated caller';
    end if;

    select * into v_engagement
    from public.engagements
    where id = check_engagement_id
    for update;

    if not found then
        raise exception 'not_found';
    end if;

    if auth.uid() is distinct from v_engagement.client_id then
        raise exception 'consent_client_only';
    end if;

    update public.engagements
    set consent_granted = granted
    where id = check_engagement_id;
end;
$$;

revoke execute on function public.set_consent(uuid, boolean) from public, anon;
grant execute on function public.set_consent(uuid, boolean) to authenticated;

create or replace function public.set_photo_consent(check_engagement_id uuid, granted boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_engagement public.engagements%rowtype;
begin
    if auth.uid() is null then
        raise exception 'set_photo_consent requires an authenticated caller';
    end if;

    select * into v_engagement
    from public.engagements
    where id = check_engagement_id
    for update;

    if not found then
        raise exception 'not_found';
    end if;

    if auth.uid() is distinct from v_engagement.client_id then
        raise exception 'consent_client_only';
    end if;

    update public.engagements
    set photo_consent_granted = granted
    where id = check_engagement_id;
end;
$$;

revoke execute on function public.set_photo_consent(uuid, boolean) from public, anon;
grant execute on function public.set_photo_consent(uuid, boolean) to authenticated;
