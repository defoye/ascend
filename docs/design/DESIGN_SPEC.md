# Ascend — Design Spec

> The operating system for independent fitness coaches and their clients, and a trust layer for physical improvement. iOS 18+, SwiftUI. One app, two role modes (professional / client / both).

---

## 1. Design principles

1. **Trust is the interface.** Every screen should feel like a credible record, not a marketing surface. Restraint, whitespace, precise typography and honest data do the persuading — never hype.
2. **Data-honest by default.** Numbers are shown with real units, real timeframes and directional deltas. We describe *verified journeys with a coach*; we never claim a coach *caused* a result. Copy is framed accordingly everywhere.
3. **Calm over loud.** No neon, no gamified confetti, no aggressive gradients. A single confident brand colour (teal) carries both action and trust. Reference feeling: Things / Oura / Whoop / Apple Health.
4. **Two roles, one brand.** The coach side is a dense business toolkit; the client side is a calmer, focused daily surface. Same tokens, same components — the client surface simply uses more air, fewer controls and warmer copy.
5. **iOS-native, not custom.** Standard navigation (large titles, back chevrons, sheets), SF Pro, SF Symbols, 44pt minimum targets, system-feeling motion. We lean on the platform so the app feels trustworthy and familiar.

### How "trust / proof" is expressed visually
- **The brand colour *is* the verified colour.** Teal is used for primary actions *and* for the Verified badge — trust and action are one system, reinforcing that proof is native to the product.
- **The Verified badge** is a filled teal pill with a checkmark, always paired with a plain-language substantiation line ("Backed by a real, paid coaching relationship & tracked measurements").
- **Proof Profile** leads with a verification chip (identity, credentials, relationships verified by Ascend), then aggregate stats (sessions, retention), then *anonymized* journeys with explicit non-causation copy.
- **Consent is a first-class screen**, privacy-forward: anonymous, scoped to tracked measurements only, reversible. This visible respect for the client is itself a trust signal.
- **Charts show real trajectories over real time** with directional deltas (▲ / ▼) and units — evidence, not decoration.

---

## 2. Tokens

Token names map directly to SwiftUI `Color` assets in an asset catalog (`Color("Primary")`, or an enum `AscendColor.primary`). Provide **Any** (light) and **Dark** appearances per asset so the OS switches automatically.

### 2.1 Color — Light

| Token | Role | Hex | On-color / contrast |
|---|---|---|---|
| `background` | App background | `#F4F5F7` | text-primary 15.3:1 ✓ |
| `surface` | Cards, sheets, nav bars | `#FFFFFF` | text-primary 16.9:1 ✓ |
| `surfaceSecondary` | Subtle fills, segmented tracks | `#EEF1F4` | text-primary 14.6:1 ✓ |
| `primary` | Primary actions / brand | `#0C6B75` | white 4.9:1 ✓ AA |
| `verified` | Verified accent (= brand) | `#0C6B75` | white 4.9:1 ✓ AA |
| `secondary` | Tonal button background | `#E7EBEF` | secondary-text 11.8:1 ✓ |
| `success` | Positive / gains / streaks | `#1C8250` | white 4.6:1 ✓ AA |
| `warning` | Caution / pending | `#8A5A00` | white 5.1:1 ✓ AA |
| `danger` | Destructive | `#C0362F` | white 5.2:1 ✓ AA |
| `textPrimary` | Primary text | `#15181E` | on background 15.3:1 ✓ |
| `textSecondary` | Secondary text | `#5A6472` | on background 4.9:1 ✓ AA |
| `textTertiary` | Captions, placeholders | `#8A93A2` | on background 3.0:1 (large/again non-essential) |
| `border` | Separators, hairlines | `#E3E6EB` | — |
| `onPrimary` | Text/icons on primary | `#FFFFFF` | — |

### 2.2 Color — Dark

| Token | Role | Hex | On-color / contrast |
|---|---|---|---|
| `background` | App background | `#0D1013` | text-primary 16.1:1 ✓ |
| `surface` | Cards, sheets, nav bars | `#161A1F` | text-primary 13.6:1 ✓ |
| `surfaceSecondary` | Subtle fills | `#1E242B` | text-primary 11.2:1 ✓ |
| `primary` | Primary actions / brand | `#34AEBD` | `#04262B` 8.9:1 ✓ AA |
| `verified` | Verified accent (= brand) | `#3BB8C6` | `#04262B` 9.7:1 ✓ AA |
| `secondary` | Tonal button background | `#232A32` | secondary-text 9.8:1 ✓ |
| `success` | Positive / gains | `#3FBE7E` | on background 8.4:1 ✓ |
| `warning` | Caution / pending | `#D6A02E` | on background 8.6:1 ✓ |
| `danger` | Destructive | `#E86B63` | on background 6.2:1 ✓ AA |
| `textPrimary` | Primary text | `#F1F4F7` | on background 16.1:1 ✓ |
| `textSecondary` | Secondary text | `#98A2AF` | on background 6.5:1 ✓ AA |
| `textTertiary` | Captions, placeholders | `#6B7480` | on background 3.6:1 |
| `border` | Separators, hairlines | `#2A313A` | — |
| `onPrimary` | Text/icons on primary | `#04262B` | — |

> **Note on `onPrimary`:** in light mode primary is dark → white label; in dark mode primary is bright → very dark teal label. Store `onPrimary` / `onVerified` as their own dynamic assets so labels flip automatically.

### 2.3 Type scale — SF Pro

Use Dynamic Type. Sizes below are the default (`.large`) content-size step. `.title`/`.largeTitle` use **SF Pro Display**; body and below use **SF Pro Text** (the system does this automatically via `.font(.title)` etc.). Numerals in stats/charts use **monospaced / tabular figures** (`.monospacedDigit()`).

| Role | SwiftUI style | Size / Line-height | Weight |
|---|---|---|---|
| Large Title | `.largeTitle` | 34 / 41 | Bold (700) |
| Title 1 | `.title` | 28 / 34 | Bold (700) |
| Title 2 | `.title2` | 22 / 28 | Semibold (600) |
| Title 3 | `.title3` | 20 / 25 | Semibold (600) |
| Headline | `.headline` | 17 / 22 | Semibold (600) |
| Body | `.body` | 17 / 22 | Regular (400) |
| Callout | `.callout` | 16 / 21 | Regular (400) |
| Subheadline | `.subheadline` | 15 / 20 | Regular (400) |
| Footnote | `.footnote` | 13 / 18 | Regular (400) |
| Caption | `.caption` | 12 / 16 | Regular (400) |
| Data / label | custom | 11–12 | Semibold, `ui-monospace` (SF Mono), uppercase, +0.8 tracking |

### 2.4 Spacing — 4pt grid

| Token | Value | Typical use |
|---|---|---|
| `space-1` | 4 | icon ↔ label, chip inner gaps |
| `space-2` | 8 | tight stacks, inline gaps |
| `space-3` | 12 | list-row internal gap |
| `space-4` | 16 | **default** card padding, screen gutters |
| `space-5` | 20 | section gaps |
| `space-6` | 24 | between major blocks |
| `space-8` | 32 | screen top padding |
| `space-10` | 40 | large separations |
| `space-12` | 48 | hero spacing |

### 2.5 Radii

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 8 | chips, small tiles, inputs' inner |
| `radius-md` | 12 | buttons, inputs, segmented controls |
| `radius-lg` | 16 | cards |
| `radius-xl` | 22 | hero cards, bottom sheets |
| `radius-pill` | 999 | pills, tab-bar highlights, avatars |
| device screen | 37 (frame), 46 (bezel) | mock only |

### 2.6 Elevation

Shadows are subtle and used sparingly; in dark mode elevation is carried by `surface` lightness + `border`, not shadow.

| Token | Use | Light shadow |
|---|---|---|
| `e0` | flat, on-surface | none — 1px `border` only |
| `e1` | cards, raised rows | `0 1px 2px rgba(16,24,40,.06), 0 1px 3px rgba(16,24,40,.08)` |
| `e2` | sheets, popovers, floating CTAs | `0 6px 16px rgba(16,24,40,.09), 0 16px 34px -10px rgba(16,24,40,.16)` |

---

## 3. Component specs

**Tab bar** — Standard iOS `TabView`. Coach = 5 tabs (Today, Clients, Programs, Inbox, Profile). Client = 4 tabs (Today, Progress, Coach, Me). Translucent material background, hairline top border, SF Symbols at ~23pt, 10pt labels. Active tint = `primary`; inactive = `textTertiary`.

**Cards** — `surface` fill, `radius-lg`, 16pt padding, `e1` (or `border` in dark). Group related rows inside one card with 1px `border` dividers rather than stacking many separate cards.

**List rows** — 44pt+ height, 12pt gap. Leading avatar/icon → title (headline/`textPrimary`) + subtitle (footnote/`textSecondary`) → trailing status pill / chevron (`textTertiary`). Chevron only when the row navigates.

**Buttons**
- *Primary*: `primary` fill, `onPrimary` label, 44–50pt height, `radius-md`, semibold 15–16.
- *Secondary (tonal)*: `secondary` fill, `secondaryText` label.
- *Destructive*: `danger` — outline for reversible destructive, filled for confirm-in-sheet.
- *Text*: `primary` label, no fill (nav bar actions, inline).
- *Small pill*: 32pt height, `radius-pill`.
- *Disabled*: 38% opacity, no interaction.

**Form fields** — Label (footnote semibold) above a `surfaceSecondary` field, `radius-md`, 46pt height. Steppers use a `surfaceSecondary` track with a raised (`e1`) increment control. Segmented controls = `surfaceSecondary` track + raised selected segment. Toggles = system switch, `success` when on.

**Chips / tags** — 28–30pt pills. *Filter chips*: selected = `primary` fill; idle = `border` outline + `textSecondary`. *Goal tags*: `surfaceSecondary` fill + 7px category dot. *Status pills*: outline + coloured dot + label (Active=`success`, Pending=`warning`, Paused=`textSecondary`).

**Stat tiles** — `surfaceSecondary` (or `surface`) tile: caption label, large tabular number, coloured delta line (`success`/`danger`).

**Verified badge** — filled `verified` pill, checkmark + "Verified journey"; a compact inline variant (outline check + "Verified"); a 22–24px circular check for avatar overlays / lock-ups. Always accompanied by substantiation copy nearby.

**Avatars** — circular, initials on a muted fill by default; `radius-pill`. Verified coaches get a `verified` check overlay (bottom-right, 3px `surface` ring). Stacked groups overlap −10px with a 2px `surface` ring + "+N".

**Empty states** — centered: `surfaceSecondary` icon chip → headline → one-line footnote → single primary action. Warm, never scolding.

**Progress chart** — line + soft area fill (`chart-fill` = 12–16% `primary`), 2.5px stroke, end-point dot, tabular-figure value + directional delta, sparse mono axis labels (Wk 1 / Now). Weight-loss charts may use `success` for the "down is good" line. Keep gridlines minimal or omit.

---

## 4. Interaction & motion

- **Motion is quiet and physical.** Sheet presentations, push transitions and tab switches use system defaults. Custom animations use `spring(response: 0.35, dampingFraction: 0.9)` — settle fast, no bounce theatre.
- **Logging feedback:** on save, the delta line animates in and a light haptic (`.success` notification / `.impact(.light)`) fires. No confetti.
- **Rest timer** counts down live in the workout player; a subtle pulse + haptic at 0.
- **Verified badge** never animates on its own — trust marks stay still and factual.
- **Pull-to-refresh** on Today / Clients; swipe actions on list rows (message, log, archive).
- **Reduce Motion** respected: cross-fades replace slides; Dynamic Type and increased-contrast supported throughout.
- **Navigation:** large-title screens collapse to inline titles on scroll (standard). Modals for creation/consent; push for drill-downs (client → program → workout).
- **Role switch:** presented as a bottom sheet from the avatar/Me tab; switching cross-fades the tab bar and root — coaching and training data stay fully separate.

---

## 5. iOS-native patterns
- SF Symbols for all iconography (calendar, person.2, list.bullet, bubble.left, chart.line.uptrend.xyaxis, dumbbell, checkmark.seal, shield, etc.).
- Standard `NavigationStack` + `TabView`; `.searchable` for the Clients list; `.sheet` / `.presentationDetents([.medium, .large])` for consent and role switch.
- System materials for tab bar / nav bar translucency.
- Dynamic Type, Dark Mode, VoiceOver labels on every control, and 44pt minimum targets are requirements, not options.
