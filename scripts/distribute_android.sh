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

firebase appdistribution:distribute "$ARTIFACT" \
  --app "$APP_ID" \
  --groups "$GROUPS" \
  "${NOTES_ARG[@]}"
