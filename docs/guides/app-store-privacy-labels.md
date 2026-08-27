# App Store / Play Console Privacy Labels — Al-Rasikhoon

What to declare in App Store Connect's App Privacy questionnaire and in Play
Console's Data safety form, and why each answer is what it is. Written so the
next submission does not have to re-derive this from the code.

This guide reflects the telemetry shipped in
`.superpowers/sdd/2026-08-27-production-observability/` (Sentry crash/error
reporting + Firebase Analytics aggregate usage stats, both user-toggleable
from «الملف الشخصي»). See also `web/privacy.html` §2.د and §5, and
`docs/guides/observability-runbook.md`.

---

## App Store Connect → App Privacy

| Category | Data type | Collected? | Linked to identity? | Used for tracking? |
|---|---|---|---|---|
| Diagnostics | Crash Data | Yes | **Yes** — the Firebase uid is attached as the Sentry user id | No |
| Diagnostics | Performance Data | Yes | **Yes** — same Sentry user id | No |
| Usage Data | Product Interaction | Yes | **No** — no Analytics user id is ever set | No |
| Identifiers | User ID | Yes | Yes | No |

Notes:
- "Linked to identity" for Crash Data and Performance Data is correct because
  every Sentry event carries the Firebase uid as `Sentry.user.id` (set in
  `lib/data/services/telemetry/telemetry_providers.dart`). It is an opaque
  account identifier, not name/email/phone — but App Store's definition of
  "linked" only asks whether the data can be connected to a user's identity,
  which an id-based join satisfies regardless of whether the id itself is
  human-readable.
- "Not used for tracking" applies to all four rows: nothing here is used to
  link the user across other companies' apps or websites for
  advertising — there is no advertising SDK in the app at all.

## Play Console → Data safety

Declare the same four data points as above, plus:

- **Encryption in transit:** Yes — all data (Firestore, Cloud Functions,
  Sentry, Firebase Analytics) travels over HTTPS/TLS.
- **Data deletion:** Users can request deletion. Per `web/privacy.html` §1
  and §8, the institute is the data controller and is the primary channel for
  a deletion request; Tech Mentors LLC will action or route a request sent
  directly if the institute is unreachable.

## Why "not linked" is accurate for usage data

`FirebaseUsageAnalytics` (`lib/data/services/telemetry/firebase_usage_analytics.dart`)
deliberately never calls `setUserId`. The only user properties it sets are
`role` and `institute_id` — never a per-user identifier — and every numeric
event parameter is bucketed (e.g. an error count is reported as a range like
`4-10`, a duration as `15-30m`) rather than sent as a raw, potentially
re-identifying number.

This is pinned by a test, so a future change that adds a user id or an
unbucketed raw value will fail CI rather than silently making the "not
linked" declaration above false:

```
test/unit/data/telemetry/firebase_usage_analytics_test.dart
  'user properties carry role and institute but never a user id'
```

If that test is ever deleted or weakened, re-audit this guide's Usage Data
row before the next submission.

## What is NOT collected (do not declare)

- Location
- Photos, contacts, microphone, or payment data
- Any advertising identifier or cross-app/cross-site tracking data
- Name, username, phone number, or memorization/session content in
  diagnostics or analytics payloads — Sentry's `sendDefaultPii` is `false`,
  screenshots/view-hierarchy capture/session replay are disabled, and
  `UserModel.toString()` is hardened to emit only id and role so it cannot
  leak PII if a raw model object ever reaches an error report.
