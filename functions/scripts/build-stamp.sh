#!/usr/bin/env bash
# build-stamp.sh — print a canonical, deployable build-identity stamp for the
# Cloud Functions package: the git commit the artifact was built from, joined
# with a content hash of the compiled functions/lib.
#
# WHY THIS EXISTS (issue al_rasikhoon-5a0, follow-up to al_rasikhoon-fh2)
#   verify-build-fresh.sh proves the LOCAL functions/lib matches functions/src.
#   It does NOT prove that the artifact actually RUNNING in the cloud is the one
#   built from HEAD. A `firebase deploy` can report success without the running
#   service changing — that is exactly the fh2 failure mode: a green deploy on
#   top of a stale artifact (see
#   docs/audits/2026-07-15-functions-dormant-deploy-audit.md).
#
#   To close that gap, the deploy path stamps THIS value into the deployed
#   function's environment (env var BUILD_STAMP) and reads it back afterwards
#   (scripts/verify_deployed_build.sh). If the read-back stamp does not equal
#   this value, the running functions are not the build from HEAD.
#
# STAMP FORMAT
#   <commit-sha>[-dirty]-<lib-hash>
#     commit-sha : `git rev-parse HEAD` (the commit being deployed)
#     -dirty     : appended when the working tree has uncommitted changes to
#                  tracked files (gitignored files such as .env and lib/ are
#                  NOT counted), so a stamp built off an unclean tree is visible
#     lib-hash   : deterministic sha256 of functions/lib (see lib-hash.sh) — ties
#                  the identity to the actual compiled bytes, not just the commit
#
# USAGE
#   functions/scripts/build-stamp.sh          # prints the stamp to stdout
#
# NOTE
#   Hashing requires functions/lib to exist, so build first (the deploy path
#   runs verify-build-fresh.sh, which builds, immediately before this).
#
# EXIT STATUS
#   0  printed a stamp
#   2  not inside a git work tree, or functions/lib is absent (nothing to stamp)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib-hash.sh
. "$SCRIPT_DIR/lib-hash.sh"

if ! git -C "$FUNCTIONS_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: build-stamp: not inside a git work tree (cannot read HEAD)" >&2
  exit 2
fi

COMMIT="$(git -C "$FUNCTIONS_DIR" rev-parse HEAD)"

# Mark the stamp if the tree carries uncommitted tracked changes. gitignored
# files (.env, lib/, node_modules/) never show up here, so a clean deploy is
# reported clean.
DIRTY=""
if [ -n "$(git -C "$FUNCTIONS_DIR" status --porcelain)" ]; then
  DIRTY="-dirty"
fi

LIB_HASH="$(hash_lib)"
if [ "$LIB_HASH" = "__NO_LIB__" ]; then
  echo "ERROR: build-stamp: functions/lib is absent — build before stamping" >&2
  exit 2
fi

printf '%s%s-%s\n' "$COMMIT" "$DIRTY" "$LIB_HASH"
