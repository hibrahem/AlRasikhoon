#!/usr/bin/env bash
# Deploy the Cloud Functions, then immediately assert every function is
# publicly invocable.
#
# Why this wrapper exists:
#   `firebase deploy --only functions` can report success while a function's
#   backing Cloud Run service is missing the `allUsers` Cloud Run Invoker
#   binding (Firebase only grants it on a clean new-service create, not on a
#   retry of a previously-failed create). That gap silently broke
#   `setUserPassword` for ~14h on 2026-05-10. Pairing every deploy with the
#   IAM audit closes the window: a deploy that leaves a function un-invocable
#   now exits non-zero loudly instead of looking green.
#
# Prerequisites:
#   - `firebase` CLI installed and `firebase login` done with deploy rights
#     on the target project.
#   - `gcloud` CLI installed and authenticated (used by the audit step).
#   - Run from the al_rasikhoon/ project root.
#
# Usage:
#   scripts/deploy_functions.sh
#
# Environment overrides (defaults match the production project):
#   FIREBASE_PROJECT_ID   project to deploy to    (default: alrasikhoon-57151)
#   FUNCTIONS_REGION      region the functions    (default: us-central1)
#                         live in — see functions/src/index.ts `region:`
#
# Exit status:
#   0  deploy succeeded AND every function passed the IAM audit
#   non-zero  deploy failed, OR a function is missing the allUsers binding
#             (run `scripts/audit_functions_iam.sh ... --fix` to print the
#             remediation command)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-alrasikhoon-57151}"
FUNCTIONS_REGION="${FUNCTIONS_REGION:-us-central1}"

echo "==> Deploying functions to project '$FIREBASE_PROJECT_ID'"
firebase deploy --only functions --project "$FIREBASE_PROJECT_ID"

echo
echo "==> Post-deploy IAM audit (asserting allUsers run.invoker on every function)"
"$SCRIPT_DIR/audit_functions_iam.sh" \
  --project "$FIREBASE_PROJECT_ID" \
  --region "$FUNCTIONS_REGION" \
  --fix

echo
echo "==> Deploy + IAM audit complete."
