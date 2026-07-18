# CLAUDE.md

Map, not a knowledge base. Read the linked doc when its trigger applies.

<!-- Maintainer note: this file should stay under ~200 lines. New durable
knowledge goes in docs/ or .claude/rules/, not here — add a pointer instead. -->

## Critical gotchas (absence of these causes a mistake every session)

- `DEBUG` builds run on `InMemoryStore.seeded()` — the whole app, previews,
  and unit tests run with zero backend cost. Rationale: docs/BACKEND.md.
- Add/remove files by editing `Project.swift` globs, then `tuist generate`.
  **Never** hand-edit `.xcodeproj`/`.xcworkspace` — generated and gitignored.
  Full rule: `.claude/rules/project-structure.md`.
- The module dependency rule is enforced by Tuist; only the `Ascend` app
  target may wire in a concrete backend. Full rule:
  `.claude/rules/project-structure.md`.

## Doc map

- `docs/PRODUCT.md` — strategy and the two product invariants. Read before any
  product, copy, or scope decision.
- `docs/ARCHITECTURE.md` — why the module boundaries and the backend-behind-
  protocols seam exist. Read before changing module structure or the backend
  seam.
- `docs/DATA_MODEL.md` — domain semantics: invite claim rules,
  `VerifiedOutcome` eligibility, consent gating. Read before touching `Domain`
  types or engagement/invite/outcome logic.
- `docs/BACKEND.md` — backend selection, offline queue, payments seam. Read
  when working on persistence, sync, payments, or the Supabase adapter.
- `docs/TESTING.md` — testing philosophy. Read before writing tests; see
  `.claude/rules/swift-conventions.md` for the exact run command.
- `docs/ROADMAP.md` — what shipped, what's next, the single status source of
  truth. Read when picking up work or asking "why does X exist."
- `docs/DEMO_HARNESS.md` — the DEBUG demo/scenario harness. Read only when
  extending that harness.
- `docs/PRIVACY_POLICY.md` — user-facing privacy text. Read when data
  collection changes; see `.claude/rules/privacy-sync.md`.
- `docs/design/` — design tokens, spec, and the design-pass handoff bundle.
  Read when touching `DesignSystem` or building screens from the design pass.

## Workflows

- Implementing a numbered `docs/ROADMAP.md` prompt end-to-end (build, test,
  lint, tick the box, commit, push): `execute-roadmap-prompt` skill.
- Cutting a release or deploying backend changes (Supabase migrations, Edge
  Functions, APNs, Archive/TestFlight/App Store): `release-deploy` skill.
