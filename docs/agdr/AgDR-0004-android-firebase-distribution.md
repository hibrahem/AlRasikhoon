# AgDR-0004 — Android distribution to stakeholders on every `main` push

> In the context of stakeholders needing to test the Al-Rasikhoon Android app
> as soon as work lands, facing no automated distribution (only a local
> `scripts/distribute_android.sh`), I decided to add a gated `distribute-android`
> job to the existing `ci.yml` that builds a release-signed APK and uploads it
> to Firebase App Distribution on every push to `main`, with release notes taken
> verbatim from the top section of a hand-maintained `CHANGELOG.md`, to give
> non-technical stakeholders one-click testing with business-readable notes,
> accepting that the changelog must be kept current (enforced as a documented
> convention) and that five GitHub secrets must be provisioned once by a human.

Refs: spec `docs/superpowers/specs/2026-07-15-android-firebase-distribution-design.md`,
issue al_rasikhoon-ec2. Builds on [AgDR-0001](AgDR-0001-github-actions-ci.md).

## Context

- Stakeholders (non-developers) need the latest Android build to test, and need
  to understand what changed in plain language.
- A working local script (`scripts/distribute_android.sh`) already builds a
  signed artifact and uploads it to Firebase App Distribution
  (project `alrasikhoon-57151`, app `1:276199755113:android:…`, group
  `beta-testers`) — but nothing runs it automatically.
- CI (`.github/workflows/ci.yml`) already runs on push to `main` and on PRs, but
  only analyzes/tests; it never ships. Its README declared "Secrets: None
  required".
- Android release signing is loaded from a gitignored `android/key.properties`;
  `android/app/build.gradle.kts` falls back to the debug keystore when that file
  is absent — a fallback the code itself marks "NOT acceptable for distribution".

## Decision

Add a third CI job, `distribute-android`, gated by `needs: [flutter, functions]`
and `if: github.event_name == 'push' && github.ref == 'refs/heads/main'`. It:

1. Sets up JDK 17, the pinned Flutter, Node, and the Firebase CLI.
2. Reconstructs release signing from GitHub secrets (keystore decoded to
   `$RUNNER_TEMP`, `android/key.properties` written to point at it).
3. Extracts stakeholder notes from `CHANGELOG.md` via
   `scripts/extract_release_notes.sh`.
4. Runs `scripts/distribute_android.sh apk` with `BUILD_NUMBER=github.run_number`
   (unique, increasing `versionCode`), `GROUPS=beta-testers`, and the notes file.

Release notes are **hand-written** in `CHANGELOG.md`; keeping the top section
current is a documented convention in `CLAUDE.md` / `AGENTS.md`.

## Options considered

- **Same-workflow `needs:` job (chosen).** Gates on tests naturally, reuses the
  pinned Flutter setup, no cross-workflow plumbing.
- **Separate `android-distribute.yml` via `workflow_run`.** Cleaner separation,
  but `workflow_run` executes the default-branch workflow file and complicates
  checkout/ref handling. Rejected.
- **Auto-generate notes from commits/PRs.** Rejected — conventional commits are
  not business-readable, which is the explicit requirement.
- **AAB instead of APK.** Rejected — App Distribution requires Google Play
  linkage for AABs; an APK installs directly, simplest for stakeholders.
- **Firebase CLI token vs service account.** Token chosen for lower setup cost;
  it is auto-detected by firebase-tools from `FIREBASE_TOKEN`. Trade-off: tied
  to a personal account and being deprecated by Google — revisit if it breaks.

## Consequences

- Every green `main` push delivers a testable APK to `beta-testers` with
  plain-language notes. A red build never ships (gated by `needs:`).
- **New required secrets** (one-time human setup): `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  `FIREBASE_TOKEN`. The workflows README is updated accordingly.
- **New ongoing discipline:** update `CHANGELOG.md` with each user-facing change;
  the build fails loudly if the top section is empty.
- Prerequisites assumed: the `beta-testers` group exists in App Distribution and
  the `FIREBASE_TOKEN` account holds Firebase App Distribution Admin on
  `alrasikhoon-57151`.
- `scripts/distribute_android.sh` gained an optional `BUILD_NUMBER` env
  (backward-compatible; local runs unchanged).
