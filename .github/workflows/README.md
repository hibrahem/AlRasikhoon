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

### Job: `distribute-android` — ship a test build to stakeholders

Runs **only on push to `main`**, and **only after `flutter` and `functions`
pass** (`needs: [flutter, functions]`) — a red `main` never ships. Never runs on
pull requests.

Builds a release-signed APK and uploads it to Firebase App Distribution (group
`beta-testers`) so stakeholders can test every change that lands on `main`.
Reuses `scripts/distribute_android.sh` (build + upload) and
`scripts/extract_release_notes.sh` (release notes). Design + rationale:
[`AgDR-0004`](../../docs/agdr/AgDR-0004-android-firebase-distribution.md).

| Step | Notes |
|------|-------|
| Set up JDK 17 | Android Gradle runs on JDK 17 (app source/target stays Java 11). |
| Set up Flutter | Same pinned `FLUTTER_VERSION` as the `flutter` job. |
| Set up Node + Firebase CLI | Node installs `firebase-tools` for the upload. |
| Configure release signing | Decodes `ANDROID_KEYSTORE_BASE64` to `$RUNNER_TEMP` and writes `android/key.properties` pointing at it. |
| Generate release notes | `scripts/extract_release_notes.sh CHANGELOG.md`; **fails if the top section is empty**. |
| Build and distribute APK | `scripts/distribute_android.sh apk` with `BUILD_NUMBER=github.run_number` (unique `versionCode`) and the notes file. |

**Release notes** are the top section of the root `CHANGELOG.md`, written for
stakeholders. Keeping it current is a convention documented in `CLAUDE.md` /
`AGENTS.md`.

## Secrets

The `flutter` and `functions` jobs require no secrets. The `distribute-android`
job requires these repo secrets (Settings → Secrets and variables → Actions);
provision them once:

| Secret | Source |
|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i /path/to/upload.jks` (the whole file, base64-encoded) |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `al_rasikhoon`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `FIREBASE_TOKEN` | `firebase login:ci` (account with Firebase App Distribution Admin on `alrasikhoon-57151`) |

Also ensure the `beta-testers` group exists in Firebase App Distribution.

## Maintenance notes

- **Flutter bump:** edit `FLUTTER_VERSION` in `ci.yml`. Keep it on a stable
  release whose bundled Dart still satisfies `pubspec.yaml`'s SDK constraint
  (Flutter 3.35.0–3.35.2 bundle Dart 3.9.0 and would fail `^3.9.2`).
- **Node bump:** edit `NODE_VERSION` in `ci.yml` to match
  `functions/package.json` → `engines.node` whenever the runtime changes.
