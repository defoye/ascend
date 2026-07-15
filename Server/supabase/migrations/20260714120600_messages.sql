-- Messages (see docs/DATA_MODEL.md "Messaging & payments"). Realtime is
-- enabled on this table below so `SupabaseBackend+MessageRepository.swift`
-- can subscribe to `postgres_changes` for a stream-first chat thread (see
-- docs/ARCHITECTURE.md's "messaging is built stream-first from the start").

create table if not exists public.messages (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    author_id uuid not null references public.people (id) on delete cascade,
    body text not null,
    sent_at timestamptz not null default now()
);

create index if not exists messages_engagement_id_idx on public.messages (engagement_id);

alter publication supabase_realtime add table public.messages;
