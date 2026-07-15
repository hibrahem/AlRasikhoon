# Android Firebase App Distribution on every `main` push — design

> In the context of stakeholders needing to test the Al-Rasikhoon Android app
> without a local toolchain, facing the absence of any automated distribution,
> I decided to add a gated `distribute-android` job to the existing CI workflow
> that builds a release-signed APK and ships it to Firebase App Distribution on
> every push to `main`, with stakeholder-readable release notes sourced from a
> hand-maintained `CHANGELOG.md`, to get one-click testing for non-technical
> stakeholders, accepting that the changelog must be kept current (enforced as
> an agent/contributor convention) and that five GitHub secrets must be
> provisioned once by a human.

Date: 2026-07-15

## Problem

Stakeholders (non-developers) need to install and test the latest Android build
as soon as work lands on `main`, and they need to understand — in business
terms — what changed. Today:

- There is a working **local** script, [`scripts/distribute_android.sh`](../../../scripts/distribute_android.sh),
  that builds a signed artifact and uploads it to Firebase App Distribution, but
  nothing runs it automatically.
- CI ([`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)) runs on
  push to `main` and on PRs, but only analyzes and tests — it never ships.
- There is no changelog; nothing captures "what changed" in language a
  stakeholder can read.

## Goals

1. On every push to `main`, and **only after tests pass**, build and distribute
   an Android APK to the `beta-testers` group via Firebase App Distribution.
2. Attach release notes written for a business audience (what they can now do),
   not commit messages.
3. Keep those notes accurate over time with the least ongoing effort, by making
   changelog updates a standing convention for every change.

## Non-goals

- iOS distribution (a separate [`scripts/distribute_ios.sh`](../../../scripts/distribute_ios.sh)
  already exists; automating it is out of scope here).
- Google Play / AAB publishing. Stakeholders install the APK directly.
- Auto-generating notes from commits or PRs. Notes are hand-written.
- Creating the Firebase tester group or the service account/keystore — these
  are one-time human setup steps, documented below.

## Decisions (settled during brainstorming)

| Question | Decision |
|---|---|
| Release-notes source | **Hand-written** `CHANGELOG.md`; CI ships the top section verbatim. |
| Artifact | **APK** — direct install, no Google Play linkage needed. |
| Firebase auth | **Firebase CLI token** (`FIREBASE_TOKEN` secret from `firebase login:ci`). |
| Keeping notes current | New agent/contributor **convention** in `CLAUDE.md` + `AGENTS.md`. |

## Design

### 1. Trigger & gating

Add a third job, `distribute-android`, to the existing `ci.yml` (rather than a
separate workflow, to avoid a fragile cross-workflow `workflow_run` trigger and
to reuse the pinned Flutter setup):

```yaml
distribute-android:
  name: Distribute Android (Firebase App Distribution)
  needs: [flutter, functions]
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
```

- `needs: [flutter, functions]` — a build reaches stakeholders only after the
  app tests **and** the functions build are green. A red `main` never ships.
- `if:` guard — never runs on pull requests, only on direct pushes to `main`.

### 2. Reuse the existing distribution script

The job does not duplicate build/upload logic; it calls
`scripts/distribute_android.sh apk`. Two small **backward-compatible** additions
to that script:

- **Optional `BUILD_NUMBER` env** → appended as `--build-number "$BUILD_NUMBER"`
  to the `flutter build` command. CI passes `github.run_number`, giving every
  `main` push a unique, monotonically increasing Android `versionCode`. Without
  this, every build is `versionCode 1` and App Distribution/testers cannot tell
  releases apart. When `BUILD_NUMBER` is unset, the script behaves exactly as
  today (local usage unchanged).
- No other behavioral change. The script already reads `GROUPS`,
  `RELEASE_NOTES_FILE`, and auto-detects `FIREBASE_TOKEN` from the environment
  (firebase-tools reads `FIREBASE_TOKEN` natively).

### 3. Signing in CI

`android/app/build.gradle.kts` already loads release signing from a gitignored
`android/key.properties` and falls back to the debug keystore when absent — a
fallback the code itself marks as **not acceptable for distribution**. So the
job must materialize real signing before building:

1. Decode `ANDROID_KEYSTORE_BASE64` → `android/app/upload-keystore.jks` on the
   runner.
2. Write `android/key.properties` with `storeFile` pointing at that decoded
   file and the password/alias values from secrets.
3. Run the distribution script (which runs `flutter build apk --release`).

No changes to `build.gradle.kts` are required — it already consumes
`key.properties`. The keystore file and `key.properties` live only on the
ephemeral runner and are never committed or logged.

### 4. Release notes from the changelog

- New root `CHANGELOG.md` in "Keep a Changelog" style. The **topmost section**
  holds the notes for the next drop, written in stakeholder language
  ("Students can now resume a session where they left off"), not commit text.
- New `scripts/extract_release_notes.sh`: prints the body between the first
  `## ` heading and the next `## ` heading (or EOF). Heading-name agnostic —
  works whether the top section is labelled `Unreleased` or a version. Exits
  non-zero with a clear message if the changelog or a usable section is missing,
  so a forgotten changelog fails loudly rather than shipping empty notes.
- The CI job runs this script, writes the output to a temp file, and passes it
  via `RELEASE_NOTES_FILE` to the distribution script.

### 5. Keeping the changelog current (the standing convention)

Add a short, explicit section to **both** `CLAUDE.md` and `AGENTS.md` (they
mirror each other in this repo) instructing any agent/contributor: **for every
change that affects what a user can see or do, add a plain-language,
stakeholder-oriented bullet to the top section of `CHANGELOG.md` in the same
change.** Includes a one-line example of business vs. technical phrasing. This
is what keeps hand-written notes from going stale.

### 6. Documentation

- This spec.
- `AgDR-0004` (Agent Decision Record) mirroring the existing
  [AgDR-0001](../../agdr/AgDR-0001-github-actions-ci.md) convention for CI
  decisions.
- Update `.github/workflows/README.md`, which currently states
  *"Secrets: None required"* — no longer true.

## Secrets (one-time human setup — cannot be automated)

Added under GitHub → Settings → Secrets and variables → Actions:

| Secret | Source |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i /path/to/upload.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore store password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `al_rasikhoon`) |
| `ANDROID_KEY_PASSWORD` | key password |
| `FIREBASE_TOKEN` | `firebase login:ci` |

Assumptions to confirm before first run:
- The `beta-testers` group exists in App Distribution for `alrasikhoon-57151`.
- The account behind `FIREBASE_TOKEN` holds **Firebase App Distribution Admin**
  on that project.

## Data flow

```
push to main
  └─ ci.yml: flutter job (analyze + tests)   ┐
     ci.yml: functions job (build + lint)    ┘ both must pass
        └─ distribute-android job
             ├─ decode keystore secret → upload-keystore.jks
             ├─ write android/key.properties
             ├─ extract_release_notes.sh → notes.txt   (from CHANGELOG.md)
             └─ BUILD_NUMBER=run_number GROUPS=beta-testers \
                RELEASE_NOTES_FILE=notes.txt \
                scripts/distribute_android.sh apk
                  ├─ flutter build apk --release --build-number N
                  └─ firebase appdistribution:distribute app-release.apk
                        → beta-testers receive an install link + notes
```

## Error handling

- Missing/empty changelog section → `extract_release_notes.sh` exits non-zero →
  job fails loudly (no silent empty-notes release).
- Missing signing secrets → `key.properties` step fails before an unsigned/
  debug-signed build can be produced.
- Test/functions failure → `needs:` short-circuits; the distribute job never
  starts.

## Testing / verification

- **`extract_release_notes.sh`**: unit-style shell assertions — top section with
  `Unreleased`, top section as a version, missing file, empty section.
- **`distribute_android.sh` `BUILD_NUMBER`**: verify the flag is appended only
  when set; verify existing no-env behavior is unchanged.
- **First real run**: confirm on a `main` push that the APK appears in App
  Distribution with the expected notes and an incremented `versionCode`.

## Alternatives considered

- **Separate `android-distribute.yml` gated via `workflow_run`**: cleaner
  separation, but `workflow_run` runs the default-branch workflow file and
  complicates checkout/ref handling. Rejected for a same-workflow `needs:` job.
- **Auto-generate notes from PRs/commits**: rejected in brainstorming — the ask
  is explicitly business-readable notes, which conventional commits are not.
- **AAB instead of APK**: rejected — App Distribution requires Play linkage for
  AABs; APK installs directly, which is simpler for stakeholders.
