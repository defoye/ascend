-- Programs: the nested weeks -> workouts -> exercise prescriptions tree (see
-- docs/DATA_MODEL.md "Programs"), normalized into one table per level.
-- `SupabaseBackend+ProgramRepository.swift` treats a `Program` as authored
-- and replaced as a whole value (matching `ProgramBuilderViewModel`): every
-- save deletes and re-bulk-inserts a program's weeks (cascading to workouts
-- and prescriptions below), so `on delete cascade` here is load-bearing, not
-- just cleanup convenience.

create table if not exists public.exercises (
    id uuid primary key,
    name text not null
);

create table if not exists public.programs (
    id uuid primary key,
    author_id uuid not null references public.people (id) on delete cascade,
    title text not null,
    summary text not null default ''
);

create index if not exists programs_author_id_idx on public.programs (author_id);

create table if not exists public.program_weeks (
    id uuid primary key,
    program_id uuid not null references public.programs (id) on delete cascade,
    index integer not null
);

create index if not exists program_weeks_program_id_idx on public.program_weeks (program_id);

create table if not exists public.workouts (
    id uuid primary key,
    program_week_id uuid not null references public.program_weeks (id) on delete cascade,
    name text not null,
    position integer not null default 0
);

create index if not exists workouts_program_week_id_idx on public.workouts (program_week_id);

create table if not exists public.exercise_prescriptions (
    id uuid primary key,
    workout_id uuid not null references public.workouts (id) on delete cascade,
    exercise_id uuid not null references public.exercises (id) on delete restrict,
    sets integer not null check (sets >= 0),
    reps text not null,
    notes text,
    position integer not null default 0
);

create index if not exists exercise_prescriptions_workout_id_idx on public.exercise_prescriptions (workout_id);
create index if not exists exercise_prescriptions_exercise_id_idx on public.exercise_prescriptions (exercise_id);

create table if not exists public.program_assignments (
    id uuid primary key,
    program_id uuid not null references public.programs (id) on delete cascade,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    assigned_at timestamptz not null default now(),
    start_date timestamptz not null
);

create index if not exists program_assignments_engagement_id_idx on public.program_assignments (engagement_id);
create index if not exists program_assignments_program_id_idx on public.program_assignments (program_id);
