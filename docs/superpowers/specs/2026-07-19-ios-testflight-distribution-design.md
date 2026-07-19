# On-demand iOS TestFlight distribution — design

- **Date:** 2026-07-19
- **Status:** approved (brainstormed with maintainer)
- **Companion:** `docs/superpowers/specs/2026-07-15-android-firebase-distribution-design.md`
  (the Android pipeline this mirrors), AgDR-0004.

## Problem

Stakeholder test builds exist for Android only (Firebase App Distribution via
`distribute-android.yml`). iOS stakeholders have no way to receive builds. The
existing `scripts/distribute_ios.sh` targets Firebase App Distribution with
ad-hoc signing, which requires registering every tester iPhone's UDID in the
Apple Developer portal and re-signing on every tester change — unworkable
friction for a stakeholder audience.

Separately, both distribution workflows re-run the full quality gates
(analyze + test suite, ~6–8 min) even though CI already validated the same
commit. The maintainer wants distribution runs fast.

## Goals

- On-demand ("cut a release" button) iOS distribution to beta testers via
  **TestFlight**, mirroring the Android workflow's shape: manual trigger,
  chosen ref, stakeholder release notes taken verbatim from `CHANGELOG.md`.
- Support **both TestFlight tiers**: internal testers (instant, no review) and
  an external `beta-testers` group (email/public-link invites, Beta App Review
  on first build).
- Replace the slow gate re-run in **both** distribution workflows with a fast
  "was CI green for this exact commit?" check.
- No per-release manual console steps once set up.

## Non-goals

- App Store release submission (TestFlight only).
- Firebase App Distribution for iOS (rejected: UDID management friction).
  `scripts/distribute_ios.sh` and `ios/ExportOptions.plist` remain for
  local/ad-hoc use but are not wired into CI.
- Xcode Cloud (second CI system; config would live outside the repo).
- fastlane `match` / a certificates repo (single-team project; a `.p12` secret
  is sufficient).

## Decisions (settled during brainstorming)

- **Channel:** TestFlight, not Firebase App Distribution — no UDID collection,
  up to 10,000 external testers, crash reports included.
- **Tiers:** both — internal for immediate sanity checks, external group
  `beta-testers` for stakeholders.
- **App Store Connect state:** no app record exists yet; one-time setup is part
  of this design (checklist below).
- **Gates:** distribution workflows do NOT re-run analyze/tests. They verify
  the shipped commit already has a green CI run, and fail loudly otherwise.
  Rationale: `main` has **no branch protection** (verified 2026-07-19 — direct
  pushes land without CI), and the `ref` input can target any commit, so
  dropping verification entirely would let a broken commit ship. The check
  preserves the invariant at ~5s instead of ~6–8 min. A `force` input allows a
  deliberate override.
- **Tooling:** `xcodebuild` cloud signing for the build, fastlane `pilot`
  (preinstalled on GitHub macOS runners) for the upload. `pilot` sets "What to
  Test" from the changelog and distributes to the external group — the pure
  `apple-actions/*` alternative cannot do either.
- **Signing (revised during planning):** Xcode **cloud signing** — automatic
  signing style with `-allowProvisioningUpdates` authenticated by the ASC API
  key. xcodebuild creates/manages the distribution certificate and App Store
  profile itself, headlessly. This drops the `.p12` secrets, the certificate
  export step, and `sigh` from the original design, and avoids the known
  CocoaPods failure where global `PROVISIONING_PROFILE_SPECIFIER` /
  `CODE_SIGN_IDENTITY` overrides break Pod targets during archive. Fallback if
  cloud signing misbehaves: the manual p12 + `sigh` path (documented in
  Alternatives).

## Design

### 1. Trigger & inputs (`.github/workflows/distribute-ios.yml`)

`workflow_dispatch` only, concurrency group `distribute-ios`
(no parallel runs, no cancel-in-progress). Runner: `macos-15` (free — public
repo). Pinned `FLUTTER_VERSION: 3.35.7` (keep in sync with `ci.yml`).

Inputs:

| input                 | default        | meaning                                              |
|-----------------------|----------------|------------------------------------------------------|
| `ref`                 | (UI dropdown)  | commit SHA / branch / tag to ship                    |
| `external_groups`     | `beta-testers` | TestFlight external group(s), comma-separated        |
| `distribute_external` | `true`         | also push to the external group (internal always get the build) |
| `force`               | `false`        | skip the green-CI check (emergencies only)           |

### 2. Green-CI check (shared pattern, both workflows)

A step (no external action) that resolves the checked-out SHA and queries
`gh api repos/$REPO/commits/$SHA/check-runs` with the built-in
`GITHUB_TOKEN` (`permissions: checks: read`). Pass only when the CI workflow's
jobs for that exact SHA all concluded `success`. Distinct failure messages:

- CI concluded failure → "CI is red for <sha> — fix or pick another commit."
- CI in progress → "CI still running for <sha> — retry when green."
- No CI run found → "No CI run for <sha> — push it through CI first (or use force)."

`force: true` skips the step with a loud `::warning::`.

`distribute-android.yml` drops its `Analyze` and `Unit, widget and E2E tests`
steps in favor of this check (same step, same messages). Everything else in
the Android workflow is unchanged.

### 3. Signing in CI (cloud signing)

- **Build:** `flutter build ios --release --no-codesign` compiles the app;
  `xcodebuild archive` + `xcodebuild -exportArchive` then run with
  `-allowProvisioningUpdates -authenticationKeyPath/-authenticationKeyID/
  -authenticationKeyIssuerID` (the ASC API key). Xcode registers the bundle
  id if needed and creates/manages a cloud-managed *Apple Distribution*
  certificate and App Store profile — no keychain import, no `sigh`, no
  global signing-setting overrides (which are known to break CocoaPods
  targets during archive).
- **Export:** new `ios/ExportOptionsAppStore.plist` — `method:
  app-store-connect`, `teamID: 327MX655VL`, `signingStyle: automatic`.
- **API key:** the `.p8` is materialized from secrets into `$RUNNER_TEMP`
  (never the repo tree), both as the raw key for xcodebuild and as a fastlane
  API-key JSON file for `pilot`.

### 4. Build & upload

- `flutter build ipa --release --build-number=${{ github.run_number }}
  --export-options-plist=ios/ExportOptionsAppStore.plist`. The run number
  gives every distribution a unique, increasing `CFBundleVersion` (independent
  of Android's sequence — the stores never compare them).
- `scripts/extract_release_notes.sh CHANGELOG.md` → notes file; fails the run
  if the top section is empty (same standing convention as Android).
- `fastlane pilot upload` with the API key JSON: uploads the IPA, waits for
  processing, sets "What to Test" from the notes, and (when
  `distribute_external`) assigns the build to `external_groups`.
- `ios/Runner/Info.plist` gains `ITSAppUsesNonExemptEncryption = false`
  (HTTPS-only app → exempt) so builds never stall on the export-compliance
  question.

### 5. Secrets (one-time human setup — cannot be automated)

| secret                      | source                                                                 |
|-----------------------------|------------------------------------------------------------------------|
| `ASC_API_KEY_ID`            | App Store Connect → Users and Access → Integrations → new key (*App Manager* role) |
| `ASC_API_ISSUER_ID`         | same page (issuer id is per-team)                                      |
| `ASC_API_KEY_P8_BASE64`     | the downloaded `.p8`, base64-encoded (downloadable **once**)           |

(The original design also required a `.p12` distribution certificate; cloud
signing made it unnecessary.)

### 6. One-time Apple setup checklist (maintainer, in the portals)

1. Confirm the Apple Developer Program membership for team `327MX655VL` is
   paid/active.
2. developer.apple.com → Identifiers: register `com.alrasikhoon.alRasikhoon`
   with capabilities matching the Xcode project (at minimum Push Notifications
   if FCM is used).
3. App Store Connect → My Apps → New App: platform iOS, bundle id from step 2,
   name/primary language/SKU.
4. Users and Access → Integrations: create the API key → secrets above.
5. TestFlight tab: add internal testers; create external group `beta-testers`
   (email invites or a shareable public link); fill in the required **Test
   Information** — beta description, feedback email, privacy policy URL, and
   **demo sign-in credentials for Apple's Beta App Review** (the app requires
   login; review is rejected without them).

### 7. Documentation

- `.github/workflows/README.md`: add the iOS workflow, its secrets, and the
  updated gate story for both workflows.
- The changelog convention in `al_rasikhoon/CLAUDE.md` already covers iOS
  (notes come from the same top section); no change needed.

## Data flow

```
maintainer clicks "Run workflow" (ref, groups, external?, force?)
  → checkout ref
  → green-CI check (gh api check-runs for SHA)        [~5s; force skips]
  → Flutter 3.35.7, pub get
  → extract_release_notes.sh CHANGELOG.md             [fails if empty]
  → write ASC API key files to $RUNNER_TEMP
  → flutter build ios --no-codesign (run_number as build number)
  → xcodebuild archive + -exportArchive (cloud signing via ASC API key)
  → pilot upload: → TestFlight processing → "What to Test" ← notes
       → internal testers (instant)
       → external group(s) (first build: Beta App Review ~24–48h)
```

## Error handling

- Missing/empty secrets → explicit `exit 1` with the secret name (mirrors the
  Android keystore check).
- Green-CI check failures → the three distinct messages above.
- Empty changelog top section → `extract_release_notes.sh` fails the run.
- `xcodebuild`/`pilot` failures (bad API key, signing errors, processing
  rejection) surface as step failures with the tool's error output.

## Testing / verification

1. First run with `distribute_external: false` — proves signing, build, upload
   and internal-tester delivery end-to-end without touching review.
2. Confirm "What to Test" shows the changelog text verbatim.
3. Second run with `distribute_external: true` after Test Information is
   complete — expect Beta App Review on the first external build.
4. Android workflow: one distribution run against a green main commit
   (check passes, gates skipped) and one against a doctored/unknown SHA
   (check fails with the right message).

## Alternatives considered

- **Firebase App Distribution (ad-hoc) for iOS** — parity with Android's
  console, but UDID registration per tester device and re-sign on every tester
  change; rejected for a stakeholder audience.
- **Pure `apple-actions/*` (no fastlane)** — leaner, but cannot set "What to
  Test" or assign the external group; would reintroduce per-release console
  work; rejected.
- **Xcode Cloud** — config lives in App Store Connect, can't reuse the repo's
  gates/changelog conventions; rejected.
- **Keeping full gate re-runs in distribution workflows** — safe but slow;
  replaced by the green-CI check which preserves the invariant at ~5s.
- **Manual signing (p12 secrets + `fastlane sigh` + build-setting overrides)**
  — the original §3; works, but needs two more secrets, a certificate export
  ritual, and global `PROVISIONING_PROFILE_SPECIFIER` overrides that are known
  to break CocoaPods targets during archive. Kept as the documented fallback
  if cloud signing fails.
