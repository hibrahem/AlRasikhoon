#!/usr/bin/env bash
# Verify that the DEPLOYED Cloud Functions are the build from HEAD.
#
# Why this exists (issue al_rasikhoon-5a0, follow-up to al_rasikhoon-fh2):
#   verify-build-fresh.sh proves the LOCAL functions/lib matches functions/src,
#   and the deploy path stamps HEAD's build identity into every function's
#   environment (env var BUILD_STAMP) at deploy time. But `firebase deploy` can
#   report success without the running service actually changing — the exact
#   fh2 failure mode: a green deploy sitting on a stale artifact. Nothing so far
#   inspects what is ACTUALLY running.
#
#   This is that inspection: for every deployed Gen2 function it reads the
#   BUILD_STAMP back off the live Cloud Run service and asserts it equals the
#   expected stamp (HEAD's, computed by functions/scripts/build-stamp.sh). A
#   mismatch means the running function is NOT the build we just shipped:
#     - stale/old stamp  -> the deploy did not replace the running artifact
#     - empty/missing    -> the function predates this mechanism, or the deploy
#                           did not carry the stamp env var
#   It complements (does not duplicate) scripts/audit_functions_iam.sh: that
#   audits reachability (allUsers run.invoker); this audits identity (is the
#   code that answers actually HEAD's build).
#
# Prerequisites:
#   - `gcloud` CLI installed and authenticated with at least
#     roles/cloudfunctions.viewer + roles/run.viewer on the target project
#     (read-only; this script never mutates anything).
#   - Run from a checkout of the repo that was deployed (needed to compute the
#     expected stamp when --expected is not passed).
#
# Usage:
#   scripts/verify_deployed_build.sh --project PROJECT_ID --region REGION
#   scripts/verify_deployed_build.sh PROJECT_ID REGION                 # positional
#   scripts/verify_deployed_build.sh -p PROJECT_ID -r REGION --expected STAMP
#   scripts/verify_deployed_build.sh -h
#
# Flags:
#   -p, --project PROJECT_ID   GCP / Firebase project ID (required)
#   -r, --region  REGION       Cloud Functions region   (required)
#       --expected STAMP       Expected BUILD_STAMP. Defaults to the output of
#                              functions/scripts/build-stamp.sh (HEAD's stamp).
#                              deploy_functions.sh passes the exact value it
#                              stamped so the check never re-derives it.
#   -h, --help                 Show this help and exit.
#
# Exit status:
#   0  every deployed function reports the expected BUILD_STAMP
#   1  at least one function's stamp is stale/missing (or no functions found)
#   2  bad usage / missing dependency / could not compute expected stamp
#
# NOTE — only fully exercisable during a real deploy:
#   The read-back uses live `gcloud` credentials against deployed services, so
#   the end-to-end check runs in the real deploy path (scripts/deploy_functions.sh)
#   or against an already-deployed project. Argument parsing and the
#   expected-stamp computation are exercisable offline; the gcloud read-back is
#   not, by design.

set -euo pipefail

PROGNAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_STAMP_SCRIPT="$SCRIPT_DIR/../functions/scripts/build-stamp.sh"

usage() {
  # Print the leading comment block (between the shebang and the
  # `set -euo pipefail` line) as the help text, stripping the `# ` prefix.
  sed -n '2,/^set -euo pipefail$/p' "$0" | sed 's/^# \{0,1\}//; /^set -euo pipefail$/d'
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

PROJECT=""
REGION=""
EXPECTED=""

# --- Argument parsing: supports flags AND two positional args -----------------
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      [[ $# -ge 2 ]] || die "$1 requires a value"
      PROJECT="$2"
      shift 2
      ;;
    -r|--region)
      [[ $# -ge 2 ]] || die "$1 requires a value"
      REGION="$2"
      shift 2
      ;;
    --expected)
      [[ $# -ge 2 ]] || die "$1 requires a value"
      EXPECTED="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      die "unknown option '$1' (run '$PROGNAME -h' for usage)"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Fill unset values from positionals: <project> <region>
if [[ -z "$PROJECT" && ${#POSITIONAL[@]} -ge 1 ]]; then
  PROJECT="${POSITIONAL[0]}"
fi
if [[ -z "$REGION" && ${#POSITIONAL[@]} -ge 2 ]]; then
  REGION="${POSITIONAL[1]}"
fi

[[ -n "$PROJECT" ]] || die "missing --project (run '$PROGNAME -h' for usage)"
[[ -n "$REGION" ]]  || die "missing --region (run '$PROGNAME -h' for usage)"

command -v gcloud >/dev/null 2>&1 || die "gcloud CLI not found on PATH"

# Compute the expected stamp from HEAD if the caller did not pass one.
if [[ -z "$EXPECTED" ]]; then
  [[ -x "$BUILD_STAMP_SCRIPT" ]] || die "cannot find build-stamp.sh at $BUILD_STAMP_SCRIPT"
  EXPECTED="$("$BUILD_STAMP_SCRIPT")" \
    || die "could not compute expected build stamp (is functions/lib built?)"
fi

echo "Verifying deployed build identity for project '$PROJECT' region '$REGION'"
echo "Assertion: every function's BUILD_STAMP env var must equal HEAD's stamp."
echo "  expected: $EXPECTED"
echo

# --- Enumerate Gen2 functions ------------------------------------------------
# Same enumeration as scripts/audit_functions_iam.sh so the two post-deploy
# checks cover the identical set of functions.
FUNCTIONS_RAW="$(
  gcloud functions list \
    --v2 \
    --project="$PROJECT" \
    --regions="$REGION" \
    --format="value(name)" 2>/dev/null || true
)"

if [[ -z "${FUNCTIONS_RAW// }" ]]; then
  echo "FAIL: no Gen2 functions found in project '$PROJECT' region '$REGION'." >&2
  echo "      (Empty result also fails — a verification that finds nothing to" >&2
  echo "       check is treated as a misconfiguration, not a pass.)" >&2
  exit 1
fi

# Normalise to bare function names (gcloud may return a fully-qualified path).
FUNCTION_NAMES=()
while IFS= read -r line; do
  [[ -z "${line// }" ]] && continue
  FUNCTION_NAMES+=("${line##*/}")
done <<< "$FUNCTIONS_RAW"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_FUNCTIONS=()

for fn in "${FUNCTION_NAMES[@]}"; do
  # Read the BUILD_STAMP env var off the deployed Gen2 function's Cloud Run
  # service config.
  deployed="$(
    gcloud functions describe "$fn" \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --format="value(serviceConfig.environmentVariables.BUILD_STAMP)" 2>/dev/null || true
  )"

  if [[ -z "${deployed// }" ]]; then
    printf 'FAIL  %s  (no BUILD_STAMP on the deployed function)\n' "$fn"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_FUNCTIONS+=("$fn (missing)")
  elif [[ "$deployed" == "$EXPECTED" ]]; then
    printf 'PASS  %s\n' "$fn"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  %s  (deployed stamp %s != expected)\n' "$fn" "$deployed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_FUNCTIONS+=("$fn ($deployed)")
  fi
done

echo
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed, $(( PASS_COUNT + FAIL_COUNT )) total."

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo >&2
  echo "One or more deployed functions are NOT the build from HEAD:" >&2
  for entry in "${FAILED_FUNCTIONS[@]}"; do
    echo "  - $entry" >&2
  done
  echo >&2
  echo "A stale or missing stamp means 'firebase deploy' reported success but the" >&2
  echo "running artifact was not replaced with HEAD's build. Re-deploy from HEAD" >&2
  echo "(scripts/deploy_functions.sh) and investigate why the deploy was a no-op." >&2
  exit 1
fi

echo "OK: every deployed function is running HEAD's build."
exit 0
