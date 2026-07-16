# Ascend Privacy Policy (stub)

This is a bundled, plain-language privacy policy stub. The canonical in-app
copy lives in `Modules/Features/Sources/Settings/PrivacyPolicyView.swift`
(reachable from Settings on both the coach and client sides); the
machine-readable declaration Apple's App Store review checks lives in
`App/Resources/PrivacyInfo.xcprivacy`. All three should stay in sync — if you
change what the app collects, update all three.

## What we collect

- **Account info**: your display name.
- **Progress metrics** (`Domain.MetricKind` — bodyweight, strength 1RMs, body
  composition, etc.), logged by you or your coach.
- **Progress photos**, only ever if you explicitly opt in per coaching
  engagement.
- **Messages** between you and your coach.

## Progress metrics and photos are sensitive

We treat progress metrics and progress photos as sensitive, health-adjacent
data:

- Photos are invisible to your coach until you grant photo-sharing consent
  for that specific engagement (`EngagementRepository.photoConsent`), and
  revoking it immediately stops your coach from seeing any of your photos —
  verified in `EngagementProgressView+Photos.swift` (no photo UI renders at
  all without consent, not merely hidden).
- Whether your progress metrics contribute to a "verified outcome" surfaced
  on your coach's profile is a **separate** consent
  (`EngagementRepository.consent`), also revocable at any time from the
  "Share progress" screen — proven both directions in `ConsentEligibilityTests`.

## What we don't do

- We don't sell your data or share it with data brokers.
- We don't track you across other companies' apps or websites (see
  `NSPrivacyTracking: false` in `PrivacyInfo.xcprivacy`).
- We don't show ads.
- Card details are handled directly by our payment processor (Stripe, once
  Prompt 14 lands — see docs/BACKEND.md); raw card data never touches
  Ascend's servers.

## Your controls

- Review/change sharing consent any time from Settings and the "Share
  progress" screen.
- Delete your account any time from Settings → "Delete account" (see
  `AccountDeletionEffect`). This permanently destroys your sign-in
  credential — you can never sign back into that account — and your
  personal profile (display name, roles, goals) is scrubbed. Any active
  coaching engagements you're part of are ended. What's **not** deleted:
  shared coaching records (sessions, progress entries, photos, and
  payments) and messages are retained, because they're jointly owned with
  the other party in the relationship — a coach deleting their account
  doesn't erase their clients' training history, and vice versa. If you
  coach, your authored programs, availability windows, and professional
  profile are deleted, since those are yours alone.

## Today's build

This build runs entirely on `InMemoryStore`, an in-process mock backend with
no network calls and no persistence beyond the running process (see
docs/BACKEND.md, docs/TESTING.md) — nothing described above is actually
transmitted or stored anywhere durable yet. This document describes the
product's real data-handling model so it's accurate once a production
backend (Supabase, Prompt 13) is wired in, not just "what happens in the
demo."
