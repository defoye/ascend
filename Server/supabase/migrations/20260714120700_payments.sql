-- Payments (see docs/DATA_MODEL.md "Messaging & payments"). A `.succeeded`
-- payment is one of the four `VerifiedOutcome.derive` pillars ("payment
-- verified"). `stripe_payment_intent_id` stays null until Prompt 14 (Stripe
-- Connect Express via Supabase Edge Functions — see docs/BACKEND.md);
-- SupabaseBackend's placeholder `PaymentGateway` never sets it.

create table if not exists public.payments (
    id uuid primary key,
    engagement_id uuid not null references public.engagements (id) on delete cascade,
    amount_cents integer not null check (amount_cents >= 0),
    currency text not null default 'USD',
    status text not null default 'pending',
    platform_fee_cents integer not null default 0 check (platform_fee_cents >= 0),
    stripe_payment_intent_id text,
    created_at timestamptz not null default now()
);

create index if not exists payments_engagement_id_idx on public.payments (engagement_id);
