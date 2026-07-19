#!/usr/bin/env bash
# Build a signed Android App Bundle (or APK) and ship it to Firebase App
# Distribution. Run from the al_rasikhoon/ project root.
#
# Prerequisites:
#   - android/key.properties exists (see android/key.properties.example)
#   - `firebase login` has been done with an account that has at least the
#     "Firebase App Distribution Admin" role on alrasikhoon-57151
#   - A tester group exists in App Distribution; default group: "beta-testers"
#
# Usage:
#   scripts/distribute_android.sh            # uploads .aab (recommended)
#   scripts/distribute_android.sh apk        # uploads .apk instead
#   GROUPS="beta-testers,internal" RELEASE_NOTES_FILE=path scripts/distribute_android.sh
#
# Optional env:
#   BUILD_NUMBER  When set, passed to `flutter build` as --build-number, which
#                 overrides the Android versionCode. CI sets this to a unique,
#                 monotonically increasing value (e.g. the workflow run number)
#                 so every distributed build is a distinct release. When unset,
#                 the versionCode from pubspec.yaml is used (unchanged behavior).
#
#   TEST_CASE_IDS      When set (comma-separated ids from apptesting/testcases.yaml),
#                      the release is also run through the Firebase App Testing
#                      agent: the repo's test cases are re-imported (upsert) so
#                      the console copy matches the shipped commit, then the
#                      listed cases execute on real Test Lab devices against
#                      this exact release. The command blocks until the run
#                      finishes and exits non-zero if any test fails.
#   TEST_DEVICES       Device matrix for the agent run (semicolon-separated
#                      specs). Default: one Pixel 9 / Android 16.
#   TEST_USERNAME      Credentials of the dedicated QA account, used by the
#   TEST_PASSWORD      agent for tests that sign in. The password is passed via
#                      a temp file so it never appears in logs or argv.
#   TEST_NON_BLOCKING  When set (any non-empty value), start the agent run and
#                      return immediately; results land in the Firebase console.

set -euo pipefail

APP_ID="1:276199755113:android:4e857305eac385d32781f8"
GROUPS="${GROUPS:-beta-testers}"
ARTIFACT_KIND="${1:-aab}"

# --build-number is appended only when BUILD_NUMBER is a non-empty value, so
# local runs without it keep building exactly as before.
BUILD_ARGS=(--release)
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  BUILD_ARGS+=(--build-number "$BUILD_NUMBER")
fi

if [[ ! -f android/key.properties ]]; then
  echo "ERROR: android/key.properties is missing. Copy android/key.properties.example and fill it in." >&2
  exit 1
fi

case "$ARTIFACT_KIND" in
  aab)
    flutter build appbundle "${BUILD_ARGS[@]}"
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    flutter build apk "${BUILD_ARGS[@]}"
    ARTIFACT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  *)
    echo "ERROR: unknown artifact kind '$ARTIFACT_KIND' (expected 'aab' or 'apk')" >&2
    exit 1
    ;;
esac

if [[ ! -f "$ARTIFACT" ]]; then
  echo "ERROR: expected artifact not found at $ARTIFACT" >&2
  exit 1
fi

NOTES_ARG=()
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  NOTES_ARG+=(--release-notes-file "$RELEASE_NOTES_FILE")
elif [[ -n "${RELEASE_NOTES:-}" ]]; then
  NOTES_ARG+=(--release-notes "$RELEASE_NOTES")
fi

# Firebase App Testing agent: activated only when TEST_CASE_IDS is set, so
# plain local distributions behave exactly as before.
TEST_ARGS=()
if [[ -n "${TEST_CASE_IDS:-}" ]]; then
  # Keep the console's Test Cases in lockstep with the repo before running
  # them (import is an upsert keyed on each case's id).
  if [[ -f apptesting/testcases.yaml ]]; then
    firebase appdistribution:testcases:import apptesting/testcases.yaml --app "$APP_ID"
  fi

  TEST_ARGS+=(
    --test-case-ids "$TEST_CASE_IDS"
    --test-devices "${TEST_DEVICES:-model=tokay,version=36,locale=en,orientation=portrait}"
  )
  if [[ -n "${TEST_USERNAME:-}" ]]; then
    TEST_ARGS+=(--test-username "$TEST_USERNAME")
  fi
  if [[ -n "${TEST_PASSWORD:-}" ]]; then
    TEST_PASSWORD_FILE="$(mktemp)"
    trap 'rm -f "$TEST_PASSWORD_FILE"' EXIT
    printf '%s' "$TEST_PASSWORD" > "$TEST_PASSWORD_FILE"
    TEST_ARGS+=(--test-password-file "$TEST_PASSWORD_FILE")
  fi
  if [[ -n "${TEST_NON_BLOCKING:-}" ]]; then
    TEST_ARGS+=(--test-non-blocking)
  fi
fi

firebase appdistribution:distribute "$ARTIFACT" \
  --app "$APP_ID" \
  --groups "$GROUPS" \
  "${NOTES_ARG[@]}" \
  "${TEST_ARGS[@]}"
