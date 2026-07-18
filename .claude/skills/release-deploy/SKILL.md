---
name: release-deploy
description: Use when cutting a release or deploying backend changes — Supabase migrations (db push), Edge Function deploy, APNs/push setup, and Archive → TestFlight → App Store. Owner-run; has side effects.
disable-model-invocation: true
---

# Release & deploy runbooks

Owner-run. These have side effects on shared infrastructure (a live Supabase
project, Apple's signing/App Store systems) — the owner controls timing, not
Claude.

## Supabase migrations

One-time setup (needs the Supabase CLI: `brew install supabase/tap/supabase`):

```
supabase login
supabase link --project-ref <your project ref — see Config/Secrets.xcconfig's SUPABASE_URL, or `supabase projects list`>
supabase db push
```

`supabase login` opens a browser for interactive auth — the owner must run
this. `link` points the CLI at the existing Supabase project. `db push`
applies every migration in `Server/supabase/migrations/` in order (tables,
views, Storage buckets, RLS policies). Safe to re-run; already-applied
migrations are skipped.

Enable email/password sign-up if not already on: Supabase dashboard ▸
Authentication ▸ Providers ▸ Email.

## Edge Function deploy

From `Server/supabase/`:

```
supabase secrets set <KEY>=<value>   # see the specific function's env below
supabase functions deploy <function-name>
```

Functions in this repo:

- **`delete-account`** — backs `AuthGateway.deleteAccount()`. No extra secrets
  beyond the project's own service-role key.
- **`notify-message`** — sends APNs pushes for new messages. Needs:
  1. An APNs Auth Key (`.p8`) from the Apple Developer portal — note its Key
     ID and Team ID.
  2. Push Notifications capability + provisioning enabled on the App ID.
  3. `supabase secrets set APNS_KEY_ID=... APNS_TEAM_ID=... APNS_PRIVATE_KEY="$(cat your-key.p8)" APNS_BUNDLE_ID=com.ascend.Ascend`
  4. `supabase functions deploy notify-message`
  5. Configure a Database Webhook in the Supabase dashboard: table
     `public.messages`, event `INSERT`, type "Supabase Edge Functions",
     pointing at `notify-message`.

## Proving a live round-trip

The skippable integration test target exercises real Supabase when its two
env vars are set (and no-ops cleanly otherwise):

```
ASCEND_TEST_SUPABASE_URL=<SUPABASE_URL from Config/Secrets.xcconfig> \
ASCEND_TEST_SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY from Config/Secrets.xcconfig> \
xcodebuild test \
  -workspace Ascend.xcworkspace -scheme SupabaseBackendIntegrationTests \
  -destination 'id=<a booted simulator UUID — see `xcrun simctl list devices`>'
```

If a test fails against real RLS, that's signal to adjust the migration or the
test fixture.

Then flip Release to actually run against Supabase: `tuist generate`, then
`xcodebuild build -scheme Ascend -configuration Release -destination
'generic/platform=iOS'` — Release already reads `Config/Secrets.xcconfig` via
Info.plist (`App/Sources/SupabaseConfig.swift`), so no further code change is
needed.

## Archive → TestFlight → App Store

**One-time setup**
1. Enroll in the Apple Developer Program ($99/yr); sign in to Xcode (Xcode ▸
   Settings ▸ Accounts ▸ **＋**).
2. In App Store Connect: Apps ▸ **＋** ▸ New App — Platform iOS, Bundle ID
   `com.ascend.Ascend` (create it under Certificates, Identifiers & Profiles ▸
   Identifiers first if not listed), name "Ascend".
3. On the generated Xcode project's **Ascend** target ▸ Signing &
   Capabilities: enable **Automatically manage signing**, pick your Team.
   Because the project is Tuist-generated, set the team via a `TUIST_`
   xcconfig or the Xcode UI on each `tuist generate` — never hand-edit
   `.xcodeproj` and commit it.

**Every release**
4. `tuist generate`.
5. Bump the build number if re-uploading: `CFBundleVersion` in
   `Project.swift`'s `appInfoPlist`, then `tuist generate` again.
6. Open `Ascend.xcworkspace` in Xcode. Set the run destination to **Any iOS
   Device (arm64)** — archives require a device SDK, not a simulator.
7. **Product ▸ Archive.** In the Organizer: select the archive ▸ **Distribute
   App** ▸ **TestFlight & App Store** (or **TestFlight Internal Only**) ▸
   **Upload** ▸ accept automatic signing ▸ **Upload**.
   - CLI equivalent:
     ```
     xcodebuild -workspace Ascend.xcworkspace -scheme Ascend \
       -configuration Release -destination 'generic/platform=iOS' \
       -archivePath build/Ascend.xcarchive archive
     xcodebuild -exportArchive -archivePath build/Ascend.xcarchive \
       -exportOptionsPlist ExportOptions.plist -exportPath build/export
     ```
     (`ExportOptions.plist` with `method = app-store-connect` and your team
     id; or `xcrun altool`/`notarytool`/Transporter.app to upload the `.ipa`.)
8. App Store Connect ▸ your app ▸ TestFlight: the build appears as
   "Processing" within a few minutes. Once processed, complete Export
   Compliance (standard HTTPS/OS crypto → "no" to the proprietary-encryption
   question), add internal testers, install via the TestFlight app.
9. **App Store submission** (once Release runs against a real backend):
   App Store Connect ▸ App Store tab ▸ fill in the privacy questionnaire to
   match `App/Resources/PrivacyInfo.xcprivacy` (Name, Fitness, Photos, Other
   User Content — all "app functionality", no tracking), add
   screenshots/description, attach the processed build, **Submit for
   Review**.

**Common gotchas**: "No account for team" → add the Apple ID in Xcode
Settings ▸ Accounts. "Bundle identifier not available" → the App Store
Connect record's bundle id must exactly equal `com.ascend.Ascend`. Archive
menu greyed out → destination is a simulator; switch to Any iOS Device.
