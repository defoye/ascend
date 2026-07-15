-- Coach notes (private to the authoring professional — never visible to the
-- client, see docs/DATA_MODEL.md "Coach notes") and coach availability
-- windows (purely descriptive, see docs/DATA_MODEL.md "Coach availability").

create table if not exists public.coach_notes (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    author_id uuid not null references public.people (id) on delete cascade,
    body text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists coach_notes_engagement_id_idx on public.coach_notes (engagement_id);

create table if not exists public.availability_windows (
    id uuid primary key,
    professional_id uuid not null references public.people (id) on delete cascade,
    weekday integer not null check (weekday between 1 and 7),
    start_minute integer not null check (start_minute >= 0),
    end_minute integer not null check (end_minute <= 24 * 60),
    constraint availability_windows_valid_span check (start_minute < end_minute)
);

create index if not exists availability_windows_professional_id_idx on public.availability_windows (professional_id);
