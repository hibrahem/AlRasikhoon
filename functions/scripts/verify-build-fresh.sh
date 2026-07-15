#!/usr/bin/env bash
# verify-build-fresh.sh — fail if the compiled functions/lib is stale vs functions/src.
#
# WHY THIS EXISTS
#   `firebase deploy --only functions` ships whatever is sitting in functions/lib
#   on the deploying machine. For ~2 months (2026-05-10..2026-07-14) firebase.json
#   had no predeploy build hook, so every deploy shipped a stale lib built on
#   2026-05-10. Three merged functions/src changes were therefore NEVER live and
#   then all went out at once, unexercised, on 2026-07-14 (see
#   docs/audits/2026-07-15-functions-dormant-deploy-audit.md and issue
#   al_rasikhoon-fh2 / root cause al_rasikhoon-vep).
#
#   The predeploy hook in firebase.json now rebuilds before every deploy, but
#   nothing independently VERIFIES that the compiled artifact matches source.
#   This script is that verification: it rebuilds and asserts the artifact did
#   not change. A non-zero exit means the lib that was about to ship did not
#   match src.
#
# HOW IT WORKS
#   functions/lib is gitignored (functions/.gitignore: "lib/"), so
#   `git diff -- functions/lib` cannot see it. Instead we hash the existing lib,
#   run `npm run build` (tsc), hash the rebuilt lib, and compare.
#     - lib existed and the hash CHANGED  -> STALE  -> exit 1 (the incident case:
#       a deploy machine holding an out-of-date compiled artifact).
#     - lib existed and the hash is IDENTICAL -> FRESH -> exit 0.
#     - lib did NOT exist (e.g. a clean CI checkout) -> we build it and pass:
#       a fresh checkout cannot carry a stale artifact, and this still proves
#       src compiles cleanly.
#
# USAGE
#   functions/scripts/verify-build-fresh.sh            # from anywhere in the repo
#   bash functions/scripts/verify-build-fresh.sh
#
# EXIT STATUS
#   0  lib is fresh (or was absent and has now been built)
#   1  lib was stale — rebuilding changed the compiled output
#   2  environment/build failure (tsc failed, deps missing, etc.)

set -euo pipefail

# Resolve the functions/ package dir relative to this script so the check works
# regardless of the caller's working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$FUNCTIONS_DIR/lib"

cd "$FUNCTIONS_DIR"

# Portable sha256: prefer sha256sum (Linux/CI), fall back to shasum (macOS).
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum
  else
    shasum -a 256
  fi
}

# Deterministic content hash of every compiled artifact under lib/.
# Sorted file list -> per-file hash -> hash of the combined list, so the result
# is stable across runs and machines. *.tsbuildinfo is a build cache, not a
# shipped artifact, so it is excluded.
hash_lib() {
  if [ ! -d "$LIB_DIR" ]; then
    echo "__NO_LIB__"
    return 0
  fi
  # Stream each artifact's path (relative to lib/, for machine independence)
  # followed by its bytes into a single sha256. Piping into the _sha256 shell
  # function is required — `xargs` cannot invoke a shell function.
  (
    cd "$LIB_DIR"
    find . -type f ! -name '*.tsbuildinfo' -print0 \
      | LC_ALL=C sort -z \
      | while IFS= read -r -d '' f; do
          printf '%s\0' "$f"
          cat "$f"
        done
  ) | _sha256 | awk '{print $1}'
}

echo "==> verify-build-fresh: hashing existing functions/lib"
BEFORE="$(hash_lib)"

echo "==> Building (npm run build)"
if ! npm run build >/tmp/verify-build-fresh.log 2>&1; then
  echo "FAIL: npm run build failed. Output:" >&2
  cat /tmp/verify-build-fresh.log >&2
  exit 2
fi

AFTER="$(hash_lib)"

if [ "$AFTER" = "__NO_LIB__" ]; then
  echo "FAIL: build did not produce functions/lib" >&2
  exit 2
fi

if [ "$BEFORE" = "__NO_LIB__" ]; then
  echo "PASS: no pre-existing lib to compare (clean checkout). Built fresh from src."
  echo "      src compiles cleanly; a fresh checkout cannot ship a stale artifact."
  exit 0
fi

if [ "$BEFORE" != "$AFTER" ]; then
  cat >&2 <<'MSG'
FAIL: functions/lib was STALE — rebuilding changed the compiled output.

The lib that was about to deploy did NOT match functions/src. This is exactly
the failure that shipped two months of dormant changes at once (see
docs/audits/2026-07-15-functions-dormant-deploy-audit.md). Re-deploy now that
lib has been rebuilt fresh before shipping.
MSG
  echo "  before: $BEFORE" >&2
  echo "  after:  $AFTER" >&2
  exit 1
fi

echo "PASS: functions/lib is fresh (matches a clean build of functions/src)."
echo "      hash: $AFTER"
exit 0
