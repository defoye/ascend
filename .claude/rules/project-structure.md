---
paths:
  - Project.swift
  - Modules/**
---

# Module dependency rule

Enforced structurally by Tuist module boundaries, not just convention — do not
violate it:

- `Domain` -> Foundation only. No SwiftUI, no Combine, no backend SDKs.
- `DataInterfaces` -> `Domain`.
- `InMemoryStore` -> `DataInterfaces`, `Domain`.
- `SupabaseBackend` -> `DataInterfaces`, `Domain`.
- `DesignSystem` -> (none).
- `Features` -> `DesignSystem`, `DataInterfaces`, `Domain` — never a concrete
  backend.
- `Ascend` (the App target) is the **only** composition root: the only target
  allowed to depend on a concrete backend adapter (`InMemoryStore`,
  `SupabaseBackend`) and wire one in.

<!-- Verified against Project.swift's target dependency arrays (appTarget,
dataInterfacesTarget, inMemoryStoreTarget, supabaseBackendTarget,
designSystemTarget, featuresTarget), 2026-07-17. Re-check here, not by memory,
after any Project.swift dependency edit. -->

Rationale (why the seam exists, not just what it is): docs/ARCHITECTURE.md.

# Tuist workflow

Add or remove files by editing the relevant target's `glob` in `Project.swift`,
then regenerate with `tuist generate`. **Never** hand-edit `.xcodeproj` /
`.xcworkspace` internals — they are generated and gitignored, and edits there
are silently lost on the next `tuist generate`.
