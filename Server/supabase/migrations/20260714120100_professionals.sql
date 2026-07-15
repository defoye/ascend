-- Professional profile, services, verifications (see docs/DATA_MODEL.md
-- "Professional profile & services").

create table if not exists public.professional_profiles (
    id uuid primary key,
    person_id uuid not null unique references public.people (id) on delete cascade,
    display_name text not null,
    headline text not null default '',
    bio text not null default ''
);

create table if not exists public.services (
    id uuid primary key,
    professional_profile_id uuid not null references public.professional_profiles (id) on delete cascade,
    category text not null,
    title text not null,
    price_cents integer not null check (price_cents >= 0),
    currency text not null default 'USD',
    modality text not null
);

create index if not exists services_profile_id_idx on public.services (professional_profile_id);

create table if not exists public.verifications (
    id uuid primary key,
    professional_profile_id uuid not null references public.professional_profiles (id) on delete cascade,
    kind text not null,
    status text not null default 'unverified',
    evidence_url text
);

create index if not exists verifications_profile_id_idx on public.verifications (professional_profile_id);
