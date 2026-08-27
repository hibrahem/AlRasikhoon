# Production Observability — Design

**Date:** 2026-08-27
**Status:** Approved pending final review
**Issue:** al_rasikhoon-ciba
**Approach:** Hybrid (Approach C) — Sentry for errors, Firebase Analytics for
usage, Google Cloud Monitoring for backend health

## Problem

The app is about to go to production and is **completely blind** there. Today:

- **No crash or error reporting of any kind.** `pubspec.yaml` has no
  Crashlytics, no Sentry, no Analytics, no Performance package.
- **No global error handlers.** `lib/main.dart` installs neither
  `FlutterError.onError`, nor `PlatformDispatcher.instance.onError`, nor a
  guarded zone. An uncaught error in a release build leaves *zero* trace.
- **62 `debugPrint` calls** across `lib/`, almost all of the form
  `.when(error: (e, st) => debugPrint('xProvider failed: $e'))`. `debugPrint`
  is a no-op sink in release builds, so none of these are observable in
  production. They are also incomplete — many providers have no such call at
  all.
- **45 `catch` blocks** that swallow the error into a UI error state and report
  nothing.
- **No alerting.** `functions/src/index.ts` already logs well-structured JSON
  via `firebase-functions/logger` with proper context, and GCP Error Reporting
  captures thrown exceptions automatically — but nobody is notified when the
  error rate climbs, and nothing links a server-side log line to the client
  that provoked it.

The consequence: when a teacher in a halaqa hits a bug, the only way we learn
about it is if that teacher tells someone.

## Goals

1. **"Why did it fail?"** — every uncaught error, widget error, provider
   failure, and repository exception reaches a searchable console with a stack
   trace, app version, device, role, route, and connectivity state.
2. **"Is anyone using it, and where do they get stuck?"** — a small, deliberate
   set of product events, including an abandonment funnel for the core
   session-recording flow.
3. **"Is it slow or too expensive?"** — visibility into Firestore read volume
   and Cloud Functions latency, with a budget alert.
4. **"Did the backend break?"** — alerting on Cloud Functions error rate and
   Firestore permission-denied spikes, and a correlation id joining a
   client-side error to its server-side log entry.
5. **No regression in privacy posture.** Nothing identifying a student ever
   leaves the device beyond an opaque uid, and that constraint is enforced by
   tests, not by discipline.

## Non-goals

- **No Performance Monitoring SDK.** Cold start was already measured and
  optimised (`2026-07-15-fast-startup-optimistic-session-design.md`), and
  Firestore's gRPC traffic is not auto-instrumented anyway, so the package
  would buy little. Firestore cost visibility comes from Cloud Monitoring
  instead.
- **No Sentry in Cloud Functions.** GCP Error Reporting already captures
  function exceptions for free, and the functions already log structured
  context. A second Sentry project would add cost and configuration for
  marginal gain.
- **No session replay, no screenshots, no view-hierarchy capture.** Student
  names are on screen in nearly every view.
- **No BigQuery export, no custom dashboards** in this phase. Add them when a
  question arises that the Analytics console cannot answer.
- **No infra-as-code for alert policies.** Four rules configured in-console and
  captured in a runbook.

## Constraints

### Privacy (the binding constraint)

The published policy at `web/privacy.html` (last updated ٢٥ أغسطس ٢٠٢٦)
currently makes three promises that this work **contradicts**:

- «لا نستخدم أدوات تحليلات أو قياس سلوك أو إعلانات»
- «لا نجمع تقارير الأعطال»
- «ولا نشارك بياناتك مع أي طرف ثالث آخر»

Further, §1 establishes the **institute as the data controller** and Tech
Mentors LLC as processor, and §6 notes most users are 13+ with some younger
under institute supervision.

Therefore the privacy revision is **a required deliverable of this work, not a
follow-up**. Shipping the SDKs without it would put the app out of compliance
with its own published policy and misstate the App Store privacy labels.

### Architectural

Per `CLAUDE.md`, dependencies point inward and the inner layers carry no
framework or vendor imports. The observed conventions in this codebase are:
`lib/domain/` holds pure value objects, `lib/core/` holds cross-cutting
concerns, `lib/data/services/` holds infrastructure. Telemetry is a
cross-cutting concern rather than a domain concept, so the ports live in
`lib/core/telemetry/` and the vendor adapters in `lib/data/services/telemetry/`.

## Architecture

### Ports — pure, zero framework or vendor imports

```
lib/core/telemetry/
  error_reporter.dart      # abstract interface class ErrorReporter
  usage_analytics.dart     # abstract interface class UsageAnalytics
  telemetry_context.dart   # closed value object (see below)
  analytics_event.dart     # sealed event taxonomy
  pii_scrubber.dart        # pure functions, no dependencies
```

Two narrow ports rather than one `Telemetry` facade: "report an error" and
"record a usage event" have different consumers, different privacy rules, and
different vendors behind them.

```dart
abstract interface class ErrorReporter {
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });
  void addBreadcrumb(String message, {String? category});
  void updateContext(TelemetryContext context);
}

abstract interface class UsageAnalytics {
  void record(AnalyticsEvent event);
  void setUserProperties({required String role, required String instituteId});
}
```

### Adapters — infrastructure

```
lib/data/services/telemetry/
  sentry_error_reporter.dart      # ErrorReporter  -> Sentry
  firebase_usage_analytics.dart   # UsageAnalytics -> Firebase Analytics
  noop_telemetry.dart             # both ports, does nothing
  telemetry_providers.dart        # Riverpod wiring and adapter selection
```

`noop_telemetry.dart` is selected in three cases:

1. **Debug builds** (`kDebugMode`) — development noise never reaches the console.
2. **Emulator runs** — `FirebaseEmulatorConfig` already knows.
3. **All tests** — the existing suite needs no network stubs and no new mocks.

A fourth gate is the user opt-out (below).

### Capture points

| # | Hook | Catches | Today |
|---|------|---------|-------|
| 1 | `FlutterError.onError` | widget build/layout errors | nothing |
| 2 | `PlatformDispatcher.instance.onError` | uncaught async errors | nothing |
| 3 | Riverpod `ProviderObserver.providerDidFail` | every provider failure app-wide | nothing |
| 4 | `go_router` `NavigatorObserver` | route breadcrumbs, current route | nothing |
| 5 | `connectivity_plus` listener | online/offline transitions | nothing |
| 6 | repository `catch` blocks (45) | Firestore/callable failures as non-fatals | swallowed |

**Hook 3 is the highest-leverage element of this design.** Every one of the 62
`debugPrint` calls follows the same shape — a failed provider rendered in a
`.when(error:)` branch. A single `ProviderObserver` catches all of them,
*including the providers that nobody remembered to add a `debugPrint` to*.
Consequently this work **deletes all 62 `debugPrint` calls** rather than
converting them; once the observer exists they are redundant. The net effect on
the codebase is a simplification.

**Hook 5 is what makes this app's bugs diagnosable.** Users work in halaqas that
may have no connectivity, and the app runs an unbounded Firestore offline cache
(`2026-07-19-offline-mode-design.md`). "Saving failed" and "saving failed while
offline after three reconnects" are different bugs with different fixes.

**Implementation risk:** the project is on `flutter_riverpod ^3.1.0`, and
Riverpod 3 changed the `ProviderObserver` signatures. The exact API must be
verified against the installed version rather than assumed.

### Context attached to every report

`TelemetryContext` is a **closed value object**, not an open `Map`. Arbitrary
key/value bags are precisely how PII leaks into error consoles.

| Field | Value | Rationale |
|---|---|---|
| `userId` | Firebase uid, opaque | correlate to Firestore docs when debugging |
| `role` | teacher / student / supervisor / admin / guardian | most bugs are role-shaped |
| `instituteId` | institute id | scoping bugs are institute-shaped |
| `route` | **templated** (`/students/:id`) | raw routes embed student ids |
| `connectivity` | online / offline / wifi / mobile | separates offline bugs from real ones |

App version and release require **no new dependency**: `sentry_flutter` and
Firebase Analytics both read the package version natively.

## PII protection

The rule is **allow-list, never deny-list**. A deny-list fails the first time
someone adds a field nobody anticipated.

1. **Closed context object.** Only the five fields above can ever be attached.
2. **`beforeSend` scrubber** as the last line of defense on the raw error
   message, because `FirebaseException` messages embed document paths and
   occasionally field values:
   - redact anything matching `@alrasikhoon.local` — the synthetic login
     address described in policy §2أ — to `<redacted>@alrasikhoon.local`
   - template long alphanumeric ids and UUIDs appearing in paths to `:id`
3. **Hard-disabled in Sentry configuration:** `sendDefaultPii: false`,
   `attachScreenshot: false`, `attachViewHierarchy: false`, no session replay.
4. **Analytics `userId` is never set.** Only `role` and `institute_id` are set
   as user properties. This is deliberate: setting the uid would turn Firebase
   Analytics into a per-person behavioural profile of minors. Aggregate data
   answers "where do teachers get stuck" without needing to know which child.
5. **Numbers are bucketed, never raw** in analytics parameters (see taxonomy).

These rules are enforced by tests (see Testing), not by reviewer vigilance.

### User opt-out

A settings toggle, «إرسال تقارير الأعطال والاستخدام», default **ON**, persisted
in `SharedPreferences` (already wired into `main.dart`), gating both adapters to
`noop`. Cheap to build; materially simplifies both the App Review narrative and
the conversation with institutes, who are the data controllers.

## Analytics taxonomy

A sealed `AnalyticsEvent` type. Numeric values are bucketed rather than raw —
bucketing prevents re-identification and is sufficient for product decisions.

| Event | Parameters |
|---|---|
| `login_succeeded` | `role` |
| `login_failed` | `reason_code` |
| `session_recorded` | `session_type` (hifz/talqeen/sard), `errors_bucket`, `duration_bucket`, `was_offline` |
| `session_abandoned` | `step` (opened / errors_recorded / saving) |
| `assessment_completed` | `result` |
| `talqeen_completed` | — |
| `home_practice_logged` | — |
| `offline_write_queued` | — |
| `offline_sync_completed` | `pending_bucket` |
| `screen_view` | templated screen name |

`session_abandoned` is the funnel that answers "where do teachers get stuck":
opened → recorded errors → saved.

Buckets: `errors_bucket` ∈ {0, 1-3, 4-10, 10+}; `duration_bucket` ∈
{<5m, 5-15m, 15-30m, 30m+}; `pending_bucket` ∈ {1, 2-5, 6-20, 20+}.

Firebase Analytics limits (500 distinct event names, 25 params per event, 40-char
param names) are comfortably satisfied.

## Backend

### Correlation

The client generates a `client_trace_id` per callable invocation and includes it
in the payload. `functions/src/index.ts` adds it to its existing `logger` calls.
The field is **optional and backwards-compatible**, so an older client
continues to work unchanged. This joins a client-side Sentry error to its
server-side Cloud Logging entry without adopting distributed tracing.

Affected callables: `createUserAccount`, `setUserPassword`, `hardDeleteStudent`.

### Alerting

Four Cloud Monitoring / Sentry policies, configured in-console and documented in
`docs/guides/observability-runbook.md`:

| Alert | Condition | Destination |
|---|---|---|
| Functions error rate | errors > 5 in 5 min | email |
| Firestore permission denied | > 20 `PERMISSION_DENIED` responses in 10 min | email |
| Firestore read budget | daily read count > 50,000 | email |
| Crash-free session rate | drops below 99% over 24h | Sentry email |

The permission-denied alert matters specifically because of institute scoping
(`AgDR-0003-supervisor-institute-scoping.md`): a spike means either a rules bug
locking legitimate users out, or someone probing.

## Error handling

Telemetry must never be a source of failure. Every adapter method is
non-throwing: internal exceptions are caught and dropped. Initialisation failure
(no network, Sentry DSN misconfigured) degrades to `noop` rather than blocking
`runApp`. Telemetry initialisation must not extend the pre-first-frame window
established by the fast-startup work — Sentry is initialised around `runApp` via
its `appRunner`, and Analytics is initialised lazily after the first frame.

## Testing

Per `CLAUDE.md`, tests use domain language and are layered.

**Pure unit tests, no mocks** (`test/core/telemetry/`):
- `test_scrubber_redacts_synthetic_login_email`
- `test_scrubber_replaces_document_ids_in_route_with_placeholder`
- `test_scrubber_leaves_ordinary_error_messages_intact`
- `test_context_carries_role_institute_and_connectivity`
- `test_error_count_bucket_maps_to_expected_range`

**Adapter tests with fake sinks** (`test/data/services/telemetry/`):
- `test_reporter_never_forwards_student_name_to_sink` — the guard test
- `test_telemetry_is_disabled_in_debug_builds`
- `test_telemetry_is_disabled_when_user_opts_out`
- `test_reporter_swallows_sink_failures`

**Observer test:**
- `test_failing_provider_is_reported_to_error_reporter`

**Regression guard:**
- a test asserting no `debugPrint` remains under `lib/`, so the 62 deletions
  cannot creep back.

## Rollout

| Phase | Content | Gate |
|---|---|---|
| 1 | Ports, scrubber, context, event taxonomy, `noop` adapter, all unit tests | CI green, nothing shipped |
| 2 | Global handlers, `ProviderObserver`, route + connectivity breadcrumbs, Sentry adapter; delete 62 `debugPrint`s | CI green |
| 3 | Analytics adapter, event instrumentation, user properties, opt-out toggle | CI green |
| 4 | `client_trace_id` correlation, alert policies, runbook | alerts firing on a test error |
| 5 | Privacy policy revision, App Store Connect labels, Play Data Safety, CHANGELOG | before the next store submission |

**Phase 5 is not optional paperwork.** It is the phase that keeps the app out of
an App Review rejection and keeps it consistent with its own published policy.

Deliverables in Phase 5:
- `web/privacy.html`: rewrite §2ج («ما لا نجمعه») and §5 («مقدّمو الخدمة») to
  disclose crash diagnostics, aggregate usage analytics, and Sentry as a
  sub-processor; bump «آخر تحديث».
- App Store Connect → App Privacy: declare Diagnostics (Crash Data,
  Performance Data) and Usage Data (Product Interaction). Crash data is linked
  to identity (uid is sent); usage data is **not** linked (no Analytics uid).
- Play Console → Data safety: the equivalent declarations.
- `CHANGELOG.md`: a stakeholder-facing bullet for the privacy policy update and
  the new settings toggle. Per project convention the internal plumbing itself
  needs no entry.

## Consequences

**Gained:** production failures become visible and searchable; provider failures
are captured app-wide rather than per-screen; offline-specific bugs become
distinguishable; the backend pages someone instead of failing silently; the
vendor choice is reversible behind two small ports.

**Accepted costs:** two new client dependencies (`sentry_flutter`,
`firebase_analytics`); a new sub-processor (Sentry) that must be disclosed to
institutes and covered by a DPA; a privacy policy revision and two store form
updates; Sentry's free tier (~5k errors/month) may need a paid plan if error
volume is high — which would itself be a signal worth acting on.
