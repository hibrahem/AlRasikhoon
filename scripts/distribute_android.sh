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

set -euo pipefail

APP_ID="1:276199755113:android:4e857305eac385d32781f8"
GROUPS="${GROUPS:-beta-testers}"
ARTIFACT_KIND="${1:-aab}"

if [[ ! -f android/key.properties ]]; then
  echo "ERROR: android/key.properties is missing. Copy android/key.properties.example and fill it in." >&2
  exit 1
fi

case "$ARTIFACT_KIND" in
  aab)
    flutter build appbundle --release
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    flutter build apk --release
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
