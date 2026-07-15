-- Progress entries and progress photos (see docs/DATA_MODEL.md "Metrics &
-- progress" and "Progress photos — sensitive, consent-gated").
--
-- `progress_photos.storage_path` is a key into the private `progress-photos`
-- Storage bucket (created in `..._storage.sql`) — never image bytes, and
-- never a durable public URL; `SupabaseBackend+ProgressPhotoRepository.swift`
-- resolves it to a short-lived signed URL on every read.

create table if not exists public.progress_entries (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    metric text not null,
    value double precision not null,
    unit text not null,
    recorded_at timestamptz not null,
    source text not null
);

create index if not exists progress_entries_engagement_id_idx on public.progress_entries (engagement_id);

create table if not exists public.progress_photos (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    storage_path text not null,
    captured_at timestamptz not null,
    source text not null
);

create index if not exists progress_photos_engagement_id_idx on public.progress_photos (engagement_id);
