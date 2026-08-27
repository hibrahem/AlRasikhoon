# Observability Runbook — Al-Rasikhoon

What to do when a production alert fires. Written for whoever is on call at
2am with no context loaded: every section below gives the exact console path,
the exact metric and threshold, and a concrete first move.

Companion docs: `docs/agdr/AgDR-0003-supervisor-institute-scoping.md` (institute
scoping, referenced by Alert 2), `docs/guides/ios-release-flow.md` and
`.github/workflows/README.md` (how builds ship).

---

## 1. Where to look

| System | URL / path | What it's for |
|---|---|---|
| **Sentry** | `https://sentry.io/organizations/<your-org>/projects/al-rasikhoon/` | Client-side crashes and captured exceptions, tagged with `clientTraceId`. Ask whoever owns the Sentry org for the exact org slug if the link 404s. |
| **Firebase Analytics** | Firebase console → project `alrasikhoon-57151` → **Analytics** → **Dashboard** (`https://console.firebase.google.com/project/alrasikhoon-57151/analytics`) | Usage events (opt-in only — see §5). |
| **Google Cloud Monitoring** | `https://console.cloud.google.com/monitoring?project=alrasikhoon-57151` | Alert policies, metrics explorer, and notification channels for Cloud Functions and Firestore. |
| **Cloud Logging** | `https://console.cloud.google.com/logs/query?project=alrasikhoon-57151` | Structured JSON logs from the three callables (`createUserAccount`, `setUserPassword`, `hardDeleteStudent`), each carrying a `clientTraceId` field. |
| **Firestore** | `https://console.cloud.google.com/firestore/databases?project=alrasikhoon-57151` | Database is in `europe-west6`. Rules, indexes, and usage live here. |

All four alert policies below live in Cloud Monitoring **except Alert 4**,
which is configured in Sentry itself (Sentry has no visibility into
server-side Cloud metrics, and Cloud Monitoring has no visibility into
client-side crash-free rate).

### The correlation that ties it all together: `clientTraceId`

Every call the app makes to `createUserAccount`, `setUserPassword`, and
`hardDeleteStudent` is tagged, client-side, with a `clientTraceId` — a random
id generated per attempt. Two things happen with it:

1. The Cloud Function includes `clientTraceId` in every structured log line it
   writes via `firebase-functions/logger` (see `functions/src/index.ts`), so
   the *server-side* half of a failed call is searchable in Cloud Logging by
   that id.
2. If the same call also triggers a client-side Sentry event (e.g. the app
   surfaces an error to the user), that event carries the same
   `clientTraceId` as a tag.

**This is the whole point of the field.** A single failed account-creation
attempt produces two independent trails — one in Cloud Logging (what the
server saw), one in Sentry (what the user's device saw) — and `clientTraceId`
is the only thing that joins them. Without it you have two disconnected logs
and no way to tell they're the same incident. With it: copy the id from one
system, paste it into the search box of the other, done.

---

## 2. Alert 1 — Cloud Functions error rate

**Where:** Cloud Monitoring → **Alerting** → **Create Policy**.

**Metric:** `cloudfunctions.googleapis.com/function/execution_count`
**Filter:** `status != "ok"`
**Condition:** more than **5** in **5 minutes**
**Notification channel:** maintainer email

### What to do when it fires

1. Open **Cloud Logging** (link in §1) and filter to the failing function:
   ```
   resource.type="cloud_function"
   resource.labels.function_name="<name from the alert>"
   severity>=ERROR
   ```
2. Find a failed execution's log line. It's structured JSON from
   `firebase-functions/logger` — the three callables (`createUserAccount`,
   `setUserPassword`, `hardDeleteStudent`) all log a `clientTraceId` field on
   both success and failure paths.
3. Copy that `clientTraceId` value.
4. Search it in **Sentry** (full-text / tag search:
   `clientTraceId:<value>`). If a matching client-side event exists, it tells
   you what the user's device experienced (network error, stale auth token,
   validation failure surfaced from the callable, etc.) — pair that with the
   server-side stack trace from Cloud Logging to get the full picture.
5. If there is no matching Sentry event, the failure never reached the client
   as a visible error (e.g. the app retried silently, or the user has
   diagnostics off — see §5) — treat the Cloud Logging trace as the sole
   source of truth.
6. Check whether the spike correlates with a recent deploy of `functions/`
   (Cloud Functions console → the function → **Revisions**). A bad deploy is
   the most common cause; rolling back the function to the previous revision
   is usually faster than a forward fix.

---

## 3. Alert 2 — Firestore permission denied

**Where:** Cloud Monitoring → **Alerting** → **Create Policy**.

**Metric:** `firestore.googleapis.com/api/request_count`
**Filter:** `response_code = "PERMISSION_DENIED"`
**Condition:** more than **20** in **10 minutes**
**Notification channel:** maintainer email

### What to do when it fires

A spike here means one of two things, and you need to figure out which fast:

- **A `firestore.rules` regression** is locking out legitimate users, or
- **Someone is probing** the database for access they don't have.

Steps, in order:

1. Check the most recent `firestore.rules` deploy first:
   `https://console.firebase.google.com/project/alrasikhoon-57151/firestore/databases/-default-/rules`
   → **History** tab. If a rules change went out in the window just before
   the spike started, that is almost certainly the cause — read the diff for
   anything touching institute scoping.
2. Institute scoping is the most likely rules surface to regress. It is
   documented in `docs/agdr/AgDR-0003-supervisor-institute-scoping.md`:
   supervisors are scoped to their institute via `users/{uid}.institute_id`,
   and a rules change that gets that comparison wrong will lock out every
   supervisor whose institute check now fails (this shows up as a burst of
   `PERMISSION_DENIED` across many distinct users, not one).
   (`AgDR-0004-supervisor-multi-institute-membership.md` supersedes the
   one-institute-per-supervisor model described there — check which model is
   live before assuming the exact field being compared.)
3. If there was no recent rules deploy, pull the denied requests' identity
   from Cloud Logging (`protoPayload.authenticationInfo.principalEmail` /
   the request's auth uid) — a small number of distinct accounts hammering
   denied paths looks like probing; a rules bug looks like a broad,
   correlated spike across otherwise-legitimate users hitting one code path.
4. If it's a rules regression: revert the rules deploy
   (`firebase deploy --only firestore:rules` with the previous known-good
   `firestore.rules`, or redeploy from the last-good commit) and confirm the
   `PERMISSION_DENIED` rate drops.
5. If it looks like probing: no rules change needed. Note the offending
   identity/IP pattern; escalate per your incident process if it looks
   automated or sustained.

---

## 4. Alert 3 — Firestore read budget

**Where:** Cloud Monitoring → **Alerting** → **Create Policy**.

**Metric:** `firestore.googleapis.com/document/read_count`
**Condition:** daily total above **50,000**
**Notification channel:** maintainer email

### What to do when it fires

1. In Cloud Monitoring's **Metrics Explorer**, filter
   `firestore.googleapis.com/document/read_count` and group by
   collection/method if the console offers it, or cross-reference with
   Firestore's own **Usage** tab
   (`https://console.cloud.google.com/firestore/databases/-default-/usage?project=alrasikhoon-57151`)
   to see which collection is driving the reads.
2. Identify the *screen* behind that collection — the offline cache is
   unbounded by design (memorization data needs to work with no connectivity
   in a halaqa), so a spike is expected background noise up to a point. Above
   50,000/day it usually means a Riverpod provider is re-fetching in a loop
   (a `StreamProvider`/`FutureProvider` re-subscribing on every rebuild
   instead of once, or a widget rebuilding its `ref.watch` in a way that
   re-triggers the query).
3. Reproduce locally with the emulator if possible and watch the Firestore
   emulator's request log for the same collection — a tight loop is usually
   obvious within a few seconds of using the suspect screen.
4. This is a cost/quota concern, not typically a user-facing outage — you do
   not need to page anyone at 2am for this one specifically unless it's
   trending toward hitting Firestore's daily quota ceiling. File a follow-up
   issue and fix the loop in the next work session unless it's actively
   burning through budget fast.

---

## 5. Alert 4 — Crash-free session rate

**Where:** Sentry → your project → **Alerts** → **Create Alert** → metric
type **Crash Free Session Rate**.

**Condition:** below **99%** over **24 hours**
**Notification channel:** configure in Sentry (email/Slack/etc. per your
Sentry org's setup)

### What to do when it fires

1. Open the Sentry **Issues** view for the project, sorted by event count,
   filtered to the last 24h. The top issue is almost always the majority
   contributor to the drop.
2. Check the release/version tag on the top issues — if they cluster on one
   build number, that build is the regression; the fix is usually "ship a
   patch release," not "fix forward silently."
3. For each top crash, pull its `clientTraceId` tag (if present — not every
   crash originates from one of the three callables) and cross-reference
   Cloud Logging per §1's join, in case the crash was triggered by a
   server-side failure surfacing badly on the client.
4. Remember this metric only reflects users who have diagnostics **on** (see
   §6) — if opt-in rates are low, the sample size may be small enough that a
   handful of crashes swing the percentage. Sanity-check the session count
   the alert is computing over before treating a single-digit-crash spike as
   a full-blown incident.

---

## 6. Turning telemetry on and off

**The DSN.** `SENTRY_DSN` is supplied to the app at build time via
`--dart-define=SENTRY_DSN=...` and stored as the `SENTRY_DSN` GitHub Actions
secret. It is **never committed** to the repo. `lib/data/services/telemetry/
telemetry_providers.dart` reads it as `kSentryDsn = String.fromEnvironment
('SENTRY_DSN')`, defaulting to an empty string when the define isn't
supplied. `telemetryIsPermitted()` in that same file treats an empty DSN
(among other conditions — debug mode, emulator mode) as "telemetry
disabled," so:

- A build with no `SENTRY_DSN` secret set still builds and runs fine — it
  just never talks to Sentry.
- **If crash/usage reports stop arriving after a release, check the
  `SENTRY_DSN` secret first** before assuming the app itself is broken. A
  secret that was deleted, expired, or renamed silently disables telemetry
  with no build failure and no user-visible symptom.

**User opt-out.** Users can turn diagnostics off in-app under **الملف
الشخصي** (Profile) → the "إرسال تقارير الأعطال والاستخدام" toggle
(`lib/features/settings/widgets/telemetry_toggle.dart`). This is a per-device,
per-user preference and does not affect other users.

**Global kill switch.** To disable telemetry for everyone, server-side:
remove/rotate the `SENTRY_DSN` GitHub secret and cut a new release build
(Android: run the **Distribute Android** workflow; iOS: run
**distribute-ios.yml**, per `docs/guides/ios-release-flow.md`). Existing
installs keep whatever DSN was baked into the build they already have — a
kill switch only takes effect from the next release onward, it cannot reach
back into devices that already installed a build with a live DSN. There is no
remote-config-driven kill switch for already-installed builds.

---

## 7. Setup this document does NOT do for you

This runbook documents four alert policies and one GitHub secret. **None of
them are created by this change.** A maintainer must create them by hand:

### Create the `SENTRY_DSN` GitHub secret

1. Create (or reuse) a Sentry project for Al-Rasikhoon; copy its DSN from
   **Settings → Client Keys (DSN)**.
2. In GitHub: repo → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**.
3. Name: `SENTRY_DSN`. Value: the DSN from step 1. Save.
4. Both `distribute-android.yml` (via `scripts/distribute_android.sh`) and
   `distribute-ios.yml` already reference `secrets.SENTRY_DSN` — no further
   workflow change is needed once the secret exists. The next distribution
   run will bake it in.

### Create the four Cloud Monitoring / Sentry alert policies

1. **Alert 1** (Cloud Functions errors): Cloud Monitoring → **Alerting** →
   **Create Policy** → metric `cloudfunctions.googleapis.com/function/
   execution_count` → add filter `status != "ok"` → condition: count > 5 over
   a 5-minute rolling window → notification channel: maintainer email
   (create the email notification channel first under **Alerting** →
   **Notification channels** if one doesn't exist) → save.
2. **Alert 2** (Firestore permission denied): same **Create Policy** flow,
   metric `firestore.googleapis.com/api/request_count`, filter
   `response_code = "PERMISSION_DENIED"`, condition: count > 20 over a
   10-minute rolling window, same notification channel.
3. **Alert 3** (Firestore read budget): same flow, metric
   `firestore.googleapis.com/document/read_count`, condition: daily
   aggregate (sum, 1-day alignment period) > 50,000, same notification
   channel.
4. **Alert 4** (crash-free session rate): in **Sentry**, project → **Alerts**
   → **Create Alert** → choose **Crash Free Session Rate** as the metric →
   condition: below 99% → time window: 24 hours → set the notification
   target per your Sentry org's configuration → save.

Until a maintainer completes both sections above, the app builds and runs
normally with telemetry silently disabled, and no alert will ever fire
because none exist yet.
