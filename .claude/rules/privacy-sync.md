---
paths:
  - docs/PRIVACY_POLICY.md
  - "**/PrivacyPolicyView.swift"
  - "**/PrivacyInfo.xcprivacy"
---

These three describe the same data-collection policy and MUST change
together: `docs/PRIVACY_POLICY.md` (bundled plain-language policy),
`Modules/Features/Sources/Settings/PrivacyPolicyView.swift` (canonical in-app
copy), and `App/Resources/PrivacyInfo.xcprivacy` (the machine-readable
declaration Apple's App Store review checks). Editing one without reconciling
the other two ships a contradiction between what the app says, shows, and
declares to Apple.
