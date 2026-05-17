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
deploys and then immediately runs the audit so a deploy that leaves a
function un-invocable fails loudly instead of looking green:

```bash
# Deploys to alrasikhoon-57151 (us-central1) by default, then audits:
scripts/deploy_functions.sh

# Override target project / region via env:
FIREBASE_PROJECT_ID=alrasikhoon-dev FUNCTIONS_REGION=us-central1 \
  scripts/deploy_functions.sh
```

The wrapper exits non-zero if either the deploy fails or the post-deploy
audit finds a function missing the binding.

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
