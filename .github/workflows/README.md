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

## `functions-iam-audit.yml`

**Triggers:** daily at 06:00 UTC, plus manual `workflow_dispatch`.

Runs `scripts/audit_functions_iam.sh` against production to assert every Gen2
Cloud Function's backing Cloud Run service still has the `allUsers` →
`roles/run.invoker` binding (the drift that silently broke `setUserPassword`
on 2026-05-10). On a genuine finding it opens/updates a tracking issue
labelled `functions-iam-audit`.

**Configuration:** three repository *variables* (Settings → Secrets and
variables → Actions → Variables) — `GCP_PROJECT_ID`, `GCP_WIF_PROVIDER`, and
`GCP_WIF_SERVICE_ACCOUNT` (a read-only service account:
`roles/cloudfunctions.viewer` + `roles/run.viewer` only). Until all three are
set, the job skips the audit with a warning annotation instead of failing —
see the header comment in the workflow file for details.

## Secrets

None required. `ci.yml` does no deploy, signing, or emulator work — those
live under `scripts/` and are out of scope for issue #6.
`functions-iam-audit.yml` authenticates via Workload Identity Federation
(OIDC), so it needs the repository variables above but no long-lived secret.

## Maintenance notes

- **Flutter bump:** edit `FLUTTER_VERSION` in `ci.yml`. Keep it on a stable
  release whose bundled Dart still satisfies `pubspec.yaml`'s SDK constraint
  (Flutter 3.35.0–3.35.2 bundle Dart 3.9.0 and would fail `^3.9.2`).
- **Node bump:** edit `NODE_VERSION` in `ci.yml` to match
  `functions/package.json` → `engines.node` whenever the runtime changes.
