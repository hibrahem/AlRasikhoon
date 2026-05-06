#!/usr/bin/env bash
# Build a signed iOS IPA and ship it to Firebase App Distribution.
# Run from the al_rasikhoon/ project root.
#
# Prerequisites:
#   - Apple Developer account is set up in Xcode and logged in
#   - The Apple Developer team owns ad-hoc / development provisioning profiles
#     covering the testers' device UDIDs
#   - `firebase login` has been done with an account that has the
#     "Firebase App Distribution Admin" role on alrasikhoon-57151
#   - A tester group exists in App Distribution; default group: "beta-testers"
#
# Usage:
#   scripts/distribute_ios.sh
#   GROUPS="beta-testers,internal" RELEASE_NOTES_FILE=path scripts/distribute_ios.sh

set -euo pipefail

APP_ID="1:276199755113:ios:7d12088a1d5663e22781f8"
GROUPS="${GROUPS:-beta-testers}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-ios/ExportOptions.plist}"

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "ERROR: $EXPORT_OPTIONS missing." >&2
  exit 1
fi

# `flutter build ipa` runs `xcodebuild -exportArchive` under the hood using the
# given export options plist. The IPA lands at build/ios/ipa/<app-name>.ipa.
flutter build ipa --release --export-options-plist="$EXPORT_OPTIONS"

IPA_PATH="$(ls build/ios/ipa/*.ipa 2>/dev/null | head -n1 || true)"
if [[ -z "$IPA_PATH" || ! -f "$IPA_PATH" ]]; then
  echo "ERROR: no IPA produced under build/ios/ipa/." >&2
  exit 1
fi

NOTES_ARG=()
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  NOTES_ARG+=(--release-notes-file "$RELEASE_NOTES_FILE")
elif [[ -n "${RELEASE_NOTES:-}" ]]; then
  NOTES_ARG+=(--release-notes "$RELEASE_NOTES")
fi

firebase appdistribution:distribute "$IPA_PATH" \
  --app "$APP_ID" \
  --groups "$GROUPS" \
  "${NOTES_ARG[@]}"
