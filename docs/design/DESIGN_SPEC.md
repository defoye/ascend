# Ascend — Design Spec

The visual system for Ascend: the operating system for independent fitness coaches
and the clients they train, and a **trust layer for physical improvement**. This spec
is the source of truth for `Modules/DesignSystem` and every screen built on top of it
(see `docs/ROADMAP.md`). The paired visual reference is `docs/design/mockups.html`.

> **Copy invariant (Invariant 2, docs/PRODUCT.md):** results are **verified journeys
> with a coach**, never "the coach caused the result." This governs every string in
> the UI, not just marketing surfaces. Do not soften it.

---

## 1. Design principles

1. **Trust is the brand.** Premium, calm, credible, data-honest. Reference feeling:
   Things / Oura / Whoop / Apple Health — never a loud neon gym app. Restraint reads
   as credibility.
2. **Proof over hype.** The "Verified" accent (a distinct teal) is reserved *only* for
   verified-journey surfaces. It is never a generic decoration; scarcity is what makes
   it mean something.
3. **Data honest.** Charts and stats never exaggerate. Y-axes are labeled, sources are
   shown, and journey copy describes measured change over time — not causation.
4. **Two roles, one brand.** The coach surface is the dense business tool; the client
   surface is a calmer, lighter, focused daily surface. Same tokens, same components —
   the client side simply uses more whitespace and fewer dense controls.
5. **iOS-native.** SF Pro, SF Symbols, standard navigation, Dynamic Type, and system
   materials. We extend the platform; we don't fight it.

---

## 2. Color tokens

Every token below ships as a **color set in the asset catalog** (`Colors.xcassets`)
with an explicit **Any (light)** and **Dark** appearance, and is surfaced through a
`Color.Ascend.<token>` accessor (see §7). All hex values are sRGB. Text/!background
pairs listed as "AA" meet WCAG 2.1 AA (≥4.5:1 body, ≥3:1 large/semibold ≥17pt or
≥24pt).

### 2.1 Light

| Token | Hex | Role |
|---|---|---|
| `backgroundPrimary` | `#F6F8FB` | App background (grouped surfaces sit on this) |
| `backgroundSecondary` | `#FFFFFF` | Secondary/grouped background |
| `surface` | `#FFFFFF` | Card / row / sheet surface |
| `surfaceElevated` | `#FFFFFF` | Elevated surface (paired with elevation shadow) |
| `primary` | `#2557D6` | Primary brand action (fills, key CTAs) |
| `primaryPressed` | `#1E47B0` | Primary pressed/active state |
| `onPrimary` | `#FFFFFF` | Foreground on `primary` — AA (white on `primary`) |
| `verified` | `#0F766E` | **Verified Outcomes accent** (teal) — reserved |
| `verifiedSurface` | `#E6F4F2` | Tinted background behind verified badges/blocks |
| `success` | `#1E8E5A` | Positive/confirmed (paid, completed) |
| `warning` | `#B45309` | Caution (pending, no-show risk) — text-safe amber |
| `danger` | `#DC2626` | Destructive / error |
| `onDanger` | `#FFFFFF` | Foreground on `danger` — AA |
| `textPrimary` | `#141A22` | Primary text — AA on all backgrounds |
| `textSecondary` | `#5B6472` | Secondary text/labels — AA on `backgroundPrimary` |
| `textTertiary` | `#8A93A2` | Tertiary/placeholder (non-essential only) |
| `border` | `#E4E8EE` | Hairline separators, card borders |
| `borderStrong` | `#CBD2DC` | Emphasized borders, unfilled control outlines |
| `scrim` | `#141A22` @ 40% | Modal/overlay scrim |

### 2.2 Dark

Dark mode is premium near-black (Oura/Whoop): it prefers **surface elevation steps +
subtle borders** over heavy shadows.

| Token | Hex | Role |
|---|---|---|
| `backgroundPrimary` | `#0B0E13` | App background |
| `backgroundSecondary` | `#12161D` | Secondary/grouped background |
| `surface` | `#171C24` | Card / row / sheet surface |
| `surfaceElevated` | `#1F262F` | Elevated surface (one step lighter than `surface`) |
| `primary` | `#3D6FE3` | Primary brand action |
| `primaryPressed` | `#5B8DEF` | Primary pressed/active (lighter on dark) |
| `onPrimary` | `#FFFFFF` | Foreground on `primary` — AA |
| `verified` | `#2DD4BF` | Verified accent (bright teal for dark) |
| `verifiedSurface` | `#0E2A28` | Tinted background behind verified badges/blocks |
| `success` | `#34D399` | Positive/confirmed |
| `warning` | `#FBBF24` | Caution |
| `danger` | `#F87171` | Destructive / error |
| `onDanger` | `#141A22` | Foreground on dark `danger` — AA |
| `textPrimary` | `#F2F5F9` | Primary text — AA |
| `textSecondary` | `#A0A9B8` | Secondary text/labels — AA on `backgroundPrimary` |
| `textTertiary` | `#6B7482` | Tertiary/placeholder |
| `border` | `#262D37` | Hairline separators, card borders |
| `borderStrong` | `#39424E` | Emphasized borders |
| `scrim` | `#000000` @ 55% | Modal/overlay scrim |

> **Contrast note:** `onPrimary`/`onDanger` labels are always used at semibold ≥17pt
> (large-text threshold), and the fill tokens above are chosen so the pair meets AA.
> `textTertiary` is decorative/placeholder only — never the sole carrier of meaning.

---

## 3. Typography

SF Pro (system). Sizes map to SwiftUI **text styles** so Dynamic Type scales them
automatically; weight/design are applied on top. Never hard-code a fixed point size
where a text style exists.

| Token | Text style basis | Size / Weight / Leading | Use |
|---|---|---|---|
| `largeTitle` | `.largeTitle` | 34 / Bold / 41 | Screen hero titles |
| `title1` | `.title` | 28 / Bold / 34 | Section-level titles |
| `title2` | `.title2` | 22 / Bold / 28 | Card group titles |
| `title3` | `.title3` | 20 / Semibold / 25 | Sub-section titles |
| `headline` | `.headline` | 17 / Semibold / 22 | Row titles, emphasis |
| `body` | `.body` | 17 / Regular / 22 | Body copy |
| `callout` | `.callout` | 16 / Regular / 21 | Secondary body |
| `subheadline` | `.subheadline` | 15 / Regular / 20 | Supporting text |
| `footnote` | `.footnote` | 13 / Regular / 18 | Metadata, timestamps |
| `caption` | `.caption` | 12 / Regular / 16 | Labels, chip text |
| `caption2` | `.caption2` | 11 / Regular / 13 | Dense metadata |
| `statLarge` | `.largeTitle` | 34 / Semibold / **rounded + monospaced digits** | Hero stat values |
| `statMedium` | `.title2` | 22 / Semibold / **rounded + monospaced digits** | StatTile values |

Numeric/stat styles use `.fontDesign(.rounded)` and `.monospacedDigit()` so figures
align and read as instrument-panel data.

---

## 4. Spacing, radii, elevation

**Spacing** — 4pt base grid:

| Token | pt |
|---|---|
| `xxs` | 2 |
| `xs` | 4 |
| `sm` | 8 |
| `md` | 12 |
| `lg` | 16 |
| `xl` | 24 |
| `xxl` | 32 |
| `xxxl` | 48 |

Default screen horizontal inset: `lg` (16). Default card padding: `lg` (16). Default
vertical rhythm between grouped elements: `md`–`lg`.

**Radii:**

| Token | pt | Use |
|---|---|---|
| `sm` | 8 | Chips-in-field, small controls |
| `md` | 12 | Buttons, text fields |
| `lg` | 16 | Cards, tiles, sheets |
| `xl` | 24 | Large hero cards |
| `capsule` | ∞ | Chips/tags, pills, avatars |

**Elevation** — light mode uses soft shadows; dark mode uses surface steps + border.

| Token | Light | Dark |
|---|---|---|
| `level0` | none | none |
| `level1` (resting card) | shadow: y 2, blur 8, `#141A22` @ 6% | `surface` + 1px `border` |
| `level2` (elevated/sheet) | shadow: y 8, blur 24, `#141A22` @ 12% | `surfaceElevated` + 1px `border` |

The `DesignSystem` provides an `.ascendElevation(_)` view modifier that resolves the
correct treatment per color scheme.

---

## 5. Components

All components are theme-aware, Dynamic-Type-correct, and expose accessibility labels.
Interactive controls have a **≥44×44pt** hit target. **No business logic** lives here —
components take plain values (`String`, `Double`, `Date`, arrays of plain data points),
never Domain types.

### AscendButton
- Variants: **primary** (filled `primary`/`onPrimary`), **secondary** (tinted:
  `primary` text on `primary`@10% fill, 1px `borderStrong`), **destructive** (filled
  `danger`/`onDanger`).
- Sizes: `large` (52pt tall, full-width default) and `compact` (44pt tall).
- Corner radius `md` (12). Label `headline` (semibold 17). Optional leading SF Symbol.
- States: normal, pressed (use `*Pressed`/opacity 0.9 + 0.98 scale), disabled (40%
  opacity, no shadow), loading (swaps label for `ProgressView`, control disabled).
- Min hit target 44pt even at `compact`. Accessibility: `.isButton`; loading sets
  `accessibilityLabel` + `.updatesFrequently` and hides the spinner.

### Card
- `surface` fill, radius `lg` (16), padding `lg`, `.ascendElevation(.level1)`.
- Optional 1px `border` in both modes for crispness. Accepts arbitrary content.

### ListRow
- Leading (icon/avatar), title (`headline`) + subtitle (`subheadline`, `textSecondary`),
  optional trailing (value/chevron/accessory). 44pt min height, `md` vertical padding.
- Tappable variant renders a chevron and is a single a11y element combining title +
  subtitle + trailing value.

### AscendTextFieldStyle (`TextFieldStyle`)
- `surface` fill, 1px `borderStrong` (→ `primary` when focused), radius `md`, `md`
  padding, `body` text. Supports label above + footnote helper/error (`danger`) below.
- Placeholder uses `textTertiary`. 44pt min height.

### Chip / Tag
- Capsule, `caption`/`footnote` text. Tones: `neutral` (`textSecondary` on
  `border`@ fill), `primary`, `success`, `warning`, `verified`. Optional leading SF
  Symbol. Optional selected state (filled tone). Decorative chips are
  `.accessibilityHidden` when the text is redundant.

### StatTile
- Compact metric block: `caption` uppercase-tracked label (`textSecondary`), `statMedium`
  value, optional delta (`success`/`danger` with ▲/▼ + `footnote`), optional unit.
- `surface`, radius `lg`, padding `lg`. Grid-friendly (2-up / 3-up). A11y: label + value
  + delta combined into one spoken string ("Sessions, 128, up 12 this month").

### VerifiedBadge
- The trust mark. `verified` seal SF Symbol (`checkmark.seal.fill`) + "Verified"
  (`caption`, semibold) on `verifiedSurface`, capsule. Sizes `small`/`medium`.
- Accessibility label: **"Verified journey"** (never "verified result"). Reserved for
  verified-outcome surfaces only.

### Avatar
- Circle. Renders an image when provided, else initials on a deterministic tinted
  background derived from the name. Sizes `sm` 28, `md` 40, `lg` 56, `xl` 88.
- Optional small `VerifiedBadge` overlay affordance. A11y label: person's name.

### EmptyState
- Centered SF Symbol (in a `primary`@10% circle), `title3` title, `subheadline`
  `textSecondary` message, optional primary `AscendButton`. Used for zero-data screens.

### SectionHeader
- `footnote`/`caption` uppercase-tracked title (`textSecondary`) + optional trailing
  action (`AscendButton` compact/plain "See all"). `lg` leading inset, `sm` bottom.

### ProgressChart (Swift Charts)
- Line + area (gradient fill from `primary`@25% → clear) over time. Plain input:
  `[ProgressPoint]` where `ProgressPoint = (date: Date, value: Double)`, plus a title,
  unit label, and optional target line (dashed `verified`).
- Labeled Y axis (never zero-baseline-hidden in a misleading way), `footnote` axis text,
  `.monospacedDigit()` values. Optional "start → latest" caption framed as a journey.
- A11y: `.accessibilityChartDescriptor` / element per point with date + value; overall
  label summarizes start, latest, and net change as a **measured journey**.

---

## 6. Interaction & motion

- Motion is quiet: 0.2–0.25s ease-in-out for state changes; spring only for sheet/press.
- Press feedback: 0.98 scale + pressed color. Honor **Reduce Motion** (cross-fade
  instead of movement) and **Reduce Transparency** (solid `surface` instead of material).
- Standard iOS navigation (push/sheet), SF Symbols throughout, pull-to-refresh on lists.
- Haptics: light impact on primary actions, success notification on verified/paid events.

---

## 7. SwiftUI token mapping

The `DesignSystem` module exposes tokens so Features never reference raw hex:

- **Colors:** `Color.Ascend.<token>` (e.g. `Color.Ascend.primary`, `.verified`,
  `.textSecondary`) — backed by `Colors.xcassets` color sets of the same name, loaded
  from the DesignSystem bundle.
- **Typography:** `Font.Ascend.<token>` (e.g. `.headline`, `.statMedium`) and a
  `.ascendType(_)` `Text`/`View` modifier that also applies rounded/monospaced-digit
  where the token requires it.
- **Spacing / radii:** `Spacing.<token>` (CGFloat) and `Radius.<token>` (CGFloat),
  `CornerRadius.capsule` via `Capsule()`.
- **Elevation:** `.ascendElevation(_ level:)` view modifier.

Component call sites read like the platform: `AscendButton("Log session", .primary) { … }`,
`StatTile(label: "Retention", value: "92%", delta: .up("4%"))`, etc.

---

## 8. Accessibility checklist (Definition of Done for every component)

- [ ] Renders correctly in light **and** dark (previews prove both).
- [ ] Scales with Dynamic Type through at least AX3 without clipping (text styles, no
      fixed sizes; layouts wrap/scroll).
- [ ] Every interactive element ≥44×44pt and exposes a role + meaningful label.
- [ ] Color pairs meet WCAG AA (§2); color is never the *only* signal (icon/label too).
- [ ] Honors Reduce Motion and Reduce Transparency.
- [ ] Verified/proof copy follows Invariant 2 ("journey," never "caused").
