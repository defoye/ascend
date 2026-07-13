# Product

A trusted marketplace + operating system for fitness/wellness professionals and the
clients they coach. The moat is a proprietary longitudinal graph of **verified
outcomes**.

## Strategy

"Come for the tool, stay for the network." Phase 1 is a single-player **provider**
tool that is fully useful with **zero consumers**; coaches bring their existing
clients. The consumer marketplace / discovery layer comes later, once the provider
tool has real usage and real verified-outcome data to show.

## Beachhead

Independent strength & weight-loss coaches. The model stays vertical-agnostic:
"trainer" is never a type in the data model — it's a `ServiceCategory`. New verticals
(yoga, physical therapy, running coaching, ...) are added as new enum cases, not new
architecture.

## Roles

One `Person`, with role modes `consumer` / `professional` / `both`. The UI adapts to
whichever role is currently active — there is no separate "coach app" and "client
app."

## Invariants

### Invariant 1 (structural): outcomes are derived, never authored

A `VerifiedOutcome` is **derived from evidence**, never hand-authored. It has **no
public initializer** — only a `derive(...)` factory that requires:

- an established relationship (`Engagement`),
- a completed, paid session,
- measurements (`ProgressEntry`) over time,
- explicit client consent.

This is enforced in code, not just by convention — see docs/DATA_MODEL.md and
docs/ARCHITECTURE.md.

### Invariant 2 (copy/UX): verify journeys, never claim causation

Product copy and UI verify that a client's **journey** happened (measured progress
over a real, paid coaching relationship) — it never claims the coach **caused** the
outcome. This distinction is legally and ethically load-bearing; do not soften it in
copy, marketing surfaces, or UI microcopy.

## Explicitly not building initially

- A generic social feed.
- A generic workout tracker.
- Nutrition tracking.
- Wearables integration.
- Medical / physical-therapy-grade clinical complexity.

These may become adjacent products later, but are out of scope for the phase-1
provider tool.
