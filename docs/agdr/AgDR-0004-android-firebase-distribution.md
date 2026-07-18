# AgDR-0004 — On-demand Android distribution to stakeholders

> In the context of stakeholders needing to test the Al-Rasikhoon Android app
> without a local toolchain, facing no automated distribution (only a local
> `scripts/distribute_android.sh`), I decided to add a standalone
> `distribute-android.yml` workflow triggered **manually** (`workflow_dispatch`)
> that re-runs the CI quality gate against a chosen commit, then builds a
> release-signed APK and uploads it to Firebase App Distribution, with release
> notes taken verbatim from the top section of a hand-maintained `CHANGELOG.md`,
> to give the team a deliberate "cut a stakeholder build" button (rather than one
> build per merge), accepting that the changelog must be kept current (enforced
> as a documented convention) and that five GitHub secrets must be provisioned
> once by a human.

Refs: spec `docs/superpowers/specs/2026-07-15-android-firebase-distribution-design.md`,
issue al_rasikhoon-ec2. Builds on [AgDR-0001](AgDR-0001-github-actions-ci.md).

## Context

- Stakeholders (non-developers) need a testable Android build and need to
  understand what changed in plain language.
- A working local script (`scripts/distribute_android.sh`) already builds a
  signed artifact and uploads it to Firebase App Distribution
  (project `alrasikhoon-57151`, app `1:276199755113:android:…`, group
  `beta-testers`) — but nothing runs it automatically.
- CI (`.github/workflows/ci.yml`) already runs on push to `main` and on PRs, but
  only analyzes/tests; it never ships.
- Android release signing is loaded from a gitignored `android/key.properties`;
  `android/app/build.gradle.kts` falls back to the debug keystore when that file
  is absent — a fallback the code itself marks "NOT acceptable for distribution".
- **Control matters:** the team wants to pick *which* state of `main` becomes the
  next stakeholder version, not ship every merge automatically.

## Decision

Add a standalone workflow `.github/workflows/distribute-android.yml` triggered
**only** by `workflow_dispatch` (a "Run workflow" button in the Actions tab),
with two optional inputs: `ref` (a specific commit/branch/tag to ship; defaults
to the ref chosen in the UI) and `groups` (tester group(s); defaults to
`beta-testers`). The single job:

1. Checks out `inputs.ref` (or the dispatched ref).
2. Sets up JDK 17 and the pinned Flutter, then **re-runs the CI quality gate**
   (`flutter analyze --no-fatal-infos`, `flutter test test/`) so a broken commit
   can never be shipped even when an operator targets an arbitrary ref.
3. Sets up Node + the Firebase CLI.
4. Reconstructs release signing from GitHub secrets (keystore decoded to
   `$RUNNER_TEMP`, `android/key.properties` written to point at it).
5. Extracts stakeholder notes from `CHANGELOG.md` via
   `scripts/extract_release_notes.sh`.
6. Runs `scripts/distribute_android.sh apk` with `BUILD_NUMBER=github.run_number`
   (unique, increasing `versionCode`), `GROUPS=<input>`, and the notes file.

Release notes are **hand-written** in `CHANGELOG.md`; keeping the top section
current is a documented convention in `CLAUDE.md` / `AGENTS.md`.

## Options considered

- **Automatic on every `main` push (rejected).** Simplest to wire (a gated job
  in `ci.yml`), but ships a build per merge — the team wants to choose which
  merge becomes a stakeholder version. Control won over automation.
- **Standalone `workflow_dispatch` workflow (chosen).** A native "Run workflow"
  button; the operator picks the commit and tester group. Re-runs the quality
  gate itself since it no longer rides on a push-triggered CI run.
- **Git-tag trigger.** Version-semantic and leaves a git marker, but releases
  from the terminal rather than a button. Rejected in favor of the UI button
  (revisit if formal version tagging becomes desirable).
- **Auto-generate notes from commits/PRs.** Rejected — conventional commits are
  not business-readable, which is the explicit requirement.
- **AAB instead of APK.** Rejected — App Distribution requires Google Play
  linkage for AABs; an APK installs directly, simplest for stakeholders.
- **Firebase CLI token vs service account.** Token chosen for lower setup cost;
  it is auto-detected by firebase-tools from `FIREBASE_TOKEN`. Trade-off: tied
  to a personal account and being deprecated by Google — revisit if it breaks.

## Consequences

- Distribution is a **deliberate action**: a maintainer clicks "Run workflow"
  to ship the chosen commit to `beta-testers` with plain-language notes. No
  build reaches stakeholders without an explicit click.
- The chosen commit is proven green (analyze + tests) before it ships, so the
  "never ship a red build" guarantee survives the move to manual triggering.
- `ci.yml` returns to two jobs (`flutter`, `functions`) with no secrets.
- **New required secrets** (one-time human setup): `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  `FIREBASE_TOKEN`. The workflows README documents how to produce each.
- **New ongoing discipline:** update `CHANGELOG.md` with each user-facing change;
  a distribution run fails loudly if the top section is empty.
- Prerequisites (verified 2026-07-15): the `beta-testers` group exists in App
  Distribution for `alrasikhoon-57151` (1 tester, 1 prior release), and the
  account `eng.hibrahem@gmail.com` holds `roles/owner` (a superset of Firebase
  App Distribution Admin). The `FIREBASE_TOKEN` must be generated from that same
  account.
- `scripts/distribute_android.sh` gained an optional `BUILD_NUMBER` env
  (backward-compatible; local runs unchanged).
