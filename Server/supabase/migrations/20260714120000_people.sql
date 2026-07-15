-- People & goals (see docs/DATA_MODEL.md "People & goals").
--
-- `people.id` is the SAME uuid as `auth.users.id`: SupabaseBackend's
-- AuthGateway wraps the signed-in Supabase Auth user's id directly as
-- `Identifier<Person>` and ensures a matching `people` row exists on first
-- sign-in (see Modules/SupabaseBackend/Sources/SupabaseBackend+AuthGateway.swift).
-- That equivalence is what every RLS policy in
-- `..._rls_policies.sql` keys off: `auth.uid() = people.id` for "is this
-- person's own row." Row Level Security is enabled and every policy is
-- defined together in that final migration, once every table it
-- cross-references (engagements, program_assignments, ...) exists — see that
-- file's header comment for why.

create table if not exists public.people (
    id uuid primary key,
    display_name text not null,
    roles text[] not null default '{}',
    created_at timestamptz not null default now()
);

comment on table public.people is 'Domain.Person — id equals auth.users.id.';

create table if not exists public.goals (
    id uuid primary key,
    person_id uuid not null references public.people (id) on delete cascade,
    kind text not null,
    metric text,
    target_value double precision,
    target_unit text,
    deadline timestamptz
);

create index if not exists goals_person_id_idx on public.goals (person_id);
