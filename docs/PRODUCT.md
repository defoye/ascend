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

## Sequencing: a conscious deviation from a consumer-first reading

The founding vision can be read two ways. Its "Phase 1" frames the foundation as
**consumer** Identity + Discovery (users browse professionals first); its
"Distribution Strategy" section says the **initial focus should likely be
providers**, because a provider brings their existing clients, followers, and
community. These two readings are in mild tension.

Ascend deliberately follows the **provider-first** thread. We build the coach-side
operating system first (Today, Clients, Programs, Scheduling, Progress, Messaging)
and treat the consumer-facing discovery/marketplace surface as a **later** layer
(see docs/ROADMAP.md, ~Prompt 15). Rationale: the provider tool is useful with zero
consumers, it is what seeds the verified-outcome graph that is the actual moat, and
providers are the side that brings distribution. This is a chosen ordering, **not**
an oversight of the vision's Phase-1 framing — do not "correct" it by pulling the
consumer marketplace forward without a deliberate decision to re-sequence.

## AI: intentionally deferred, not dropped

The founding vision leans on AI as a product surface — AI goal assessment /
onboarding, AI consumer↔professional matching with "why" explanations, and an AI
provider assistant (generate programs, draft client messages, summarize progress,
write marketing copy). **None of this is in the phase-1 build**, and that is a
deliberate choice, consistent with the vision's own note that *AI is not the moat*
(the verified-outcome data, provider network, and reputation system are). We build
the durable substrate first; AI is layered on top once the entities and data it
would operate over exist.

AI capabilities are tracked explicitly as a deferred track in docs/ROADMAP.md so
they are not silently lost. Note the standing tension to revisit when we do pick AI
up: the vision's "MVP Philosophy" wants the product to *prove consumers trust
recommendations*, which structurally needs the AI-matching + consumer-discovery
layer that we are deferring.

## Explicitly not building initially

- A generic social feed.
- A generic workout tracker.
- Nutrition tracking.
- Wearables integration.
- Medical / physical-therapy-grade clinical complexity.

These may become adjacent products later, but are out of scope for the phase-1
provider tool.
