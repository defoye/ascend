-- `outcomes` view: a read-only, SQL-side mirror of the same eligibility
-- rules as `Domain.VerifiedOutcome.derive` (docs/DATA_MODEL.md's "Verified
-- outcomes — the core invariant"), for reporting/debugging and as a
-- foundation for a possible future server-side derivation (an Edge
-- Function, alongside Prompt 14's Stripe work).
--
-- IMPORTANT: this view is NOT queried by `SupabaseBackend.outcomes` today.
-- `SupabaseBackend+OutcomeRepository.swift` gathers the same evidence
-- (engagement, sessions, payments, consent, progress entries) via ordinary
-- table reads and calls `Domain.VerifiedOutcome.derive` client-side —
-- exactly like `InMemoryBackend` does — because `derive` is the ONLY
-- sanctioned constructor of a `VerifiedOutcome` (see docs/DATA_MODEL.md); a
-- SQL view re-deriving the same shape would be a second, un-typechecked copy
-- of that invariant's logic that could silently drift from `derive`'s actual
-- behavior. This view intentionally computes the same four pillars anyway —
-- as a cross-check an operator can run by hand, not as a code path the app
-- depends on.
create or replace view public.outcomes as
with eligible_engagements as (
    select
        e.id as engagement_id,
        e.started_at,
        e.status,
        (e.started_at is not null and e.status <> 'pending') as relationship_verified,
        e.consent_granted as consent_granted,
        exists (
            select 1 from public.sessions s
            where s.engagement_id = e.id and s.status = 'completed'
        ) as activity_verified,
        exists (
            select 1 from public.payments p
            where p.engagement_id = e.id and p.status = 'succeeded'
        ) as payment_verified
    from public.engagements e
),
eligible_metrics as (
    select
        pe.engagement_id,
        pe.metric,
        count(*) as point_count,
        count(distinct pe.recorded_at) as distinct_timestamp_count,
        min(pe.recorded_at) as started_at,
        max(pe.recorded_at) as ended_at
    from public.progress_entries pe
    group by pe.engagement_id, pe.metric
)
select
    ee.engagement_id,
    em.metric,
    em.started_at,
    em.ended_at,
    ee.relationship_verified,
    ee.activity_verified,
    ee.payment_verified,
    ee.consent_granted,
    (
        ee.relationship_verified
        and ee.activity_verified
        and ee.payment_verified
        and ee.consent_granted
        and em.point_count >= 2
        and em.distinct_timestamp_count >= 2
    ) as is_fully_verified
from eligible_engagements ee
join eligible_metrics em on em.engagement_id = ee.engagement_id;

comment on view public.outcomes is
    'SQL-side cross-check mirroring Domain.VerifiedOutcome.derive''s eligibility rules. '
    'Not the app''s source of truth — see this file''s header comment.';
