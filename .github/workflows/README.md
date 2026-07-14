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
| Unit tests | `flutter test test/` | **Unit suite only.** The integration suite needs a booted device, so it runs in the `integration` job below. |

### Job: `integration` — integration suite on an iOS simulator

Runs on `macos-15`, because `flutter test integration_test/` requires a real device
and the Android emulator hangs on this suite (`al_rasikhoon-1fg`).

| Step | Command | Notes |
|------|---------|-------|
| Boot iOS simulator | `xcrun simctl boot` + `bootstatus -b` | `simctl boot` returns immediately; `bootstatus` waits for a *fully* booted device. `flutter test -d` against a half-booted simulator fails in ways that look like test failures. |
| Integration tests | `flutter test integration_test/app_test.dart -d $SIM_UDID` | **One** invocation, via the aggregate entry point that runs all five E2E suites in a single binary. Do **not** loop over `integration_test/*_test.dart`: each invocation drives a fresh Xcode build (37 min vs 3) and they collide on the shared DerivedData `build.db` — *"Xcode build failed too many times due to concurrent builds"*. `firebase_emulator_flow_test.dart` is excluded on purpose: it needs a real `firebase emulators:start`, which this job does not run. |

This job closes **issue #5**. It exists because CI previously ran analyze + unit tests
only, and nothing ran the integration suite — so it rotted unnoticed while two PRs merged
green over six red integration tests (`al_rasikhoon-8oh`). Both breakages were real product
changes the tests had not been told about, and no unit test could have caught either.
macOS runners bill at a premium; that is the honest price of gating on this.

### Job: `functions` — build + lint

Runs with working directory `functions/`.

| Step | Command | Notes |
|------|---------|-------|
| Set up Node.js | `actions/setup-node@v4` | Version from the single `NODE_VERSION` env constant in `ci.yml`, which mirrors `functions/package.json` → `engines.node` (`22`). Change that one constant on a runtime bump. |
| Install deps | `npm install` | Not `npm ci`: `functions/package-lock.json` is intentionally gitignored, so there is no committed lockfile to install from. See the AgDR tradeoffs section. |
| Build | `npm run build` | `tsc` per `functions/package.json`. |
| Lint | `npm run lint --if-present` | Runs `eslint --ext .ts src/`; `--if-present` makes it a no-op if the script is ever removed. |

## Secrets

None required. This pipeline does no deploy, signing, or emulator work — those
live under `scripts/` and are out of scope for issue #6.

## Maintenance notes

- **Flutter bump:** edit `FLUTTER_VERSION` in `ci.yml`. Keep it on a stable
  release whose bundled Dart still satisfies `pubspec.yaml`'s SDK constraint
  (Flutter 3.35.0–3.35.2 bundle Dart 3.9.0 and would fail `^3.9.2`).
- **Node bump:** edit `NODE_VERSION` in `ci.yml` to match
  `functions/package.json` → `engines.node` whenever the runtime changes.
