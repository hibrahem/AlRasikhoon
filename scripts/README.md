# Bootstrap & maintenance scripts

These scripts use the Firebase Admin SDK against a service-account credential.
Both expect `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID` in the
environment. Get a service-account key from
**Firebase Console → Project Settings → Service accounts → Generate new private
key** (do NOT commit it).

```bash
cd scripts
npm install
```

## Seed the first super-admin (bootstrap a fresh project)

After deploying the rules + functions to a fresh project, the `users`
collection is empty and nobody can sign in via the app. Run:

```bash
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-57151 \
SUPER_ADMIN_USERNAME=admin \
SUPER_ADMIN_PASSWORD='admin123' \
SUPER_ADMIN_NAME='مدير النظام' \
npm run seed-super-admin
```

The super-admin can then sign in via the login screen with the given
username and password, and create teachers from the admin panel.

## Wipe users (destructive)

Clears the `/users` Firestore collection AND the Firebase Auth user pool.
Refuses to touch production unless explicitly opted in.

```bash
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-dev \
npm run wipe-users -- --confirm

# Production (rare — only when intentionally re-provisioning):
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
FIREBASE_PROJECT_ID=alrasikhoon-57151 \
npm run wipe-users -- --confirm --i-know-what-im-doing
```

## Cloud Functions IAM audit

`audit_functions_iam.sh` asserts that every Gen2 Cloud Function is publicly
invocable — i.e. the member `allUsers` holds `roles/run.invoker` on each
function's backing Cloud Run service.

**Why it exists:** on 2026-05-10 `setUserPassword` was silently broken for
~14h because its Cloud Run service was missing that binding. Firebase only
grants `allUsers` on a *clean* new-service create — a retry of a
previously-failed create does NOT re-grant it, so the function deploys
"successfully" while every client call gets a 403.

Needs `gcloud` authenticated with read-only viewer roles
(`roles/cloudfunctions.viewer` + `roles/run.viewer`). It never mutates IAM;
`--fix` only **prints** the remediation command, it does not run it.

```bash
# Audit production (functions live in us-central1):
scripts/audit_functions_iam.sh --project alrasikhoon-57151 --region us-central1

# Positional form is equivalent:
scripts/audit_functions_iam.sh alrasikhoon-57151 us-central1

# Print the gcloud add-iam-policy-binding command for any failing function
# (does NOT execute it — copy/run manually after review):
scripts/audit_functions_iam.sh -p alrasikhoon-57151 -r us-central1 --fix

# Full help:
scripts/audit_functions_iam.sh -h
```

Exit codes: `0` all functions invocable · `1` at least one failed (or none
found) · `2` bad usage / `gcloud` missing.

### Post-deploy wrapper — always audit after deploying

Don't run `firebase deploy --only functions` bare. Use the wrapper, which
guards the deploy on both sides so a bad deploy fails loudly instead of
looking green. In order it:

1. **Pre-deploy build freshness** (`functions/scripts/verify-build-fresh.sh`) —
   rebuilds `functions/lib` and asserts it matches `functions/src`, so a stale
   artifact can never be shipped.
2. **Pre-deploy build stamp** (`functions/scripts/build-stamp.sh`) — records
   HEAD's build identity (`<commit>[-dirty]-<lib-hash>`) into `functions/.env`
   as `BUILD_STAMP`, which Firebase deploys as an env var on each function.
3. **Deploy** — `firebase deploy --only functions`.
4. **Post-deploy IAM audit** (`audit_functions_iam.sh`) — asserts every
   function is publicly invocable.
5. **Post-deploy build identity** (`verify_deployed_build.sh`) — reads
   `BUILD_STAMP` back off the LIVE functions and asserts it equals HEAD's,
   proving the deploy actually replaced the running artifact.

```bash
# Deploys to alrasikhoon-57151 (us-central1) by default, with all guards:
scripts/deploy_functions.sh

# Override target project / region via env:
FIREBASE_PROJECT_ID=alrasikhoon-dev FUNCTIONS_REGION=us-central1 \
  scripts/deploy_functions.sh
```

The wrapper exits non-zero if the lib is stale, the deploy fails, a function
is missing the `allUsers` binding, or a function is not running HEAD's build.

### Build-freshness check (pre-deploy + CI)

`functions/scripts/verify-build-fresh.sh` rebuilds `functions/lib` and fails if
the compiled output changed — i.e. the lib about to ship did not match
`functions/src`. It closes the gap behind issue `al_rasikhoon-fh2`, where a
stale lib silently shipped two months of dormant `src` changes at once.

```bash
# From anywhere in the repo (or `npm run verify:build-fresh` in functions/):
functions/scripts/verify-build-fresh.sh
```

Exit codes: `0` fresh (or clean checkout with no prior lib) · `1` stale —
rebuilding changed the output · `2` build/environment failure. It runs in CI
(the **functions** job in `.github/workflows/ci.yml`) and as the first
pre-deploy step of the wrapper above.

### Deployed-build identity check (post-deploy)

`verify_deployed_build.sh` proves the functions actually RUNNING are the build
from HEAD, complementing the IAM audit (reachability) with an identity check.
The deploy path stamps `BUILD_STAMP` into each function's env; this script reads
it back off the live Cloud Run services and asserts it equals HEAD's stamp
(from `functions/scripts/build-stamp.sh`). A stale or missing stamp means
`firebase deploy` reported success but did not replace the running artifact —
the `al_rasikhoon-fh2` failure mode.

```bash
scripts/verify_deployed_build.sh --project alrasikhoon-57151 --region us-central1
```

Exit codes: `0` every function runs HEAD's build · `1` a function's stamp is
stale/missing (or none found) · `2` bad usage / `gcloud` missing.

**Only fully exercisable during a real deploy:** the read-back uses live
`gcloud` credentials against deployed services. Argument parsing and the
expected-stamp computation run offline (and in CI, via the *Verify build stamp
computes* step), but the read-back-and-compare needs a deployed project.

### CI — daily cron audit against production

`.github/workflows/functions-iam-audit.yml` runs the audit against prod every
day at 06:00 UTC (and on-demand via the Actions tab → *Run workflow*). It
authenticates with Google Cloud via **Workload Identity Federation** (no
long-lived service-account key in the repo) and, on a non-zero audit exit,
opens — or comments on an existing — GitHub issue labelled
`functions-iam-audit` so drift is caught within 24h.

**One-time setup (human, before the workflow can pass):** edit the three
`TODO:` placeholders in the workflow's `auth` step:

| Placeholder | What to put |
|-------------|-------------|
| `project_id` | Production GCP/Firebase project ID (live: `alrasikhoon-57151` — confirm) |
| `workload_identity_provider` | Full WIF provider resource name (`projects/<num>/locations/global/workloadIdentityPools/<pool>/providers/<provider>`) |
| `service_account` | A **read-only** SA email the WIF provider may impersonate — grant `roles/cloudfunctions.viewer` + `roles/run.viewer` ONLY, never an IAM-write role |

Keep the workflow's `--region us-central1` in sync with the `region:` set in
`functions/src/index.ts` if the functions ever move regions.
