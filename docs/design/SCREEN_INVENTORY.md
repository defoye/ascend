# Ascend — Screen Inventory (current build)

What each shipped screen does today, so the design pass improves reality rather
than guessing. States marked ✗ are implemented in code but not yet given a proper
visual treatment — those are opportunities, not omissions to preserve.

## Coach (5 tabs: Today · Clients · Programs · Messages · Profile)

- **Today** — upcoming sessions, merged recent-activity feed (progress logs +
  messages), revenue snapshot (paid mode only). Empty ✓ · Error ✓ · Loading ✗.
  Session/activity rows are currently non-tappable (dead drill-ins).
- **Clients** — searchable roster → Client Detail (header/status, stat tiles,
  program summary, per-metric charts, recent entries, coach notes) → Add Client.
  Empty ✓ · Error ✓ · Loading ✗. "Message" button is a "coming soon" alert even
  though Messaging ships — needs wiring.
- **Programs** — Program → Week → Workout → Exercise builder tree (add/duplicate/
  delete/reorder), searchable exercise picker, assign-to-client. Empty ✓ · Error
  partial (inline red text, not the banner) · Loading ✗.
- **Schedule** (reached from Today) — day/week toggle, session lifecycle
  (complete/cancel/no-show), book session, weekly availability. Empty ✓ (with
  CTA) · Error ✓ · Loading ✗. Best state coverage on the coach side.
- **Inbox / Messaging** — conversations list → thread (bubbles, load-earlier
  paging, compose). List empty ✓ · Error ✓. Thread has **no empty state**; no
  typing/read/delivery indicators.
- **Proof Profile** — verification chips, practice stats, "how verification
  works" (copy swaps Verified↔Tracked by mode), journeys via `VerifiedOutcome`.
  Empty ✓ · Error ✓ · Loading ✗. Most polished, most spec-aligned screen.
- **Payments** (paid mode) — charge client, service pricing, payment history.
  Consumer-pay is an explicit stub (no card entry). Money formatting is
  inconsistent (CurrencyFormatter vs. ad-hoc string format).

## Consumer (4 tabs: Today · Progress · Coach · Me)

- **Today (Home)** — today's assigned workout, next session, latest coach nudge.
  Empty ✓ · Error ✓ · Loading ✓ (root gate). Calm but static.
- **Workout Player** — per-exercise cards, per-set reps/weight logging, **live
  rest timer**, bodyweight check-in, success haptics. The one delightful screen.
- **My Progress** — personal charts, streaks, milestones.
- **Consent** — reversible, scoped-to-measurements toggle that demonstrably flips
  whether a VerifiedOutcome derives. First-class privacy screen.
- **Onboarding** — goal-first intake (plain 3-picker form today) → real Goal +
  summary message to coach.
- **Me / Settings** — account, role switch, reminders toggle (not persisted),
  privacy policy (stub), sign-out, in-app account deletion.

## Cross-cutting reality

- **Loading is universally invisible** — every view model tracks `isLoading` but
  only the consumer root renders a spinner. No skeleton/shimmer anywhere. Biggest
  systemic gap.
- **Progress photos are fake** — hash-colored placeholder tiles, never a real
  image (backend has no asset bytes yet).
- **Microinteractions exist in exactly one place** (rest timer/haptics). Charts,
  logging, and the verification moment have none.
- **Previews**: ~76 `#Preview` blocks, but ~95% are just Light/Dark of one
  populated state. Empty/error/loading are never previewed.

## Design system

`DESIGN_SPEC.md` is authoritative: teal `#0C6B75`/`#34AEBD` is the only brand
color and also the verified color; 4pt grid; radii sm 8 / md 12 / lg 16 / xl 22 /
pill; subtle elevation; SF Pro + tabular figures. Existing components: AscendButton,
AscendTextField, Avatar, Card, Chip, EmptyState, ErrorBanner, ListRow,
ProgressChart, ProgressPoint, SectionHeader, StatTile, TrackedBadge, VerifiedBadge.
