# iOS TestFlight Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On-demand GitHub Actions workflow that ships iOS builds to TestFlight (internal + external testers), and a fast "green-CI" check replacing the slow gate re-runs in both distribution workflows.

**Architecture:** A reusable composite action queries GitHub for the CI conclusion of the exact commit being shipped (~5s) and fails loudly unless green. The new iOS workflow builds on `macos-15` with Xcode **cloud signing** (automatic signing + `-allowProvisioningUpdates`, authenticated by an App Store Connect API key — no certificates in secrets) and uploads via `fastlane pilot`, which sets "What to Test" verbatim from `CHANGELOG.md`'s top section and pushes to the external group.

**Tech Stack:** GitHub Actions (composite action, `workflow_dispatch`), `gh` CLI + `jq`, Flutter 3.35.7, `xcodebuild` cloud signing, fastlane `pilot` (preinstalled on GitHub macOS runners).

**Spec:** `docs/superpowers/specs/2026-07-19-ios-testflight-distribution-design.md`
**Issue tracking:** beads — create/claim an issue for this plan before starting (`bd create --title="Implement iOS TestFlight distribution + green-CI gate" --type=feature --priority=1`), close it when Task 5 is pushed.

## Global Constraints

- `FLUTTER_VERSION: "3.35.7"` in every workflow (keep in sync with `ci.yml`).
- Bundle id `com.alrasikhoon.alRasikhoon`, Apple team `327MX655VL`, Firebase project `alrasikhoon-57151`.
- Quote the workflow trigger key as `"on":` (repo convention — YAML Norway problem, see `ci.yml`).
- Secrets are decoded only into `$RUNNER_TEMP`, never the repo tree.
- Distribution workflows: concurrency group per workflow, `cancel-in-progress: false`.
- No changelog entry for any of this work (internal/CI-only; stakeholders never see it).
- This is CI/config code — no unit-test framework applies. Every task still carries a verify cycle: local lint (`ruby -ryaml`, `plutil -lint`, `bash -n`) and, where possible, executing the same logic locally against the real repo. Final end-to-end verification (Task 6) needs maintainer secrets and runs in GitHub.
- Commit after each task; push at session end (`git pull --rebase && bd dolt push && git push`).

---

### Task 1: Composite action `require-green-ci`

**Files:**
- Create: `.github/actions/require-green-ci/action.yml`

**Interfaces:**
- Produces: composite action referenced as `uses: ./.github/actions/require-green-ci` with one input `force` (string `"true"`/`"false"`, default `"false"`). Tasks 2 and 4 consume it. Requires the calling workflow to grant `permissions: actions: read` and to run after `actions/checkout`.

- [ ] **Step 1: Write the action**

Create `.github/actions/require-green-ci/action.yml`:

```yaml
# Require green CI — Al-Rasikhoon
#
# Fails unless the checked-out commit already has a successful run of the CI
# workflow. Distribution workflows use this instead of re-running the full
# analyze+test gates (~5s instead of ~6-8 min). Rationale: main has no branch
# protection and the distribution `ref` input can target any commit, so
# dropping verification entirely would let a broken commit ship. See
# docs/superpowers/specs/2026-07-19-ios-testflight-distribution-design.md.
#
# Requirements for callers:
#   - runs AFTER actions/checkout (inspects the checked-out HEAD)
#   - workflow grants `permissions: actions: read` (for gh run list)

name: Require green CI
description: Fail unless the checked-out commit has a successful CI run.

inputs:
  force:
    description: "\"true\" skips the check (emergencies only)"
    required: false
    default: "false"

runs:
  using: composite
  steps:
    - name: Check CI conclusion for HEAD
      shell: bash
      env:
        GH_TOKEN: ${{ github.token }}
        GH_REPO: ${{ github.repository }}
        FORCE: ${{ inputs.force }}
      run: |
        set -euo pipefail
        SHA="$(git rev-parse HEAD)"
        if [[ "$FORCE" == "true" ]]; then
          echo "::warning::force=true — skipping the green-CI check for $SHA."
          exit 0
        fi
        runs_json="$(gh run list --commit "$SHA" --workflow CI --json status,conclusion --limit 50)"
        success="$(jq '[.[] | select(.conclusion == "success")] | length' <<<"$runs_json")"
        running="$(jq '[.[] | select(.status != "completed")] | length' <<<"$runs_json")"
        total="$(jq 'length' <<<"$runs_json")"
        if (( success > 0 )); then
          echo "CI is green for $SHA ($success successful run(s) of $total)."
        elif (( running > 0 )); then
          echo "::error::CI is still running for $SHA — retry when it finishes green."
          exit 1
        elif (( total > 0 )); then
          echo "::error::CI is red for $SHA — fix it or pick another commit."
          exit 1
        else
          echo "::error::No CI run found for $SHA — push it through CI first, or re-run with force=true."
          exit 1
        fi
```

- [ ] **Step 2: Lint the YAML**

Run: `ruby -ryaml -e 'YAML.load_file(".github/actions/require-green-ci/action.yml"); puts "yaml ok"'`
Expected: `yaml ok`

- [ ] **Step 3: Execute the check logic locally against real commits**

The step's bash is runnable as-is outside Actions (gh is authenticated locally). Green case — run against a merged main commit:

```bash
cd /Users/hassanibrahim/Documents/Projects/AlRasikhoonProject/al_rasikhoon
SHA="$(git rev-parse origin/main)" FORCE=false bash -c "$(ruby -ryaml -e 'puts YAML.load_file(".github/actions/require-green-ci/action.yml")["runs"]["steps"][0]["run"]' | sed 's/\$(git rev-parse HEAD)/\$SHA/')"
```

Expected: `CI is green for <sha> (...)`, exit 0.

No-run case — use a SHA that never went through CI (any local-only commit, or fabricate by committing a scratch change without pushing):

```bash
SHA="$(git rev-parse HEAD)" FORCE=false bash -c "..."   # same extraction as above
```

Expected (if HEAD is unpushed): `No CI run found for <sha>...`, exit 1.
Force case: rerun with `FORCE=true` → warning line, exit 0.

- [ ] **Step 4: Commit**

```bash
git add .github/actions/require-green-ci/action.yml
git commit -m "ci: add require-green-ci composite action

Verifies the shipped commit has a successful CI run instead of re-running
the full gates in distribution workflows. Spec: 2026-07-19 iOS TestFlight
distribution design."
```

---

### Task 2: Swap gate re-runs for the green-CI check in `distribute-android.yml`

**Files:**
- Modify: `.github/workflows/distribute-android.yml`

**Interfaces:**
- Consumes: `./.github/actions/require-green-ci` (Task 1), input `force`.
- Produces: nothing new; behavior change only.

- [ ] **Step 1: Update the header comment**

Replace lines 11–14 (the "It re-runs the same quality gates…" sentence) so the header reads:

```yaml
# Instead of re-running the CI gates, it verifies the chosen commit already
# has a GREEN CI run (require-green-ci composite action, ~5s) — a broken or
# unvalidated commit still cannot ship, but a validated one ships fast. The
# `force` input skips the check for emergencies. Then it reuses the existing
# scripts/distribute_android.sh (build + upload) and scripts/extract_release_notes.sh
# (stakeholder notes taken verbatim from the top section of CHANGELOG.md).
```

- [ ] **Step 2: Add the `force` input**

After the `test_case_ids` input block, add:

```yaml
      force:
        description: "Skip the green-CI check (emergencies only)"
        required: false
        default: false
        type: boolean
```

- [ ] **Step 3: Grant actions: read**

Replace:

```yaml
permissions:
  contents: read
```

with:

```yaml
permissions:
  contents: read
  actions: read
```

- [ ] **Step 4: Insert the check, remove the gate steps**

Immediately after the `Checkout` step, insert:

```yaml
      # Gate: the shipped commit must already be green in CI (see the header
      # comment). Replaces the former Analyze + test re-run.
      - name: Require green CI for this commit
        uses: ./.github/actions/require-green-ci
        with:
          force: ${{ inputs.force }}
```

Delete these two steps entirely (including their comment lines 110–112):

```yaml
      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Unit, widget and E2E tests
        run: flutter test test/
```

Everything else (JDK, Flutter, Node, Firebase CLI, signing, notes, distribute) stays unchanged.

- [ ] **Step 5: Lint**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/distribute-android.yml"); puts "yaml ok"'`
Expected: `yaml ok`
Also confirm the deleted steps are gone and the new step present:
`grep -n "require-green-ci\|flutter analyze\|flutter test" .github/workflows/distribute-android.yml`
Expected: exactly one match — the `require-green-ci` line.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/distribute-android.yml
git commit -m "ci(android): verify CI is green instead of re-running gates

Distribution runs drop ~6-8 min of analyze+tests; the require-green-ci
check preserves the can't-ship-a-broken-commit invariant at ~5s, with a
force input for emergencies."
```

---

### Task 3: iOS export options + export-compliance flag

**Files:**
- Create: `ios/ExportOptionsAppStore.plist`
- Modify: `ios/Runner/Info.plist` (add one key before the closing `</dict>`)

**Interfaces:**
- Produces: `ios/ExportOptionsAppStore.plist` consumed by Task 4's `xcodebuild -exportArchive` step.

- [ ] **Step 1: Create `ios/ExportOptionsAppStore.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Export options for the TestFlight CI pipeline (distribute-ios.yml):
  `xcodebuild -exportArchive -exportOptionsPlist ios/ExportOptionsAppStore.plist`.

  method "app-store-connect" produces an App Store / TestFlight IPA.
  signingStyle "automatic" + the workflow's -allowProvisioningUpdates and
  App Store Connect API key flags = Xcode cloud signing: certificates and
  profiles are created and managed by Apple, nothing is stored in secrets.

  ExportOptions.plist (ad-hoc / release-testing) remains for local use.
-->
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>327MX655VL</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 2: Add the export-compliance key to `ios/Runner/Info.plist`**

The file currently ends:

```xml
		<key>UIViewControllerBasedStatusBarAppearance</key>
		<false/>
	</dict>
</plist>
```

Change to (app uses only standard HTTPS → exempt; prevents every TestFlight build stalling on "Missing Compliance"):

```xml
		<key>UIViewControllerBasedStatusBarAppearance</key>
		<false/>
		<key>ITSAppUsesNonExemptEncryption</key>
		<false/>
	</dict>
</plist>
```

- [ ] **Step 3: Lint both plists**

Run: `plutil -lint ios/ExportOptionsAppStore.plist ios/Runner/Info.plist`
Expected: both lines end with `OK`

- [ ] **Step 4: Commit**

```bash
git add ios/ExportOptionsAppStore.plist ios/Runner/Info.plist
git commit -m "ios: App Store export options + non-exempt-encryption flag

ExportOptionsAppStore.plist backs the TestFlight CI export (cloud
signing); ITSAppUsesNonExemptEncryption=false stops every build stalling
on TestFlight's export-compliance question (HTTPS-only app)."
```

---

### Task 4: `distribute-ios.yml` workflow

**Files:**
- Create: `.github/workflows/distribute-ios.yml`

**Interfaces:**
- Consumes: `./.github/actions/require-green-ci` (Task 1), `ios/ExportOptionsAppStore.plist` (Task 3), `scripts/extract_release_notes.sh` (existing), secrets `ASC_API_KEY_ID` / `ASC_API_ISSUER_ID` / `ASC_API_KEY_P8_BASE64` (Task 6).

- [ ] **Step 1: Create the workflow**

```yaml
# Distribute iOS — Al-Rasikhoon
#
# Publishes a TestFlight build ON DEMAND, not on every push. A maintainer
# opens the Actions tab, picks this workflow, clicks "Run workflow", and
# chooses which commit becomes the next stakeholder test build — the same
# deliberate "cut a release" button as distribute-android.yml.
#
# Instead of re-running the CI gates, it verifies the chosen commit already
# has a GREEN CI run (require-green-ci composite action, ~5s). The `force`
# input skips the check for emergencies.
#
# Signing is Xcode CLOUD SIGNING: automatic signing + -allowProvisioningUpdates
# authenticated by the App Store Connect API key. Certificates and profiles
# are created and managed by Apple; no .p12 or provisioning profile secrets.
#
# Internal testers get every build within minutes of processing. External
# groups additionally require Apple's Beta App Review on the first build
# (~24-48h) and complete TestFlight Test Information (incl. demo sign-in
# credentials — the app requires login).
#
# Required repo secrets (Settings → Secrets and variables → Actions):
#   ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_P8_BASE64
# See .github/workflows/README.md for how to produce each.
#
# Design: docs/superpowers/specs/2026-07-19-ios-testflight-distribution-design.md

name: Distribute iOS

# Quoted for the YAML-1.1 Norway problem — see ci.yml.
"on":
  workflow_dispatch:
    inputs:
      ref:
        description: "Commit SHA or branch/tag to ship (blank = the ref selected in the UI, normally main)"
        required: false
        type: string
      external_groups:
        description: "TestFlight external tester group(s), comma-separated"
        required: false
        default: "beta-testers"
        type: string
      distribute_external:
        description: "Also distribute to the external group(s); internal testers always receive the build"
        required: false
        default: true
        type: boolean
      force:
        description: "Skip the green-CI check (emergencies only)"
        required: false
        default: false
        type: boolean

# Never run two distributions at once, and never cancel one in flight.
concurrency:
  group: distribute-ios
  cancel-in-progress: false

permissions:
  contents: read
  actions: read

env:
  # Keep in sync with .github/workflows/ci.yml.
  FLUTTER_VERSION: "3.35.7"
  BUNDLE_ID: com.alrasikhoon.alRasikhoon
  TEAM_ID: 327MX655VL

jobs:
  distribute:
    name: Build & upload to TestFlight
    # macOS runner required for xcodebuild; free on public repos.
    runs-on: macos-15
    # Apple-side IPA processing alone can take 10-30 min; leave headroom.
    timeout-minutes: 90

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.ref || github.ref }}

      - name: Require green CI for this commit
        uses: ./.github/actions/require-green-ci
        with:
          force: ${{ inputs.force }}

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Resolve dependencies
        run: flutter pub get

      # Fails loudly if the changelog's top section is missing or empty, so a
      # forgotten changelog blocks the release instead of shipping empty notes.
      - name: Generate stakeholder release notes
        run: scripts/extract_release_notes.sh CHANGELOG.md > "$RUNNER_TEMP/release-notes.txt"

      # Materialize the App Store Connect API key OUTSIDE the repo tree:
      # the raw .p8 for xcodebuild's authentication flags, and the JSON form
      # fastlane pilot expects. GitHub masks registered secrets in logs.
      - name: Write App Store Connect API key
        env:
          ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}
          ASC_API_ISSUER_ID: ${{ secrets.ASC_API_ISSUER_ID }}
          ASC_API_KEY_P8_BASE64: ${{ secrets.ASC_API_KEY_P8_BASE64 }}
        run: |
          set -euo pipefail
          for v in ASC_API_KEY_ID ASC_API_ISSUER_ID ASC_API_KEY_P8_BASE64; do
            if [[ -z "${!v}" ]]; then
              echo "ERROR: $v secret is empty or unset." >&2
              exit 1
            fi
          done
          echo "$ASC_API_KEY_P8_BASE64" | base64 --decode > "$RUNNER_TEMP/asc_key.p8"
          jq -n --arg key_id "$ASC_API_KEY_ID" \
                --arg issuer_id "$ASC_API_ISSUER_ID" \
                --rawfile key "$RUNNER_TEMP/asc_key.p8" \
                '{key_id: $key_id, issuer_id: $issuer_id, key: $key, in_house: false}' \
                > "$RUNNER_TEMP/asc_api_key.json"

      # BUILD_NUMBER=run_number gives every distribution a unique, increasing
      # CFBundleVersion so TestFlight treats each as a new build. Compilation
      # happens here unsigned; signing happens in the archive step below.
      - name: Build Flutter iOS (no codesign)
        run: flutter build ios --release --no-codesign --build-number="${{ github.run_number }}"

      # Cloud signing: -allowProvisioningUpdates + the API key lets xcodebuild
      # register the bundle id and create/manage the distribution certificate
      # and App Store profile headlessly. Auth flags are command-line only —
      # no global signing build settings, so CocoaPods targets are untouched.
      - name: Archive (cloud signing)
        env:
          ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}
          ASC_API_ISSUER_ID: ${{ secrets.ASC_API_ISSUER_ID }}
        run: |
          set -euo pipefail
          xcodebuild -workspace ios/Runner.xcworkspace \
            -scheme Runner \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath "$RUNNER_TEMP/Runner.xcarchive" \
            archive \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$RUNNER_TEMP/asc_key.p8" \
            -authenticationKeyID "$ASC_API_KEY_ID" \
            -authenticationKeyIssuerID "$ASC_API_ISSUER_ID"

      - name: Export IPA
        env:
          ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}
          ASC_API_ISSUER_ID: ${{ secrets.ASC_API_ISSUER_ID }}
        run: |
          set -euo pipefail
          xcodebuild -exportArchive \
            -archivePath "$RUNNER_TEMP/Runner.xcarchive" \
            -exportOptionsPlist ios/ExportOptionsAppStore.plist \
            -exportPath "$RUNNER_TEMP/export" \
            -allowProvisioningUpdates \
            -authenticationKeyPath "$RUNNER_TEMP/asc_key.p8" \
            -authenticationKeyID "$ASC_API_KEY_ID" \
            -authenticationKeyIssuerID "$ASC_API_ISSUER_ID"

      # pilot uploads, waits for Apple's processing, sets "What to Test" from
      # the changelog notes, and (when distribute_external) pushes the build
      # to the external group(s) — triggering Beta App Review when required.
      - name: Upload to TestFlight
        env:
          GROUPS: ${{ inputs.external_groups }}
          DISTRIBUTE_EXTERNAL: ${{ inputs.distribute_external }}
        run: |
          set -euo pipefail
          IPA_PATH="$(ls "$RUNNER_TEMP"/export/*.ipa 2>/dev/null | head -n1 || true)"
          if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
            echo "ERROR: no IPA produced under $RUNNER_TEMP/export/." >&2
            exit 1
          fi
          args=( --api_key_path "$RUNNER_TEMP/asc_api_key.json"
                 --ipa "$IPA_PATH"
                 --changelog "$(cat "$RUNNER_TEMP/release-notes.txt")" )
          if [[ "$DISTRIBUTE_EXTERNAL" == "true" ]]; then
            args+=( --distribute_external true --groups "$GROUPS" )
          fi
          fastlane pilot upload "${args[@]}"
```

- [ ] **Step 2: Lint**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/distribute-ios.yml"); puts "yaml ok"'`
Expected: `yaml ok`

- [ ] **Step 3: Sanity-check the embedded bash blocks**

Extract and `bash -n` each `run:` block:

```bash
ruby -ryaml -e '
  wf = YAML.load_file(".github/workflows/distribute-ios.yml")
  wf["jobs"]["distribute"]["steps"].each do |s|
    next unless s["run"]
    File.write("/tmp/step.sh", s["run"])
    ok = system("bash", "-n", "/tmp/step.sh")
    abort("SYNTAX ERROR in step: #{s["name"]}") unless ok
  end
  puts "all run blocks parse"
'
```

Expected: `all run blocks parse`

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/distribute-ios.yml
git commit -m "ci(ios): on-demand TestFlight distribution workflow

macos-15, green-CI gate, cloud signing via the App Store Connect API key
(no certificate secrets), fastlane pilot upload with What-to-Test taken
verbatim from CHANGELOG.md. Spec: 2026-07-19 design doc."
```

---

### Task 5: Update `.github/workflows/README.md`

**Files:**
- Modify: `.github/workflows/README.md`

**Interfaces:** documentation only.

- [ ] **Step 1: Document the gate change under `## distribute-android.yml`**

Two exact edits in that section:

a) In the inputs table, add after the `test_case_ids` row:

```markdown
| `force` | `false` | Skip the green-CI check (emergencies only). |
```

b) In the step table, replace the row:

```markdown
| Analyze + tests | Re-runs the CI quality gate (`flutter analyze --no-fatal-infos`, `flutter test test/`) against the chosen commit, so a broken ref can never be shipped. |
```

with:

```markdown
| Require green CI | `.github/actions/require-green-ci` (~5s): fails unless the chosen commit already has a successful `CI` run — a broken or unvalidated ref still cannot ship, without re-running the gates. `force: true` skips it. |
```

- [ ] **Step 2: Add a `## distribute-ios.yml` section after the Android one**

```markdown
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
```

- [ ] **Step 3: Add the iOS secrets to the `## Secrets` section**

Append to the secrets documentation:

```markdown
### iOS (TestFlight)

| secret | how to produce it |
| --- | --- |
| `ASC_API_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API → generate key with **App Manager** role; the Key ID shown in the list |
| `ASC_API_ISSUER_ID` | same page — the team-wide Issuer ID above the key list |
| `ASC_API_KEY_P8_BASE64` | download the key's `.p8` (possible **once**), then `base64 -i AuthKey_<KEYID>.p8 \| gh secret set ASC_API_KEY_P8_BASE64` |
```

- [ ] **Step 4: Verify and commit**

Run: `grep -c "distribute-ios" .github/workflows/README.md` — Expected: ≥ 2.

```bash
git add .github/workflows/README.md
git commit -m "docs(ci): document distribute-ios workflow, secrets, and the green-CI gate"
```

---

### Task 6: Maintainer setup + first-run verification (requires the human)

**Files:** none (portal + GitHub settings work). Present this checklist to the maintainer verbatim; the agent cannot perform these steps.

- [ ] **Step 1: Apple portal setup (maintainer)**

1. Confirm the Apple Developer Program membership for team `327MX655VL` is paid/active (developer.apple.com → Membership).
2. App Store Connect → My Apps → **New App**: platform iOS, name (e.g. "Al Rasikhoon — الراسخون"), primary language Arabic, bundle ID `com.alrasikhoon.alRasikhoon` (register it at developer.apple.com → Identifiers first if the dropdown doesn't offer it; enable Push Notifications capability if FCM is used), any unique SKU.
3. Users and Access → Integrations → App Store Connect API → **Generate API Key**, role **App Manager**. Note the Issuer ID and Key ID; download the `.p8` (only possible once).
4. Set the secrets:

```bash
gh secret set ASC_API_KEY_ID --body "<key id>"
gh secret set ASC_API_ISSUER_ID --body "<issuer id>"
base64 -i ~/Downloads/AuthKey_<KEYID>.p8 | gh secret set ASC_API_KEY_P8_BASE64
```

5. TestFlight tab: add yourself + devs as **internal testers**; create external group **beta-testers**; fill **Test Information** — beta description, feedback email, privacy policy URL, and demo sign-in credentials for Apple's reviewers (required: the app has a login wall).

- [ ] **Step 2: First run — internal only**

Actions → **Distribute iOS** → Run workflow on `main` with `distribute_external: false`. Proves: green-CI gate passes, cloud signing creates the cert/profile, build uploads, internal testers get the build. Check TestFlight shows "What to Test" matching `CHANGELOG.md`'s top section verbatim.

- [ ] **Step 3: Second run — external**

Re-run with `distribute_external: true` (default). First external build enters Beta App Review (~24–48h). Confirm the `beta-testers` group receives the invite once approved.

- [ ] **Step 4: Android regression check**

Run **Distribute Android** against green `main` — the green-CI check passes in seconds and the gates are skipped. Optionally dispatch it against an unpushed/unknown SHA to see the "No CI run found" failure message.

- [ ] **Step 5: Close out**

`bd close <issue-id>`, then `git pull --rebase && bd dolt push && git push`.
