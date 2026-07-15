-- Engagements: the coaching relationship, plus its two independent consent
-- grants (see docs/DATA_MODEL.md "Verified outcomes" and "Progress photos").
--
-- `consent_granted`/`photo_consent_granted` back
-- `EngagementRepository.consent`/`photoConsent` — both default false and are
-- revocable at any time by the client.

create table if not exists public.engagements (
    id uuid primary key,
    client_id uuid not null references public.people (id) on delete cascade,
    professional_id uuid not null references public.people (id) on delete cascade,
    status text not null default 'pending',
    started_at timestamptz,
    ended_at timestamptz,
    consent_granted boolean not null default false,
    photo_consent_granted boolean not null default false
);

create index if not exists engagements_client_id_idx on public.engagements (client_id);
create index if not exists engagements_professional_id_idx on public.engagements (professional_id);
