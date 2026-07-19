# GitHub Actions Workflows

CI for the Al-Rasikhoon repo. Added under issue #6.
Design rationale: [`docs/agdr/AgDR-0001-github-actions-ci.md`](../../docs/agdr/AgDR-0001-github-actions-ci.md).

## `ci.yml`

**Triggers:** every pull request, and every push to `main`.
Concurrent runs on the same ref are cancelled to save CI minutes.

Two independent jobs run in parallel (no dependency between them, so one
toolchain failing does not mask the other):

### Job: `flutter` — analyze + unit tests

| Step | Command | Notes |
|------|---------|-------|
| Set up Flutter | `subosito/flutter-action@v2` | Pinned to Flutter **3.35.7** (stable) — bundles Dart 3.9.2 to satisfy `pubspec.yaml`'s `sdk: ^3.9.2`. |
| Resolve deps | `flutter pub get` | |
| Analyze | `flutter analyze` | Fails the job on any analyzer error/warning (default behaviour). |
| Unit, widget and E2E tests | `flutter test test/` | Everything: unit, widget, and the five E2E suites in `test/e2e/`. All on the Dart VM — no device, no simulator (closes **issue #5**). The E2E suites fake Firestore and override every provider, so they never needed a device; the one they used to demand cost a ~28-minute cold Xcode build per run, which is why nothing ran them. They execute at a real phone's viewport, **safe-area padding included** — the host's default 800×600 surface hides precisely the below-the-fold bugs the suite exists to catch. `integration_test/firebase_emulator_flow_test.dart` is NOT run here: it talks to a real Firestore via `firebase emulators:start`. |

### Job: `functions` — build + lint

Runs with working directory `functions/`.

| Step | Command | Notes |
|------|---------|-------|
| Set up Node.js | `actions/setup-node@v4` | Version from the single `NODE_VERSION` env constant in `ci.yml`, which mirrors `functions/package.json` → `engines.node` (`22`). Change that one constant on a runtime bump. |
| Install deps | `npm install` | Not `npm ci`: `functions/package-lock.json` is intentionally gitignored, so there is no committed lockfile to install from. See the AgDR tradeoffs section. |
| Build | `npm run build` | `tsc` per `functions/package.json`. |
| Lint | `npm run lint --if-present` | Runs `eslint --ext .ts src/`; `--if-present` makes it a no-op if the script is ever removed. |

## `distribute-android.yml`

**Trigger:** **manual only** (`workflow_dispatch`) — there is a **"Run
workflow"** button in the Actions tab. Distribution never happens automatically
on push; a maintainer clicks it to cut a stakeholder build. This is deliberate:
stakeholders get a curated build when the team decides one is ready, not one per
merge (see [`AgDR-0004`](../../docs/agdr/AgDR-0004-android-firebase-distribution.md)).

**How to release:** Actions tab → **Distribute Android** → **Run workflow** →
(optionally set inputs) → **Run workflow**.

| Input | Default | Purpose |
|-------|---------|---------|
| `ref` | the ref picked in the "Use workflow from" dropdown (normally `main`) | A specific commit SHA / branch / tag to ship. Leave blank to ship the selected branch tip; set it to release an earlier merge. |
| `groups` | `beta-testers` | Firebase App Distribution tester group(s), comma-separated. |
| `run_agent_tests` | `true` | Run the Firebase App Testing agent (AI tester on a real Test Lab device) against the release. See [`apptesting/README.md`](../../apptesting/README.md). |
| `test_case_ids` | blank (= the smoke suite) | Override which test case ids from `apptesting/testcases.yaml` the agent runs. |
| `force` | `false` | Skip the green-CI check (emergencies only). |

Builds a release-signed APK and uploads it to Firebase App Distribution. Reuses
`scripts/distribute_android.sh` (build + upload) and
`scripts/extract_release_notes.sh` (release notes).

| Step | Notes |
|------|-------|
| Checkout | Checks out `inputs.ref` (or the dispatched ref). |
| Set up JDK 17 | Android Gradle runs on JDK 17 (app source/target stays Java 11). |
| Set up Flutter | Same pinned `FLUTTER_VERSION` as `ci.yml`. |
| Require green CI | `.github/actions/require-green-ci` (~5s): fails unless the chosen commit already has a successful `CI` run — a broken or unvalidated ref still cannot ship, without re-running the gates. `force: true` skips it. |
| Set up Node + Firebase CLI | Node installs `firebase-tools` for the upload. |
| Configure release signing | Decodes `ANDROID_KEYSTORE_BASE64` to `$RUNNER_TEMP` and writes `android/key.properties` pointing at it. |
| Generate release notes | `scripts/extract_release_notes.sh CHANGELOG.md`; **fails if the top section is empty**. |
| Build, distribute and run App Testing agent | `scripts/distribute_android.sh apk` with `BUILD_NUMBER=github.run_number` (unique `versionCode`) and the notes file. When `run_agent_tests` is on, the script also re-imports `apptesting/testcases.yaml` (upsert) and runs the smoke suite on the release via the App Testing agent; a test failure fails the run **after** distribution (post-release smoke alarm, not a delivery gate). Without the `APP_TESTING_*` secrets only the signed-out tests run. |

**Release notes** are the top section of the root `CHANGELOG.md`, written for
stakeholders. Keeping it current is a convention documented in `CLAUDE.md` /
`AGENTS.md`.

## `distribute-ios.yml`

On-demand TestFlight distribution — the iOS counterpart of
`distribute-android.yml`. Manual trigger only ("Run workflow"), same
green-CI gate, same stakeholder release notes taken verbatim from the top
section of `CHANGELOG.md` (empty top section fails the run, shown in
TestFlight as "What to Test").

Runs on `macos-15` (free: public repo). Signing is Xcode **cloud signing**:
automatic signing + `-allowProvisioningUpdates` authenticated by the App
Store Connect API key — certificates and profiles are created and managed
by Apple, nothing signing-related lives in secrets.

Inputs: `ref` (commit to ship), `external_groups` (default `beta-testers`),
`distribute_external` (default true; internal testers always receive the
build), `force` (skip the green-CI check).

Internal testers receive builds minutes after Apple finishes processing.
External groups require Apple's Beta App Review on the first build
(~24–48h) and completed TestFlight Test Information — including demo
sign-in credentials, since the app requires login.

Design: `docs/superpowers/specs/2026-07-19-ios-testflight-distribution-design.md`

**How to release:** Actions tab → **Distribute iOS** → **Run workflow** →
(optionally set inputs) → **Run workflow**.

## Secrets

`ci.yml` (`flutter` and `functions`) requires no secrets. Both
`distribute-android.yml` and `distribute-ios.yml` workflows require repo secrets
(Settings → Secrets and variables → Actions); provision them once:

| Secret | Source |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i /path/to/upload.jks` (the whole file, base64-encoded) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `al_rasikhoon`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `FIREBASE_TOKEN` | `firebase login:ci` (account with Firebase App Distribution Admin on `alrasikhoon-57151`) |
| `APP_TESTING_USERNAME` | username of the dedicated QA account the App Testing agent signs in with (optional — without it only signed-out tests run) |
| `APP_TESTING_PASSWORD` | password of that QA account (optional, pairs with the username) |

Also ensure the `beta-testers` group exists in Firebase App Distribution.

### iOS (TestFlight)

| Secret | How to produce it |
|--------|-------------------|
| `ASC_API_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API → generate key with **App Manager** role; the Key ID shown in the list |
| `ASC_API_ISSUER_ID` | same page — the team-wide Issuer ID above the key list |
| `ASC_API_KEY_P8_BASE64` | download the key's `.p8` (possible **once**), then `base64 -i AuthKey_<KEYID>.p8 \| gh secret set ASC_API_KEY_P8_BASE64` |

## Removed workflows

- `functions-iam-audit.yml` (daily Gen2 Cloud Functions IAM audit) was removed
  because its Workload Identity Federation auth was never configured, so it
  failed every scheduled run without ever checking anything. The same audit
  (`scripts/audit_functions_iam.sh`) still runs after every deploy via
  `scripts/deploy_functions.sh`, which is where the 2026-05-10
  `setUserPassword` 403 regression it guards against would be introduced.

## Maintenance notes

- **Flutter bump:** edit `FLUTTER_VERSION` in `ci.yml`. Keep it on a stable
  release whose bundled Dart still satisfies `pubspec.yaml`'s SDK constraint
  (Flutter 3.35.0–3.35.2 bundle Dart 3.9.0 and would fail `^3.9.2`).
- **Node bump:** edit `NODE_VERSION` in `ci.yml` to match
  `functions/package.json` → `engines.node` whenever the runtime changes.
