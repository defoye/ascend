-- Launch-hardening follow-up: closes a message-attribution spoofing hole in
-- the same class LH-4 (`20260716121000_rls_hardening.sql`) closed for
-- `engagements` inserts. The original `messages_party`
-- (`20260714121100_rls_policies.sql`) was `for all` scoped only to
-- `public.is_engagement_party(engagement_id)` — which for INSERT means either
-- party could write a `messages` row with `author_id` set to the OTHER
-- party's id. That forges thread attribution and, via
-- `functions/notify-message` (whose recipient is "the party who is not
-- author_id"), misdirects/forges the resulting push notification. The app
-- itself always sends `author_id` = the signed-in person
-- (`MessageThreadViewModel`/`ClientDetailViewModel`/
-- `ConsumerOnboardingViewModel`), so requiring `author_id = auth.uid()` on
-- insert can never reject a legitimate send — it only rejects a spoofed one.
--
-- Reviewed-only, like every other migration in this schema (no local
-- Docker/Postgres here); the owner applies it at `supabase db push`. This
-- migration is timestamped after every prior one so it drops and recreates
-- the live `messages_party` policy rather than editing an already-applied
-- migration.

drop policy if exists "messages_party" on public.messages;

create policy "messages_select_party" on public.messages
    for select
    using (public.is_engagement_party(engagement_id));

-- The added guard: a message may only be inserted by a party to its
-- engagement AND stamped with that caller's own id as author.
create policy "messages_insert_author" on public.messages
    for insert
    with check (public.is_engagement_party(engagement_id) and author_id = auth.uid());

-- Messages have no app-side update or delete path, but keep both party-scoped
-- for parity with the rest of the schema rather than leaving them policy-less
-- (which would silently forbid a future edit/delete feature outright).
create policy "messages_update_party" on public.messages
    for update
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id) and author_id = auth.uid());

create policy "messages_delete_party" on public.messages
    for delete
    using (public.is_engagement_party(engagement_id));
