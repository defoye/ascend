-- Sessions (see docs/DATA_MODEL.md "Engagement & sessions"). A `.completed`
-- session is one of the four `VerifiedOutcome.derive` pillars ("activity
-- verified") — see docs/DATA_MODEL.md's "Verified outcomes" section.

create table if not exists public.sessions (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    scheduled_at timestamptz not null,
    status text not null default 'scheduled'
);

create index if not exists sessions_engagement_id_idx on public.sessions (engagement_id);
