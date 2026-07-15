-- Row Level Security for every table created in the migrations above.
--
-- All policies live in this one file, applied last, because most of them
-- cross-reference `public.engagements` (and, for programs, `public.programs`
-- / `public.program_assignments`) — defining them alongside each table's own
-- `create table` would force an artificial creation order and scatter the
-- security model across a dozen files. This file is the single place to
-- audit "who can read/write what."
--
-- Ground rule throughout: `auth.uid()` is the signed-in Supabase Auth user's
-- id, which is always equal to that person's `people.id` (see
-- `..._people.sql`'s header comment) — so `auth.uid() = engagements.client_id`
-- / `= engagements.professional_id` is "am I a party to this engagement."

-- ===== people / goals =====

alter table public.people enable row level security;
alter table public.goals enable row level security;

create policy "people_select_self_or_engaged" on public.people
    for select
    using (
        id = auth.uid()
        or exists (
            select 1 from public.engagements e
            where (e.client_id = auth.uid() and e.professional_id = people.id)
               or (e.professional_id = auth.uid() and e.client_id = people.id)
        )
    );

create policy "people_write_self" on public.people
    for insert
    with check (id = auth.uid());

create policy "people_update_self" on public.people
    for update
    using (id = auth.uid())
    with check (id = auth.uid());

create policy "people_delete_self" on public.people
    for delete
    using (id = auth.uid());

create policy "goals_select_self_or_engaged" on public.goals
    for select
    using (
        person_id = auth.uid()
        or exists (
            select 1 from public.engagements e
            where (e.client_id = auth.uid() and e.professional_id = goals.person_id)
               or (e.professional_id = auth.uid() and e.client_id = goals.person_id)
        )
    );

create policy "goals_write_self" on public.goals
    for all
    using (person_id = auth.uid())
    with check (person_id = auth.uid());

-- ===== professional profiles / services / verifications =====
-- Public-facing marketplace data: readable by any signed-in person (a
-- client browsing/discovering coaches), writable only by the owning
-- professional.

alter table public.professional_profiles enable row level security;
alter table public.services enable row level security;
alter table public.verifications enable row level security;

create policy "professional_profiles_select_any_authenticated" on public.professional_profiles
    for select
    to authenticated
    using (true);

create policy "professional_profiles_write_owner" on public.professional_profiles
    for all
    using (person_id = auth.uid())
    with check (person_id = auth.uid());

create policy "services_select_any_authenticated" on public.services
    for select
    to authenticated
    using (true);

create policy "services_write_owner" on public.services
    for all
    using (
        exists (
            select 1 from public.professional_profiles pp
            where pp.id = services.professional_profile_id and pp.person_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.professional_profiles pp
            where pp.id = services.professional_profile_id and pp.person_id = auth.uid()
        )
    );

create policy "verifications_select_any_authenticated" on public.verifications
    for select
    to authenticated
    using (true);

create policy "verifications_write_owner" on public.verifications
    for all
    using (
        exists (
            select 1 from public.professional_profiles pp
            where pp.id = verifications.professional_profile_id and pp.person_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.professional_profiles pp
            where pp.id = verifications.professional_profile_id and pp.person_id = auth.uid()
        )
    );

-- ===== engagements =====
-- A coach sees only their own engagements/clients; a client sees only their
-- own — the core "coach sees only their own clients" rule this task calls
-- out explicitly.

alter table public.engagements enable row level security;

create policy "engagements_select_party" on public.engagements
    for select
    using (client_id = auth.uid() or professional_id = auth.uid());

create policy "engagements_write_party" on public.engagements
    for all
    using (client_id = auth.uid() or professional_id = auth.uid())
    with check (client_id = auth.uid() or professional_id = auth.uid());

-- ===== sessions / progress_entries / messages / payments / program_assignments =====
-- All scoped identically: visible/writable only to the two parties of the
-- engagement they belong to.

create or replace function public.is_engagement_party(check_engagement_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (
        select 1 from public.engagements e
        where e.id = check_engagement_id
          and (e.client_id = auth.uid() or e.professional_id = auth.uid())
    );
$$;

alter table public.sessions enable row level security;
alter table public.progress_entries enable row level security;
alter table public.messages enable row level security;
alter table public.payments enable row level security;
alter table public.program_assignments enable row level security;

create policy "sessions_party" on public.sessions
    for all
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

create policy "progress_entries_party" on public.progress_entries
    for all
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

create policy "messages_party" on public.messages
    for all
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

create policy "payments_party" on public.payments
    for all
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

create policy "program_assignments_party" on public.program_assignments
    for all
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

-- ===== progress_photos =====
-- The most sensitive table: consent-gated in the database itself (in
-- addition to the Features-level `photoConsent` gate documented in
-- docs/DATA_MODEL.md) — the client can always see their own engagement's
-- photos; the professional only when `photo_consent_granted` is true.

alter table public.progress_photos enable row level security;

create policy "progress_photos_select_client_or_consented_professional" on public.progress_photos
    for select
    using (
        exists (
            select 1 from public.engagements e
            where e.id = progress_photos.engagement_id
              and (
                  e.client_id = auth.uid()
                  or (e.professional_id = auth.uid() and e.photo_consent_granted)
              )
        )
    );

create policy "progress_photos_write_party" on public.progress_photos
    for insert
    with check (public.is_engagement_party(engagement_id));

create policy "progress_photos_update_party" on public.progress_photos
    for update
    using (public.is_engagement_party(engagement_id))
    with check (public.is_engagement_party(engagement_id));

create policy "progress_photos_delete_party" on public.progress_photos
    for delete
    using (public.is_engagement_party(engagement_id));

-- ===== coach_notes =====
-- Private to the authoring professional (see docs/DATA_MODEL.md "Coach
-- notes": "not visible to the client") — unlike every other engagement-scoped
-- table above, the client is deliberately excluded here.

alter table public.coach_notes enable row level security;

create policy "coach_notes_professional_only" on public.coach_notes
    for all
    using (
        exists (
            select 1 from public.engagements e
            where e.id = coach_notes.engagement_id and e.professional_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.engagements e
            where e.id = coach_notes.engagement_id and e.professional_id = auth.uid()
        )
    );

-- ===== availability_windows =====
-- Descriptive scheduling context, readable by any signed-in person (a
-- client viewing a coach's general availability), writable only by the
-- owning professional.

alter table public.availability_windows enable row level security;

create policy "availability_windows_select_any_authenticated" on public.availability_windows
    for select
    to authenticated
    using (true);

create policy "availability_windows_write_owner" on public.availability_windows
    for all
    using (professional_id = auth.uid())
    with check (professional_id = auth.uid());

-- ===== exercises / programs / program_weeks / workouts / exercise_prescriptions =====
-- `exercises` is a shared, low-sensitivity library (just names) — any
-- signed-in person may read or contribute to it. `programs` and their nested
-- tree are authored by one professional and assigned to specific
-- engagements; a client may read (never write) a program once it's been
-- assigned to one of their engagements.

alter table public.exercises enable row level security;
alter table public.programs enable row level security;
alter table public.program_weeks enable row level security;
alter table public.workouts enable row level security;
alter table public.exercise_prescriptions enable row level security;

create policy "exercises_read_write_any_authenticated" on public.exercises
    for all
    to authenticated
    using (true)
    with check (true);

create or replace function public.can_read_program(check_program_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
    select exists (
        select 1 from public.programs p
        where p.id = check_program_id and p.author_id = auth.uid()
    ) or exists (
        select 1
        from public.program_assignments pa
        join public.engagements e on e.id = pa.engagement_id
        where pa.program_id = check_program_id and e.client_id = auth.uid()
    );
$$;

create policy "programs_select_author_or_assigned_client" on public.programs
    for select
    using (public.can_read_program(id));

create policy "programs_write_author" on public.programs
    for insert
    with check (author_id = auth.uid());

create policy "programs_update_author" on public.programs
    for update
    using (author_id = auth.uid())
    with check (author_id = auth.uid());

create policy "programs_delete_author" on public.programs
    for delete
    using (author_id = auth.uid());

create policy "program_weeks_select_readable_program" on public.program_weeks
    for select
    using (public.can_read_program(program_id));

create policy "program_weeks_write_author" on public.program_weeks
    for all
    using (
        exists (select 1 from public.programs p where p.id = program_weeks.program_id and p.author_id = auth.uid())
    )
    with check (
        exists (select 1 from public.programs p where p.id = program_weeks.program_id and p.author_id = auth.uid())
    );

create policy "workouts_select_readable_program" on public.workouts
    for select
    using (
        exists (
            select 1 from public.program_weeks w
            where w.id = workouts.program_week_id and public.can_read_program(w.program_id)
        )
    );

create policy "workouts_write_author" on public.workouts
    for all
    using (
        exists (
            select 1 from public.program_weeks w
            join public.programs p on p.id = w.program_id
            where w.id = workouts.program_week_id and p.author_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.program_weeks w
            join public.programs p on p.id = w.program_id
            where w.id = workouts.program_week_id and p.author_id = auth.uid()
        )
    );

create policy "exercise_prescriptions_select_readable_program" on public.exercise_prescriptions
    for select
    using (
        exists (
            select 1 from public.workouts wo
            join public.program_weeks w on w.id = wo.program_week_id
            where wo.id = exercise_prescriptions.workout_id and public.can_read_program(w.program_id)
        )
    );

create policy "exercise_prescriptions_write_author" on public.exercise_prescriptions
    for all
    using (
        exists (
            select 1 from public.workouts wo
            join public.program_weeks w on w.id = wo.program_week_id
            join public.programs p on p.id = w.program_id
            where wo.id = exercise_prescriptions.workout_id and p.author_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from public.workouts wo
            join public.program_weeks w on w.id = wo.program_week_id
            join public.programs p on p.id = w.program_id
            where wo.id = exercise_prescriptions.workout_id and p.author_id = auth.uid()
        )
    );
