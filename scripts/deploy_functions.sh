#!/usr/bin/env bash
# Deploy the Cloud Functions, then immediately assert every function is
# publicly invocable.
#
# Why this wrapper exists:
#   `firebase deploy --only functions` can report success while (a) shipping a
#   STALE compiled functions/lib that no longer matches functions/src, or (b)
#   leaving a function's backing Cloud Run service without the `allUsers` Cloud
#   Run Invoker binding (Firebase only grants it on a clean new-service create,
#   not on a retry of a previously-failed create). Gap (b) silently broke
#   `setUserPassword` for ~14h on 2026-05-10; gap (a) shipped two months of
#   dormant src changes at once on 2026-07-14
#   (docs/audits/2026-07-15-functions-dormant-deploy-audit.md). This wrapper
#   closes all three windows around every deploy:
#
#     1. PRE-deploy build freshness  (al_rasikhoon-x9v) — rebuild and assert the
#        compiled lib matches src, so a stale artifact can never be shipped.
#     2. PRE-deploy build stamp      (al_rasikhoon-5a0) — record HEAD's build
#        identity into the functions' environment (env var BUILD_STAMP) so the
#        running artifact can be identified after deploy.
#     3. POST-deploy IAM audit       — assert allUsers run.invoker on every fn.
#     4. POST-deploy build identity  (al_rasikhoon-5a0) — read BUILD_STAMP back
#        off the LIVE functions and assert it equals HEAD's, proving the deploy
#        actually replaced the running artifact (not a green no-op deploy).
#
# Prerequisites:
#   - `firebase` CLI installed and `firebase login` done with deploy rights
#     on the target project.
#   - `gcloud` CLI installed and authenticated (used by the audit + identity
#     read-back steps).
#   - Run from a checkout of the repo (HEAD is the commit being deployed).
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
#   0  deploy succeeded AND the lib was fresh AND every function passed the IAM
#      audit AND every function is running HEAD's build
#   non-zero  a pre-deploy check failed (stale lib), the deploy failed, a
#             function is missing the allUsers binding, or a function is not
#             running HEAD's build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTIONS_DIR="$(cd "$SCRIPT_DIR/../functions" && pwd)"

FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-alrasikhoon-57151}"
FUNCTIONS_REGION="${FUNCTIONS_REGION:-us-central1}"

# --- 1. Pre-deploy: fail fast if the compiled lib is stale vs src ------------
# Rebuilds functions/lib and asserts it did not change, so a stale artifact can
# never be deployed. Runs BEFORE `firebase deploy` on purpose.
echo "==> Pre-deploy: verifying functions/lib is fresh vs functions/src"
"$FUNCTIONS_DIR/scripts/verify-build-fresh.sh"

# --- 2. Pre-deploy: stamp HEAD's build identity into the functions' env ------
# build-stamp.sh yields "<commit>[-dirty]-<lib-hash>". It is written to
# functions/.env (gitignored) as BUILD_STAMP, which Firebase deploys as an
# environment variable on each Gen2 function's Cloud Run service. Step 4 reads
# it back to confirm the deploy actually shipped this build.
echo
echo "==> Pre-deploy: stamping HEAD's build identity into functions/.env"
BUILD_STAMP="$("$FUNCTIONS_DIR/scripts/build-stamp.sh")"
ENV_FILE="$FUNCTIONS_DIR/.env"
touch "$ENV_FILE"
# Upsert BUILD_STAMP: drop any prior line, then append the current value,
# preserving any other keys already in .env.
_env_tmp="$(mktemp)"
grep -v '^BUILD_STAMP=' "$ENV_FILE" > "$_env_tmp" 2>/dev/null || true
printf 'BUILD_STAMP=%s\n' "$BUILD_STAMP" >> "$_env_tmp"
mv "$_env_tmp" "$ENV_FILE"
echo "    BUILD_STAMP=$BUILD_STAMP"

# --- 3. Deploy ----------------------------------------------------------------
echo
echo "==> Deploying functions to project '$FIREBASE_PROJECT_ID'"
firebase deploy --only functions --project "$FIREBASE_PROJECT_ID"

# --- 4. Post-deploy: assert every function is publicly invocable -------------
echo
echo "==> Post-deploy IAM audit (asserting allUsers run.invoker on every function)"
"$SCRIPT_DIR/audit_functions_iam.sh" \
  --project "$FIREBASE_PROJECT_ID" \
  --region "$FUNCTIONS_REGION" \
  --fix

# --- 5. Post-deploy: assert every function is running HEAD's build -----------
# Reads BUILD_STAMP back off the LIVE functions and compares to the exact value
# stamped in step 2. Catches a green-but-no-op deploy (the fh2 failure mode).
echo
echo "==> Post-deploy build-identity check (asserting live BUILD_STAMP == HEAD)"
"$SCRIPT_DIR/verify_deployed_build.sh" \
  --project "$FIREBASE_PROJECT_ID" \
  --region "$FUNCTIONS_REGION" \
  --expected "$BUILD_STAMP"

echo
echo "==> Deploy + freshness + IAM audit + build-identity checks complete."
