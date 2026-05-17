#!/usr/bin/env bash
# Audit that every Gen2 Cloud Function is publicly invocable.
#
# Why this exists:
#   On 2026-05-10 `setUserPassword` was silently broken for ~14h because its
#   underlying Cloud Run service was missing the `allUsers` Cloud Run Invoker
#   binding. Firebase only grants that binding on a *clean* new-service create
#   — a retry of a previously-failed create does NOT re-grant it, so the
#   function deploys "successfully" while every client call gets a 403. This
#   script asserts the binding is present so that gap is caught fast (in CI
#   daily, and immediately after every deploy via scripts/deploy_functions.sh).
#
# What it checks:
#   For every Gen2 function (`gcloud functions list --v2`) it inspects the
#   backing Cloud Run service's IAM policy (`gcloud run services
#   get-iam-policy`) and asserts that member `allUsers` holds role
#   `roles/run.invoker`.
#
# Prerequisites:
#   - `gcloud` CLI installed and authenticated with at least
#     roles/cloudfunctions.viewer + roles/run.viewer on the target project
#     (read-only; --fix only PRINTS the remediation command, never runs it).
#   - The target GCP project + region.
#
# Usage:
#   scripts/audit_functions_iam.sh --project PROJECT_ID --region REGION
#   scripts/audit_functions_iam.sh PROJECT_ID REGION          # positional
#   scripts/audit_functions_iam.sh -p PROJECT_ID -r REGION --fix
#   scripts/audit_functions_iam.sh -h
#
# Flags:
#   -p, --project PROJECT_ID   GCP / Firebase project ID (required)
#   -r, --region  REGION       Cloud Functions region   (required)
#       --fix                  On failures, PRINT (do NOT run) the
#                              `gcloud run services add-iam-policy-binding`
#                              command that would remediate each one.
#   -h, --help                 Show this help and exit.
#
# Exit status:
#   0  every function has the allUsers run.invoker binding
#   1  at least one function is missing it (or no functions found)
#   2  bad usage / missing dependency
#
# Examples:
#   # Audit production (alrasikhoon-57151 functions live in us-central1):
#   scripts/audit_functions_iam.sh --project alrasikhoon-57151 --region us-central1
#
#   # Show how to fix any failures (does not execute the fix):
#   scripts/audit_functions_iam.sh -p alrasikhoon-57151 -r us-central1 --fix

set -euo pipefail

PROGNAME="$(basename "$0")"

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
FIX=0

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
    --fix)
      FIX=1
      shift
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

echo "Auditing Gen2 Cloud Functions IAM for project '$PROJECT' region '$REGION'"
echo "Assertion: member 'allUsers' must hold role 'roles/run.invoker' on each function's Cloud Run service."
echo

# --- Enumerate Gen2 functions ------------------------------------------------
# `gcloud functions list --v2` lists Gen2 functions. We filter to the target
# region and extract bare function names. --format keeps parsing robust across
# gcloud versions (no header / table-layout assumptions).
FUNCTIONS_RAW="$(
  gcloud functions list \
    --v2 \
    --project="$PROJECT" \
    --regions="$REGION" \
    --format="value(name)" 2>/dev/null || true
)"

if [[ -z "${FUNCTIONS_RAW// }" ]]; then
  echo "FAIL: no Gen2 functions found in project '$PROJECT' region '$REGION'." >&2
  echo "      (Empty result also fails — an audit that finds nothing to check" >&2
  echo "       is treated as a misconfiguration, not a pass.)" >&2
  exit 1
fi

# Normalise: gcloud may return a fully-qualified resource path
# (projects/.../locations/.../functions/NAME) or a bare NAME depending on
# version. Reduce to the trailing segment either way.
FUNCTION_NAMES=()
while IFS= read -r line; do
  [[ -z "${line// }" ]] && continue
  FUNCTION_NAMES+=("${line##*/}")
done <<< "$FUNCTIONS_RAW"

PASS_COUNT=0
FAIL_COUNT=0
FAILED_FUNCTIONS=()

for fn in "${FUNCTION_NAMES[@]}"; do
  # The Gen2 function's backing Cloud Run service shares its name.
  policy="$(
    gcloud run services get-iam-policy "$fn" \
      --project="$PROJECT" \
      --region="$REGION" \
      --format="value(bindings.members.list(separator=','))" \
      --filter="bindings.role:roles/run.invoker" 2>/dev/null || true
  )"

  if echo "$policy" | grep -qw "allUsers"; then
    printf 'PASS  %s\n' "$fn"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    printf 'FAIL  %s  (allUsers missing from roles/run.invoker)\n' "$fn"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_FUNCTIONS+=("$fn")
  fi
done

echo
echo "Summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed, $(( PASS_COUNT + FAIL_COUNT )) total."

if [[ $FAIL_COUNT -gt 0 ]]; then
  if [[ $FIX -eq 1 ]]; then
    echo
    echo "--- Remediation (NOT executed — copy/run manually after review) ---"
    for fn in "${FAILED_FUNCTIONS[@]}"; do
      echo "gcloud run services add-iam-policy-binding ${fn} \\"
      echo "  --project=${PROJECT} \\"
      echo "  --region=${REGION} \\"
      echo "  --member=allUsers \\"
      echo "  --role=roles/run.invoker"
    done
    echo "-------------------------------------------------------------------"
  else
    echo "Re-run with --fix to print the remediation command(s)." >&2
  fi
  exit 1
fi

echo "OK: all functions are publicly invocable."
exit 0
