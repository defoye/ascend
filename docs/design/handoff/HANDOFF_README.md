# Handoff: Ascend — five high-traffic surfaces + shared state kit

## Overview
Ascend is a fitness-coaching platform whose core value is a **load-bearing distinction between "Verified"** (paid, coach-confirmed outcomes over a real coaching relationship) **and "Tracked"** (free, user-reported results, no verification claim). This handoff covers a polish + depth pass on five high-traffic iOS 18 / SwiftUI surfaces and the cross-cutting loading / empty / error states that tie them together.

Reference feeling: Things, Oura, Whoop, Apple Health — a credible record, not a marketing surface. "Trust is the interface."

## About the Design Files
The files in this bundle are **design references created in HTML** — prototypes showing intended look and behavior, **not production code to copy directly**. The task is to **recreate these designs in the target codebase** (the existing iOS 18 / SwiftUI app) using its established patterns, `Color` assets, SF Symbols, and navigation components. Map every token below to the existing SwiftUI asset catalog; do not hardcode hex where a semantic `Color` already exists.

`AscendScreens.dc.html` is the canonical design canvas — every surface is drawn as a 332×720 phone frame in both light and dark, grouped by surface (sections 01–06). `mockups.html`, `CLAUDE_DESIGN_BRIEF.md`, `SCREEN_INVENTORY.md`, and `DESIGN_SPEC` (if present) are the original brief and foundation references.

## Fidelity
**High-fidelity (hifi).** Final colors, typography, spacing (4pt grid), and interaction specs. Recreate the UI pixel-accurately using the codebase's existing SwiftUI components. All figures are shown in light and dark; both are normative.

## Design Tokens

### Color — Light
| Role | Hex | Notes |
|---|---|---|
| background | `#F4F5F7` | app canvas |
| surface | `#FFFFFF` | cards & sheets |
| surfaceSecondary | `#EEF1F4` | subtle fills, tiles |
| primary | `#0C6B75` | brand teal (light) |
| verified | `#0C6B75` | verified accent = primary in light |
| success | `#1C8250` | deltas, logged confirmations |
| warning | `#8A5A00` | |
| danger | `#C0362F` | error banner |
| text | `#15181E` | |
| textSecondary | `#5A6472` | |
| textTertiary | `#8A93A2` | |
| border | `#E3E6EB` | |
| onPrimary | `#FFFFFF` | text/icon on teal |
| skeleton / skeleton2 | `#E7EAEF` / `#EFF1F4` | shimmer gradient stops |

### Color — Dark
| Role | Hex |
|---|---|
| background | `#0D1013` |
| surface | `#161A1F` |
| surfaceSecondary | `#1E242B` |
| primary | `#34AEBD` (brand teal, dark) |
| verified | `#3BB8C6` |
| success | `#3FBE7E` |
| warning | `#D6A02E` |
| danger | `#E86B63` |
| text | `#F1F4F7` |
| textSecondary | `#98A2AF` |
| textTertiary | `#6B7480` |
| border | `#2A313A` |
| onPrimary | `#05262A` (dark text on teal button) |
| skeleton / skeleton2 | `#1E242B` / `#2A343D` |

**Only these two teals are allowed as brand color** — `#0C6B75` (light) and `#34AEBD` (dark). No other accent hues.

### Typography — SF Pro (system)
- Numbers everywhere use **tabular figures** (`font-variant-numeric: tabular-nums` → SwiftUI `.monospacedDigit()`).
- Large title (screen name "Today"): 32px / 700 / -0.6px tracking
- Title (sheet, card hero): 24–27px / 700 / -0.5px
- Body: 14–15px / 400–500
- Caption / secondary: 12.5–13.5px / 500, textSecondary
- Mono labels (section eyebrows, set-table headers): SF Mono 11px / 600, letter-spacing 0.5–0.9px, uppercase, textTertiary

### Spacing — 4pt grid
Card padding 14–20px; card gap 10–20px; screen horizontal inset 18px; card radius **16px**, hero/sheet **20px**, tiles **12–14px**, pills **999px**, phone frame **46px**.

### Elevation
Cards: `0 1px 2px rgba(16,24,40,.05)` (light only; dark uses border, no shadow).

### Motion (keyframes in the file)
- `ascShim` — skeleton shimmer, 1.4s linear infinite, left→right.
- `ascPop` — success check: scale 0.7 → 1.08 → 1 over 0.5s.
- `ascRing` — rest-timer ring stroke-dashoffset sweep.
- `ascIn` — content fade+rise 6px on load.

## Screens / Views

### 01 · Coach — Today (`section` 01)
Confident home base. **States: Populated (L+D), Loading skeleton (D), Empty (L), Error (L).**
- Header: "Tuesday, Jul 15" (textSecondary 15px) + "Today" (32/700). Coach avatar (40px round) with a small verified check badge bottom-right.
- **Upcoming**: card of tappable session rows (avatar initials, name, program, time right-aligned tabular, chevron). Rows drill into Client Detail.
- **Recent activity**: merged feed rows (10px rounded icon tile, actor+action, relative time, chevron). e.g. "Sam logged bodyweight 181 lb · 2h ago", "Morgan sent a message · 4h ago".
- **Revenue · last 30 days**: calm ledger card — `$1,840 net` (30/700 tabular), then Gross `$2,000` / Platform fee · 8% `−$160`.
- Empty state: "No sessions today" and "No recent activity", each with its own CTA. Loading: skeleton mirrors this exact layout. Error: red banner "Couldn't refresh / Showing stale data" + Retry, content below dimmed to 55%.

### 02 · Coach — Client Detail
Densest screen. **States: Populated (Morgan, L+D), Empty-metrics (Sam), Loading, Error.**
- Nav bar: back chevron, centered client name, **message icon** top-right (this is the real message entry point — today a dead "coming soon" alert; wire it to the thread).
- Header: avatar, name, status pill.
- 2×2 **stat tiles** (mono label + big tabular value).
- Program summary card.
- One **metric chart** — Morgan's back-squat est. 1RM trend (line + area fill, teal). Sam has **empty-metrics** state instead ("No measurements logged yet" + CTA).
- Recent entries list; **Coach notes** card.

### 03 · Proof Profile (flagship / evidence-first)
**States: Verified (paid, L+D), Tracked (free), Empty, Journey-detail sheet.**
- Verification chips + practice stats.
- **Verified variant**: teal "Verified journey" badges + substantiation line. **Tracked variant**: neutral "Tracked results" badge, **no verified claim**, no teal verification treatment. The "how verification works" copy swaps by mode.
- **Journey detail sheet** (anonymized): metric trajectory, timeframe, "Backed by" line. Copy is **load-bearing and verbatim** — see brief; never imply causation.

### 04 · Consumer — Today (`section` 04)
Calm daily surface. **States: Populated (L+D), Empty rest-day (L), Loading skeleton (D), Error stale (L).**
- Header identical pattern to coach, avatar **without** verified badge (client).
- **Hero workout card** (solid teal, onPrimary text, decorative corner circle): eyebrow "Today's workout", title "Lower Body A", meta "6 exercises · ~45 min · Week 6", full-width **Start workout** button (white fill, teal text, play glyph).
- **Up next**: single check-in row with Coach Riley.
- **From your coach**: nudge card (coach avatar, name, timestamp, message body).
- **Bodyweight · 8 weeks**: `181 lb` with `−15 lb` success delta, line+area chart. **Data: 196 → 189 → 184 → 181** (descending; axis labels 196/189/184/181).
- Empty = **Rest day** card (moon icon, reframes rest as programmed, "Log bodyweight" secondary CTA) + "This week 4 of 5 workouts · On track" progress bars.
- Consumer tab bar: **Today · Workouts · Progress · Profile** (calendar / dumbbell / line-chart / person).

### 05 · Consumer — Workout Player (`section` 05)
The one delightful screen. **States: Active set logging (L), Live rest timer (D), Workout complete (L).**
- Header: close (✕), centered "Lower Body A" + "EXERCISE 2 / 6", elapsed time (mono tabular). Segmented exercise progress bar (done=success, current=primary, remaining=surfaceSecondary).
- **Active logging**: exercise title "Back Squat", "4 sets · 5 reps · target 185 lb". Set table (Set / Weight / Reps / ✓): set 1 done (success-tinted row + check), set 2 active (primary border inputs), sets 3–4 pending (tertiary). "Last time: 185 lb × 5" reference chip. Sticky bottom **Log set 2** button (teal).
- **Rest timer**: large ring (94r, 12 stroke, primary sweep over surfaceSecondary track), center "REST / 1:12 / of 2:00" (54px tabular). −15s and Skip rest controls. Confirmation chip "Set 2 logged · 185 lb × 5". Bottom "Next: Set 3".
- **Workout complete**: teal check medallion, "Workout complete", factual summary. 3 stat tiles (Sets 24 / Duration 47:12 / lb moved 12,850). Success card "Back squat top set +5 lb vs. last week". **No confetti** — calm, factual.

### 06 · Shared state kit (spec sheet, not a phone frame)
Documents the three states as one system + the single success microinteraction:
- **Loading — skeleton not spinner**: matches final layout box-for-box, neutral fills (never brand color), shimmer 1.4s, min 400ms to avoid flash.
- **Empty — warm, one action**: icon · title · one-line reason · exactly one primary CTA; rest day reframes rather than apologizes.
- **Error — banner over stale data**: inline banner (never modal), Retry inside the banner, last-good content dimmed to 55%.
- **Success "logged"**: spring 0.5s (check 0.7→1.08→1), one light success haptic on commit, factual delta copy (state number + change, no praise adjectives), success-green used for the **delta only** — teal stays the brand.

## Interactions & Behavior
- Session + activity rows on Coach Today are tappable with chevron drill-in affordances.
- Client Detail message icon opens the message thread (fix the dead "coming soon" alert).
- Proof Profile journey → journey detail sheet (bottom sheet).
- Workout flow: Consumer Today → tap hero → Workout Player → log set → rest timer counts down → next set → … → Workout complete → progress updates.
- Loading holds ≥400ms; error keeps stale content dimmed 55% under a retryable banner; empty always offers one CTA.

## State Management
- Per-surface `phase`: `loading | populated | empty | error`.
- Account `mode`: `verified` (paid) | `tracked` (free) — drives Proof Profile copy/badges and revenue visibility.
- Workout Player: current exercise index, per-set `{weight, reps, logged}`, rest-timer remaining seconds + running flag, session totals.
- Data fetching per surface refresh; on failure keep last good snapshot for the stale-content error state.

## Assets
All icons are inline SVG in the reference file, mapped to **SF Symbols** in-app (calendar, person.2, list.bullet, bubble.left, dumbbell, chart.xyaxis.line, play.fill, checkmark, clock, moon, chevron.right, exclamationmark). No raster assets. No third-party brand assets.

## Files
- `AscendScreens.dc.html` — canonical design canvas (all six sections, light + dark).
- `mockups.html` — foundations + component reference.
- `CLAUDE_DESIGN_BRIEF.md` — original brief (includes the verbatim load-bearing Verified/Tracked copy).
- `SCREEN_INVENTORY.md` — current-build screen inventory and known dead-ends.
