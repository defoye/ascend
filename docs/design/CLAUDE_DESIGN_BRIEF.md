# Ascend — Claude Design Brief

Paste this whole block into Claude Design. Supporting files ship in the same
bundle: `DESIGN_SPEC.md` (the authoritative token + component system — honor it
exactly), `mockups.html` (existing static mockups), and `SCREEN_INVENTORY.md`
(what each screen does today). Design *to* the spec; this brief tells you what to
push forward.

---

## Product

Ascend is the operating system for independent fitness/wellness coaches and the
clients they train — one iOS app, two role modes (professional / client / both).
Its moat is a proprietary longitudinal record of **verified outcomes**: measured
client progress over a real, paid coaching relationship, with consent. Primary
user for this pass: the **independent coach** (dense business toolkit) and,
secondarily, their **client** (calm daily-training surface).

Reference feeling: Things, Oura, Whoop, Apple Health. Trust is the interface —
every screen should read like a credible record, not a marketing surface.

## Goal of this design

The engineering is built and working; this is a **polish + depth pass**, not a
rebuild. Raise five high-traffic surfaces from "functional" to "pleasant and
obviously trustworthy," and design the **cross-cutting states** the current build
implements in code but never shows well. Concretely:

1. **Coach — Today dashboard**: make it the confident home base. Real loading
   (skeleton, not blank cards), tappable session + activity rows with drill-in
   affordances, a revenue snapshot that reads as a calm ledger.
2. **Coach — Client Detail**: the single densest screen. Header + status, stat
   tiles, program summary, per-metric progress charts, coach notes, and a
   **direct message entry point** (today it's a dead "coming soon" alert).
3. **Proof Profile** (the flagship / evidence-first screen): verification chips,
   practice stats, "how verification works," and anonymized journeys. Design the
   **Verified vs. Tracked** split explicitly (see Constraints — copy is
   load-bearing). Add a tap-to-see-proof detail for a journey.
4. **Consumer — Today + Workout Player**: the workout player is already the one
   delightful screen (live rest timer, haptics); bring its polish level to the
   consumer Today home and progress surfaces.
5. **Cross-cutting states**: a consistent **loading skeleton**, a warm **empty
   state**, and an **error banner** treatment — designed once, applied to every
   screen. Plus one **celebratory-but-calm "logged" microinteraction** (delta
   animates in, light haptic — never confetti).

## Screens & states

Design each screen in **light and dark**, and for each, show the states listed.

- **Coach Today** — loading (skeleton rows), empty (no sessions / no activity,
  each with a CTA), populated (sessions + merged activity feed + revenue card),
  error (top banner + stale content beneath).
- **Coach Client Detail** — populated (header, status pill, 3–4 stat tiles,
  program summary, one metric chart, recent entries, notes), empty-metrics,
  loading, error. Show the message-coach affordance in the header.
- **Proof Profile** — Verified variant (paid mode: teal "Verified journey"
  badges + substantiation line), Tracked variant (free mode: neutral "Tracked
  results" badge, no verified claim), empty (no journeys yet), and a **journey
  detail** sheet (anonymized: metric trajectory, timeframe, "backed by" line).
- **Consumer Today** — populated (today's workout card, next session, coach
  nudge), empty (rest day / nothing assigned), loading, error.
- **Consumer Workout Player** — active set logging, live rest timer, set-complete
  and workout-complete success moments.
- **Shared state kit** — the skeleton, empty, and error components as a small
  spec sheet so they read as one system across all of the above.

## Key flows

1. **Coach morning check-in**: open app → Today (skeleton → populated) → tap an
   upcoming session → session detail → mark complete → return, activity feed
   updates.
2. **Coach reviews a client**: Today activity row *or* Clients roster → Client
   Detail → scan stat tiles + chart → tap message → thread (this wiring is the
   fix; today the message button dead-ends).
3. **Coach shows proof**: Profile tab → Proof Profile → tap a journey → journey
   detail sheet with the anonymized trajectory + non-causation "backed by" copy.
4. **Client trains**: Consumer Today → tap today's workout → Workout Player → log
   sets, rest timer counts down → finish → calm success moment → progress updates.

## Content & data (use this, not lorem ipsum)

- Coach: "Alex Rivera," strength & weight-loss coach.
- Clients: **Morgan Chen** — goal "Squat 1.5× bodyweight," active 14 weeks;
  **Sam Patel** — goal "Lose 20 lb," active 9 weeks.
- Stat tiles (Morgan): Bodyweight 178 lb (▲2), Squat 1RM 245 lb (▲15 this
  month), Sessions 22, Retention 92%.
- Progress chart (Sam, weight-loss — "down is good," use success color for the
  line): 196 → 189 → 184 → 181 lb over Wk 1 → Now; delta "−15 lb".
- Revenue snapshot (paid mode only): Net (30 days) $1,840 · Gross $2,000 ·
  Platform fee shown honestly.
- Today sessions: "Morgan Chen — Lower Body A — 9:00 AM," "Sam Patel — Check-in —
  11:30 AM." Activity: "Sam logged bodyweight 181 lb · 2h ago," "Morgan sent a
  message · 4h ago."
- Verified badge substantiation line (verbatim tone): "Backed by a real, paid
  coaching relationship & tracked measurements." Tracked badge line: "Self-
  tracked progress over an active coaching relationship."
- Journey (anonymized): "Client, 32 · Weight loss · 16 weeks · −18 lb, measured."
- Coach note example: "Cut volume 10% this week — right knee flared after
  Tuesday. Revisit squat depth Thursday."

## Constraints

- **Platform**: iOS 18+, SwiftUI, iPhone. Standard navigation (large titles, back
  chevrons, sheets, `TabView`). SF Pro + SF Symbols. 44pt minimum targets.
- **Design system is fixed**: use the exact tokens in `DESIGN_SPEC.md` (teal
  `#0C6B75` light / `#34AEBD` dark is the single brand color AND the verified
  color — do not introduce new hues). 4pt spacing grid, stated radii, subtle
  elevation. Tabular figures on all stats/charts.
- **Copy is legally load-bearing** (Invariant 2): verify a client's *journey*
  happened; **never claim the coach caused the outcome**. "Verified journey," not
  "Verified results." In free/unpaid mode, outcomes are "Tracked," never
  "Verified." Do not soften or blur this anywhere.
- **Calm over loud**: no neon, no gamified confetti, no aggressive gradients. One
  confident brand color. Motion is quiet and physical (`spring(response: 0.35,
  dampingFraction: 0.9)`). Verified/trust marks never animate.
- **Accessibility is a requirement, not an option**: Dynamic Type (design at
  default and imagine XXL), VoiceOver labels on every control, Reduce Motion
  (cross-fades replace slides), sufficient contrast (spec ratios already pass).
- **Avoid**: dashboards that feel like ad dashboards; anything implying medical/
  clinical claims; social-feed patterns; generic-workout-tracker chrome.

## Out of scope (this pass)

- Consumer discovery / marketplace / coach search (deferred product phase).
- Any AI surface (goal assessment, matching, assistant) — deferred track.
- Real payment / card-entry UI (payments are behind a free-mode flag; design the
  *revenue* read-outs, not a checkout).
- Program builder deep tree, Scheduling availability editor, Settings — keep
  consistent with the system but not the focus of this pass.
- Nutrition, wearables, social feed — explicit product non-goals.
