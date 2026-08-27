# App Store / Play Console Privacy Labels — Al-Rasikhoon

What to declare in App Store Connect's App Privacy questionnaire and in Play
Console's Data safety form, and why each answer is what it is. Written so the
next submission does not have to re-derive this from the code.

This guide reflects the telemetry shipped in
`.superpowers/sdd/2026-08-27-production-observability/` (Sentry crash/error
reporting + Firebase Analytics aggregate usage stats, both on by default and
user-toggleable from «الملف الشخصي»). Turning the toggle off stops collection
at the SDK level, native layers included — see
`docs/guides/observability-runbook.md` §6. See also `web/privacy.html` §2.د
and §5.

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

The guarantee is **structural, not test-enforced**: `AnalyticsSink` — the only
route from this app to Firebase Analytics — exposes `logEvent` and
`setUserProperty` and nothing else. There is no `setUserId` on the seam at
all, so setting one is not something a call site can do by accident; it would
take a deliberate widening of the interface.

There is a test that guards the weaker, adjacent property — that the
`setUserProperties` call sets exactly `role` and `institute_id` and no
`user_id` property:

```
test/unit/data/telemetry/firebase_usage_analytics_test.dart
  'user properties carry role and institute but never a user id'
```

Do not read that test as pinning the whole "not linked" claim — it does not.
If `AnalyticsSink` ever grows a `setUserId` (or that test is deleted or
weakened), re-audit this guide's Usage Data row before the next submission.

Note also that Firebase Analytics derives an approximate country/region from
the connection's IP address server-side. That is not device location and needs
no Location declaration, but it is why `web/privacy.html` §2.ج says so
explicitly rather than claiming no geographic data of any kind.

## What is NOT collected (do not declare)

- Location
- Photos, contacts, microphone, or payment data
- Any advertising identifier or cross-app/cross-site tracking data
- Name, username, phone number, or memorization/session content in
  diagnostics or analytics payloads — Sentry's `sendDefaultPii` is `false`,
  and `attachScreenshot` / `attachViewHierarchy` are explicitly set to
  `false`. Session replay is off because the SDK ships it **off by default**
  and no replay sample rate is set — that is an absence of configuration, not
  an explicit opt-out, so a future SDK upgrade that changes the default would
  silently turn it on. `UserModel.toString()` and `InstituteModel.toString()`
  are both hardened to emit only the id (plus the role, for the user) so they
  cannot leak a name, phone or institute location if a raw model object ever
  reaches an error report.
