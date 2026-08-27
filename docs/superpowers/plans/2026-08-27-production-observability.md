# Production Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make production failures, usage, and backend health observable for the الراسخون Flutter app, which today has no crash reporting, no global error handlers, and 62 `debugPrint` calls that vanish in release builds.

**Architecture:** Two narrow vendor-neutral ports (`ErrorReporter`, `UsageAnalytics`) live in `lib/core/telemetry/` with zero framework or vendor imports. Vendor adapters (Sentry, Firebase Analytics, and a no-op) live in `lib/data/services/telemetry/`. A single Riverpod `ProviderObserver` captures every provider failure app-wide, replacing all 62 scattered `debugPrint` calls. All personally identifying data is blocked by a closed context value object plus a pure scrubber, both enforced by tests.

**Tech Stack:** Flutter 3.9+/Dart 3, `flutter_riverpod` 3.1.0, `go_router` 17, `connectivity_plus` 7, `shared_preferences` 2.3, Firebase (Auth/Firestore/Functions), plus two new dependencies added during this plan: `sentry_flutter` and `firebase_analytics`.

**Spec:** `docs/superpowers/specs/2026-08-27-production-observability-design.md`
**Issue:** al_rasikhoon-ciba

## Global Constraints

- **Never send PII.** Student/teacher name, `username`, `phone`, and real or synthetic email must never leave the device. Only the opaque Firebase uid, role, institute id, templated route, and connectivity state may be attached. `UserModel.toString()` includes `username` and `name` — never interpolate a `UserModel` into an error message, reason, or breadcrumb.
- **Never set an Analytics `userId`.** Only `role` and `institute_id` user properties.
- **Telemetry never throws.** Every adapter method catches and drops its own internal exceptions. Telemetry failure must never take down the app or a provider.
- **Telemetry is disabled** in debug builds (`kDebugMode`), in emulator mode (`FirebaseEmulatorConfig.isEmulatorMode`), when the Sentry DSN is empty, and when the user has opted out.
- **No secrets in the repo.** The Sentry DSN arrives via `--dart-define=SENTRY_DSN=...`. An empty DSN degrades to the no-op adapter, so local runs and CI work with no secret configured.
- **Ports stay pure.** Nothing under `lib/core/telemetry/` may import `package:flutter/*`, `package:firebase_*`, `package:sentry*`, or `package:flutter_riverpod`. `dart:core` and `lib/core/constants` only.
- **Riverpod 3 API (verified against installed 3.1.0):** `ProviderObserver` is an `abstract base class`, so subclasses must be declared `final class ... extends ProviderObserver`. The hook signature is `void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace)`. `ProviderScope` accepts `observers: List<ProviderObserver>?`.
- **Test commands:** `flutter test test/<path>` for one file, `flutter test test/` for the suite, `flutter analyze --no-fatal-infos` for lints. All three must pass before any commit.
- **Test naming** uses domain language per `CLAUDE.md` (e.g. `test_scrubber_redacts_synthetic_login_email`, not `test_scrub_works`).
- **Commit style:** one commit per task, Conventional Commits, subject ends with `(al_rasikhoon-ciba)`, body ends with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

## File Structure

| Path | Responsibility |
|---|---|
| `lib/core/telemetry/pii_scrubber.dart` | Pure redaction + route templating + numeric buckets |
| `lib/core/telemetry/telemetry_context.dart` | Closed value object of allowed context fields |
| `lib/core/telemetry/analytics_event.dart` | Sealed usage-event taxonomy |
| `lib/core/telemetry/error_reporter.dart` | `ErrorReporter` port |
| `lib/core/telemetry/usage_analytics.dart` | `UsageAnalytics` port |
| `lib/core/telemetry/telemetry_gate.dart` | Mutable on/off holder consulted by every adapter |
| `lib/data/services/telemetry/noop_telemetry.dart` | Both ports, does nothing |
| `lib/data/services/telemetry/sentry_error_reporter.dart` | `ErrorReporter` → Sentry |
| `lib/data/services/telemetry/firebase_usage_analytics.dart` | `UsageAnalytics` → Firebase Analytics |
| `lib/data/services/telemetry/telemetry_providers.dart` | Riverpod wiring |
| `lib/shared/providers/telemetry_provider_observer.dart` | `ProviderObserver` → `ErrorReporter` |
| `lib/shared/providers/telemetry_navigator_observer.dart` | Route breadcrumbs + route context |
| `lib/shared/providers/telemetry_connectivity_provider.dart` | Connectivity breadcrumbs + context |
| `lib/features/settings/providers/telemetry_enabled_provider.dart` | Opt-out toggle state |
| `lib/features/settings/widgets/telemetry_toggle.dart` | Opt-out toggle UI |
| `docs/guides/observability-runbook.md` | Alert policies, thresholds, response steps |

---

### Task 1: PII scrubber and numeric buckets

**Files:**
- Create: `lib/core/telemetry/pii_scrubber.dart`
- Test: `test/unit/core/telemetry/pii_scrubber_test.dart`

**Interfaces:**
- Consumes: `AppConstants.synthesizedEmailDomain` from `lib/core/constants/app_constants.dart`
- Produces: `String scrubMessage(String input)`, `String templateRoute(String route)`, `String errorsBucket(int count)`, `String durationBucket(Duration duration)`, `String pendingBucket(int count)`

- [ ] **Step 1: Confirm the constant name**

Run: `grep -n "synthesizedEmailDomain" lib/core/constants/app_constants.dart`
Expected: a line defining `synthesizedEmailDomain`. Use that exact name below. If it does not exist, use the literal `'alrasikhoon.local'` and note the deviation in the commit body.

- [ ] **Step 2: Write the failing test**

Create `test/unit/core/telemetry/pii_scrubber_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/pii_scrubber.dart';

void main() {
  group('scrubMessage', () {
    test('redacts the synthetic login email', () {
      const input = 'FirebaseAuthException: no user for ahmad.ali@alrasikhoon.local';
      expect(scrubMessage(input), isNot(contains('ahmad.ali')));
      expect(scrubMessage(input), contains('<redacted>@alrasikhoon.local'));
    });

    test('templates document ids embedded in firestore paths', () {
      const input = 'PERMISSION_DENIED on students/aB3xY9kL2mN7pQ4rS8tU/sessions';
      expect(scrubMessage(input), contains('students/:id/sessions'));
      expect(scrubMessage(input), isNot(contains('aB3xY9kL2mN7pQ4rS8tU')));
    });

    test('leaves ordinary error messages intact', () {
      const input = 'Network request failed after 3 retries';
      expect(scrubMessage(input), input);
    });
  });

  group('templateRoute', () {
    test('replaces a student id with a placeholder', () {
      expect(templateRoute('/students/aB3xY9kL2mN7pQ4rS8tU'), '/students/:id');
    });

    test('replaces a uuid segment with a placeholder', () {
      expect(
        templateRoute('/sessions/3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        '/sessions/:id',
      );
    });

    test('preserves a hyphenated route name that is not an id', () {
      expect(templateRoute('/account-not-found'), '/account-not-found');
    });

    test('preserves a nested static route', () {
      expect(templateRoute('/admin/institutes'), '/admin/institutes');
    });
  });

  group('buckets', () {
    test('maps a recitation error count to its expected range', () {
      expect(errorsBucket(0), '0');
      expect(errorsBucket(3), '1-3');
      expect(errorsBucket(4), '4-10');
      expect(errorsBucket(11), '10+');
    });

    test('maps a session duration to its expected range', () {
      expect(durationBucket(const Duration(minutes: 4)), '<5m');
      expect(durationBucket(const Duration(minutes: 15)), '5-15m');
      expect(durationBucket(const Duration(minutes: 29)), '15-30m');
      expect(durationBucket(const Duration(minutes: 31)), '30m+');
    });

    test('maps a pending write count to its expected range', () {
      expect(pendingBucket(1), '1');
      expect(pendingBucket(5), '2-5');
      expect(pendingBucket(20), '6-20');
      expect(pendingBucket(21), '20+');
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unit/core/telemetry/pii_scrubber_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'al_rasikhoon/core/telemetry/pii_scrubber.dart'`

- [ ] **Step 4: Write the implementation**

Create `lib/core/telemetry/pii_scrubber.dart`:

```dart
/// Pure, dependency-free redaction helpers.
///
/// These run on every message and route before it leaves the device. They are
/// the last line of defence behind [TelemetryContext]'s closed field set:
/// FirebaseException messages routinely embed document paths, and go_router
/// locations embed student ids.
library;

import '../constants/app_constants.dart';

const String _redactedLocalPart = '<redacted>';

final RegExp _syntheticEmail = RegExp(
  r'[A-Za-z0-9._%+-]+@' + RegExp.escape(AppConstants.synthesizedEmailDomain),
);

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final RegExp _containsDigit = RegExp(r'\d');

/// A path segment is treated as an identifier when it is a UUID, or when it is
/// long AND contains a digit. The digit test is what keeps legitimate route
/// names intact: `/account-not-found` is 17 characters but has no digit, while
/// a Firestore auto-id is 20 mixed-case alphanumerics and always has one.
bool _looksLikeIdentifier(String segment) {
  if (_uuid.hasMatch(segment)) return true;
  return segment.length >= 16 && _containsDigit.hasMatch(segment);
}

/// Replaces identifier-looking segments in a `/`-delimited path with `:id`.
String templateRoute(String route) {
  final query = route.indexOf('?');
  final path = query == -1 ? route : route.substring(0, query);
  final templated = path
      .split('/')
      .map((segment) => _looksLikeIdentifier(segment) ? ':id' : segment)
      .join('/');
  // Query strings can carry ids too, and nothing downstream needs them.
  return templated;
}

/// Redacts synthetic login addresses and document ids from a free-form
/// message. Safe to call on any string, including an empty one.
String scrubMessage(String input) {
  final withoutEmails = input.replaceAllMapped(
    _syntheticEmail,
    (_) => '$_redactedLocalPart@${AppConstants.synthesizedEmailDomain}',
  );
  return withoutEmails
      .split(' ')
      .map((token) => token.contains('/') ? templateRoute(token) : token)
      .join(' ');
}

String errorsBucket(int count) {
  if (count <= 0) return '0';
  if (count <= 3) return '1-3';
  if (count <= 10) return '4-10';
  return '10+';
}

String durationBucket(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 5) return '<5m';
  if (minutes <= 15) return '5-15m';
  if (minutes <= 30) return '15-30m';
  return '30m+';
}

String pendingBucket(int count) {
  if (count <= 1) return '1';
  if (count <= 5) return '2-5';
  if (count <= 20) return '6-20';
  return '20+';
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/unit/core/telemetry/pii_scrubber_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze --no-fatal-infos`
Expected: no errors or warnings in the new files.

- [ ] **Step 7: Commit**

```bash
git add lib/core/telemetry/pii_scrubber.dart test/unit/core/telemetry/pii_scrubber_test.dart
git commit -m "feat(telemetry): add pure PII scrubber and analytics buckets (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: TelemetryContext value object

**Files:**
- Create: `lib/core/telemetry/telemetry_context.dart`
- Test: `test/unit/core/telemetry/telemetry_context_test.dart`

**Interfaces:**
- Consumes: `templateRoute` from Task 1
- Produces: `TelemetryContext` with fields `userId`, `role`, `instituteId`, `route`, `connectivity`; `TelemetryContext.empty`; `TelemetryContext copyWith({...})`; `Map<String, String> toTags()`

- [ ] **Step 1: Write the failing test**

Create `test/unit/core/telemetry/telemetry_context_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';

void main() {
  test('empty context carries no identifying values', () {
    expect(TelemetryContext.empty.userId, isNull);
    expect(TelemetryContext.empty.role, isNull);
    expect(TelemetryContext.empty.toTags(), isEmpty);
  });

  test('context carries role institute and connectivity as tags', () {
    const context = TelemetryContext(
      userId: 'uid123',
      role: 'teacher',
      instituteId: 'inst456',
      route: '/students/:id',
      connectivity: 'offline',
    );

    expect(context.toTags(), {
      'role': 'teacher',
      'institute_id': 'inst456',
      'route': '/students/:id',
      'connectivity': 'offline',
    });
  });

  test('user id is not exposed as a tag', () {
    const context = TelemetryContext(userId: 'uid123');
    expect(context.toTags().values, isNot(contains('uid123')));
  });

  test('route is templated when the context is built', () {
    final context = TelemetryContext.empty.copyWith(
      route: '/students/aB3xY9kL2mN7pQ4rS8tU',
    );
    expect(context.route, '/students/:id');
  });

  test('copyWith preserves untouched fields', () {
    const original = TelemetryContext(userId: 'uid123', role: 'teacher');
    final updated = original.copyWith(connectivity: 'online');
    expect(updated.userId, 'uid123');
    expect(updated.role, 'teacher');
    expect(updated.connectivity, 'online');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/core/telemetry/telemetry_context_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/core/telemetry/telemetry_context.dart`:

```dart
import 'pii_scrubber.dart';

/// The complete, closed set of context that may accompany a telemetry event.
///
/// Deliberately NOT a `Map<String, dynamic>`: an open bag is exactly how a
/// student's name ends up in an error console. Adding a field here is a
/// reviewable act.
class TelemetryContext {
  const TelemetryContext({
    this.userId,
    this.role,
    this.instituteId,
    this.route,
    this.connectivity,
  });

  static const TelemetryContext empty = TelemetryContext();

  /// Opaque Firebase uid. Sent as the Sentry user id so a report can be
  /// correlated with Firestore documents; never exposed as a searchable tag.
  final String? userId;

  /// One of: superAdmin, supervisor, teacher, student, guardian.
  final String? role;
  final String? instituteId;

  /// Always templated (`/students/:id`), never a raw location.
  final String? route;

  /// One of: online, offline.
  final String? connectivity;

  TelemetryContext copyWith({
    String? userId,
    String? role,
    String? instituteId,
    String? route,
    String? connectivity,
  }) {
    return TelemetryContext(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      instituteId: instituteId ?? this.instituteId,
      route: route == null ? this.route : templateRoute(route),
      connectivity: connectivity ?? this.connectivity,
    );
  }

  Map<String, String> toTags() {
    return {
      if (role != null) 'role': role!,
      if (instituteId != null) 'institute_id': instituteId!,
      if (route != null) 'route': route!,
      if (connectivity != null) 'connectivity': connectivity!,
    };
  }
}
```

Note: the const constructor does not template `route`, so construct contexts through `copyWith` (or pass an already-templated route) — the test above pins both behaviours.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/core/telemetry/telemetry_context_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/telemetry_context.dart test/unit/core/telemetry/telemetry_context_test.dart
git commit -m "feat(telemetry): add closed TelemetryContext value object (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Analytics event taxonomy

**Files:**
- Create: `lib/core/telemetry/analytics_event.dart`
- Test: `test/unit/core/telemetry/analytics_event_test.dart`

**Interfaces:**
- Consumes: `errorsBucket`, `durationBucket`, `pendingBucket` from Task 1
- Produces: `sealed class AnalyticsEvent` with `String get name` and `Map<String, Object> get parameters`, and these subclasses: `LoginSucceeded(role)`, `LoginFailed(reasonCode)`, `SessionRecorded({sessionType, errorCount, duration, wasOffline})`, `SessionAbandoned(step)`, `AssessmentCompleted(result)`, `TalqeenCompleted()`, `HomePracticeLogged()`, `OfflineWriteQueued()`, `OfflineSyncCompleted(pendingCount)`

- [ ] **Step 1: Write the failing test**

Create `test/unit/core/telemetry/analytics_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';

void main() {
  test('a recorded session reports bucketed values only', () {
    final event = SessionRecorded(
      sessionType: 'hifz',
      errorCount: 7,
      duration: const Duration(minutes: 22),
      wasOffline: true,
    );

    expect(event.name, 'session_recorded');
    expect(event.parameters, {
      'session_type': 'hifz',
      'errors_bucket': '4-10',
      'duration_bucket': '15-30m',
      'was_offline': 1,
    });
  });

  test('an abandoned session reports the step it stopped at', () {
    final event = SessionAbandoned(step: 'errors_recorded');
    expect(event.name, 'session_abandoned');
    expect(event.parameters, {'step': 'errors_recorded'});
  });

  test('a successful login reports only the role', () {
    final event = LoginSucceeded(role: 'teacher');
    expect(event.name, 'login_succeeded');
    expect(event.parameters, {'role': 'teacher'});
  });

  test('a failed login reports a reason code and never a username', () {
    final event = LoginFailed(reasonCode: 'wrong_password');
    expect(event.parameters, {'reason_code': 'wrong_password'});
    expect(event.parameters.values.join(), isNot(contains('@')));
  });

  test('a completed offline sync reports a bucketed pending count', () {
    final event = OfflineSyncCompleted(pendingCount: 9);
    expect(event.parameters, {'pending_bucket': '6-20'});
  });

  test('events without parameters expose an empty map', () {
    expect(TalqeenCompleted().parameters, isEmpty);
    expect(HomePracticeLogged().name, 'home_practice_logged');
    expect(OfflineWriteQueued().name, 'offline_write_queued');
  });

  test('every event name fits the analytics naming limit', () {
    final events = <AnalyticsEvent>[
      LoginSucceeded(role: 'teacher'),
      LoginFailed(reasonCode: 'x'),
      SessionRecorded(
        sessionType: 'sard',
        errorCount: 0,
        duration: Duration.zero,
        wasOffline: false,
      ),
      SessionAbandoned(step: 'opened'),
      AssessmentCompleted(result: 'passed'),
      TalqeenCompleted(),
      HomePracticeLogged(),
      OfflineWriteQueued(),
      OfflineSyncCompleted(pendingCount: 1),
    ];

    for (final event in events) {
      expect(event.name.length, lessThanOrEqualTo(40));
      for (final key in event.parameters.keys) {
        expect(key.length, lessThanOrEqualTo(40));
      }
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/core/telemetry/analytics_event_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/core/telemetry/analytics_event.dart`:

```dart
import 'pii_scrubber.dart';

/// The complete set of product events the app may record.
///
/// Sealed so that adding an event is a deliberate, reviewable act, and so no
/// call site can invent an ad-hoc event carrying free-form (and possibly
/// identifying) values. Numeric values are always bucketed: raw counts and
/// durations are re-identifying in a small halaqa, and buckets answer every
/// product question we actually have.
sealed class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;
  Map<String, Object> get parameters;
}

final class LoginSucceeded extends AnalyticsEvent {
  const LoginSucceeded({required this.role});
  final String role;

  @override
  String get name => 'login_succeeded';

  @override
  Map<String, Object> get parameters => {'role': role};
}

final class LoginFailed extends AnalyticsEvent {
  const LoginFailed({required this.reasonCode});

  /// A stable code such as `wrong_password` or `network_error`. Never the
  /// username or the message returned by Firebase.
  final String reasonCode;

  @override
  String get name => 'login_failed';

  @override
  Map<String, Object> get parameters => {'reason_code': reasonCode};
}

final class SessionRecorded extends AnalyticsEvent {
  const SessionRecorded({
    required this.sessionType,
    required this.errorCount,
    required this.duration,
    required this.wasOffline,
  });

  /// One of: hifz, talqeen, sard.
  final String sessionType;
  final int errorCount;
  final Duration duration;
  final bool wasOffline;

  @override
  String get name => 'session_recorded';

  @override
  Map<String, Object> get parameters => {
    'session_type': sessionType,
    'errors_bucket': errorsBucket(errorCount),
    'duration_bucket': durationBucket(duration),
    'was_offline': wasOffline ? 1 : 0,
  };
}

final class SessionAbandoned extends AnalyticsEvent {
  const SessionAbandoned({required this.step});

  /// One of: opened, errors_recorded, saving.
  final String step;

  @override
  String get name => 'session_abandoned';

  @override
  Map<String, Object> get parameters => {'step': step};
}

final class AssessmentCompleted extends AnalyticsEvent {
  const AssessmentCompleted({required this.result});
  final String result;

  @override
  String get name => 'assessment_completed';

  @override
  Map<String, Object> get parameters => {'result': result};
}

final class TalqeenCompleted extends AnalyticsEvent {
  const TalqeenCompleted();

  @override
  String get name => 'talqeen_completed';

  @override
  Map<String, Object> get parameters => const {};
}

final class HomePracticeLogged extends AnalyticsEvent {
  const HomePracticeLogged();

  @override
  String get name => 'home_practice_logged';

  @override
  Map<String, Object> get parameters => const {};
}

final class OfflineWriteQueued extends AnalyticsEvent {
  const OfflineWriteQueued();

  @override
  String get name => 'offline_write_queued';

  @override
  Map<String, Object> get parameters => const {};
}

final class OfflineSyncCompleted extends AnalyticsEvent {
  const OfflineSyncCompleted({required this.pendingCount});
  final int pendingCount;

  @override
  String get name => 'offline_sync_completed';

  @override
  Map<String, Object> get parameters => {
    'pending_bucket': pendingBucket(pendingCount),
  };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/core/telemetry/analytics_event_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/telemetry/analytics_event.dart test/unit/core/telemetry/analytics_event_test.dart
git commit -m "feat(telemetry): add sealed analytics event taxonomy (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Ports, gate, and the no-op adapter

**Files:**
- Create: `lib/core/telemetry/error_reporter.dart`
- Create: `lib/core/telemetry/usage_analytics.dart`
- Create: `lib/core/telemetry/telemetry_gate.dart`
- Create: `lib/data/services/telemetry/noop_telemetry.dart`
- Test: `test/unit/core/telemetry/telemetry_gate_test.dart`
- Test: `test/unit/data/telemetry/noop_telemetry_test.dart`

**Interfaces:**
- Consumes: `TelemetryContext` (Task 2), `AnalyticsEvent` (Task 3)
- Produces:
  - `abstract interface class ErrorReporter` with `void recordError(Object error, StackTrace? stackTrace, {String? reason, bool fatal})`, `void addBreadcrumb(String message, {String? category})`, `void updateContext(TelemetryContext context)`
  - `abstract interface class UsageAnalytics` with `void record(AnalyticsEvent event)`, `void setUserProperties({required String role, required String instituteId})`, `void recordScreenView(String templatedRoute)`
  - `class TelemetryGate` with `bool get isOpen`, `void close()`, `void open()`
  - `class NoopErrorReporter implements ErrorReporter`, `class NoopUsageAnalytics implements UsageAnalytics`

- [ ] **Step 1: Write the failing tests**

Create `test/unit/core/telemetry/telemetry_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';

void main() {
  test('a gate opens by default when telemetry is permitted', () {
    expect(TelemetryGate(isOpen: true).isOpen, isTrue);
  });

  test('a closed gate stays closed until explicitly opened', () {
    final gate = TelemetryGate(isOpen: false);
    expect(gate.isOpen, isFalse);
    gate.open();
    expect(gate.isOpen, isTrue);
    gate.close();
    expect(gate.isOpen, isFalse);
  });
}
```

Create `test/unit/data/telemetry/noop_telemetry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/data/services/telemetry/noop_telemetry.dart';

void main() {
  test('the no-op reporter accepts every call without throwing', () {
    const reporter = NoopErrorReporter();
    expect(
      () => reporter.recordError(Exception('boom'), StackTrace.current),
      returnsNormally,
    );
    expect(() => reporter.addBreadcrumb('opened screen'), returnsNormally);
    expect(
      () => reporter.updateContext(TelemetryContext.empty),
      returnsNormally,
    );
  });

  test('the no-op analytics accepts every call without throwing', () {
    const analytics = NoopUsageAnalytics();
    expect(() => analytics.record(const TalqeenCompleted()), returnsNormally);
    expect(
      () => analytics.setUserProperties(role: 'teacher', instituteId: 'i1'),
      returnsNormally,
    );
    expect(() => analytics.recordScreenView('/students/:id'), returnsNormally);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/core/telemetry/telemetry_gate_test.dart test/unit/data/telemetry/noop_telemetry_test.dart`
Expected: FAIL — unresolved imports.

- [ ] **Step 3: Write the ports**

Create `lib/core/telemetry/error_reporter.dart`:

```dart
import 'telemetry_context.dart';

/// Reports failures to whatever error backend is configured.
///
/// Every implementation MUST be non-throwing: telemetry is never allowed to
/// become a source of failure, so internal exceptions are caught and dropped.
abstract interface class ErrorReporter {
  /// Records a failure. [reason] is a short, non-identifying description such
  /// as `provider studentStatsProvider failed`.
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  /// Adds a trail entry attached to subsequent reports.
  void addBreadcrumb(String message, {String? category});

  /// Replaces the context attached to subsequent reports.
  void updateContext(TelemetryContext context);
}
```

Create `lib/core/telemetry/usage_analytics.dart`:

```dart
import 'analytics_event.dart';

/// Records aggregate product usage.
///
/// Implementations MUST NOT set a per-user identifier: only [role] and
/// [instituteId] are permitted user properties. See the design spec — setting a
/// uid here would turn aggregate analytics into a behavioural profile of
/// minors.
abstract interface class UsageAnalytics {
  void record(AnalyticsEvent event);
  void setUserProperties({required String role, required String instituteId});

  /// [templatedRoute] must already be templated (`/students/:id`).
  void recordScreenView(String templatedRoute);
}
```

Create `lib/core/telemetry/telemetry_gate.dart`:

```dart
/// A mutable on/off switch consulted by every adapter before it emits.
///
/// Held as a single instance created in `main()` and shared by the adapters,
/// so the user's opt-out toggle takes effect immediately without an app
/// restart.
class TelemetryGate {
  TelemetryGate({required bool isOpen}) : _isOpen = isOpen;

  bool _isOpen;

  bool get isOpen => _isOpen;

  void open() => _isOpen = true;
  void close() => _isOpen = false;
}
```

- [ ] **Step 4: Write the no-op adapter**

Create `lib/data/services/telemetry/noop_telemetry.dart`:

```dart
import '../../../core/telemetry/analytics_event.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_context.dart';
import '../../../core/telemetry/usage_analytics.dart';

/// Selected in debug builds, in emulator mode, when no Sentry DSN is
/// configured, and in every test. Nothing leaves the device.
class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

class NoopUsageAnalytics implements UsageAnalytics {
  const NoopUsageAnalytics();

  @override
  void record(AnalyticsEvent event) {}

  @override
  void setUserProperties({
    required String role,
    required String instituteId,
  }) {}

  @override
  void recordScreenView(String templatedRoute) {}
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/unit/core/telemetry/ test/unit/data/telemetry/`
Expected: PASS, all tests green.

- [ ] **Step 6: Verify the ports stayed pure**

Run: `grep -rn "^import" lib/core/telemetry/ | grep -E "package:(flutter|firebase|sentry)"`
Expected: no output. If anything prints, a port has taken a framework dependency — fix it before committing.

- [ ] **Step 7: Commit**

```bash
git add lib/core/telemetry lib/data/services/telemetry test/unit/core/telemetry test/unit/data/telemetry
git commit -m "feat(telemetry): add ErrorReporter and UsageAnalytics ports with no-op adapter (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: Riverpod ProviderObserver

**Files:**
- Create: `lib/shared/providers/telemetry_provider_observer.dart`
- Test: `test/unit/shared/telemetry_provider_observer_test.dart`

**Interfaces:**
- Consumes: `ErrorReporter` (Task 4)
- Produces: `final class TelemetryProviderObserver extends ProviderObserver` with constructor `TelemetryProviderObserver(ErrorReporter reporter)`

This is the highest-leverage task in the plan. It captures every provider failure app-wide, including providers nobody remembered to add a `debugPrint` to.

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/telemetry_provider_observer_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/shared/providers/telemetry_provider_observer.dart';

class _RecordingReporter implements ErrorReporter {
  final List<({Object error, String? reason})> recorded = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    recorded.add((error: error, reason: reason));
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

final throwingProvider = Provider<int>(
  (ref) => throw StateError('halaqa unreachable'),
  name: 'throwingProvider',
);

void main() {
  test('a failing provider is reported to the error reporter', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(reporter)],
    );
    addTearDown(container.dispose);

    expect(() => container.read(throwingProvider), throwsStateError);

    expect(reporter.recorded, hasLength(1));
    expect(reporter.recorded.single.error, isA<StateError>());
    expect(reporter.recorded.single.reason, contains('throwingProvider'));
  });

  test('a succeeding provider reports nothing', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(reporter)],
    );
    addTearDown(container.dispose);

    final ok = Provider<int>((ref) => 7, name: 'okProvider');
    expect(container.read(ok), 7);
    expect(reporter.recorded, isEmpty);
  });

  test('a reporter that throws does not break the provider container', () {
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(_ThrowingReporter())],
    );
    addTearDown(container.dispose);

    expect(() => container.read(throwingProvider), throwsStateError);
  });
}

class _ThrowingReporter implements ErrorReporter {
  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    throw Exception('reporter is broken');
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/shared/telemetry_provider_observer_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/providers/telemetry_provider_observer.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/error_reporter.dart';

/// Routes every provider failure in the app to the [ErrorReporter].
///
/// This replaces the 62 per-screen `debugPrint('xProvider failed: $e')` calls
/// that preceded it. Those were both invisible in release builds and
/// incomplete — a provider with no `.when(error:)` branch reported nothing at
/// all. One observer covers every provider, including future ones.
///
/// `ProviderObserver` is an `abstract base class` in Riverpod 3, so this must
/// be `final`/`base`/`sealed` and use `extends`, not `implements`.
final class TelemetryProviderObserver extends ProviderObserver {
  TelemetryProviderObserver(this._reporter);

  final ErrorReporter _reporter;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // A broken reporter must never escalate into a broken container, so this
    // swallows its own failures.
    try {
      final name = context.provider.name ?? context.provider.runtimeType.toString();
      _reporter.recordError(error, stackTrace, reason: 'provider $name failed');
    } catch (_) {}
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/shared/telemetry_provider_observer_test.dart`
Expected: PASS, 3 tests.

If `providerDidFail` is not called for a synchronous `Provider` throw in this Riverpod version, check `didAddProvider` (which receives a `null` value when initialization threw) and adapt — but run the test first and let the failure tell you.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/providers/telemetry_provider_observer.dart test/unit/shared/telemetry_provider_observer_test.dart
git commit -m "feat(telemetry): capture every provider failure via ProviderObserver (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Sentry adapter

**Files:**
- Modify: `pubspec.yaml` (add `sentry_flutter`)
- Create: `lib/data/services/telemetry/sentry_error_reporter.dart`
- Test: `test/unit/data/telemetry/sentry_error_reporter_test.dart`

**Interfaces:**
- Consumes: `ErrorReporter`, `TelemetryContext`, `TelemetryGate`, `scrubMessage`
- Produces: `class SentryErrorReporter implements ErrorReporter` with constructor `SentryErrorReporter({required TelemetryGate gate, required SentrySink sink})`; `abstract interface class SentrySink` with `void captureException(Object error, StackTrace? stackTrace, String? reason, Map<String, String> tags, String? userId)`, `void breadcrumb(String message, String? category)`; `class LiveSentrySink implements SentrySink`

The `SentrySink` seam exists so the adapter's PII behaviour is testable without a network or a Sentry DSN. `LiveSentrySink` is the only untested code, and it contains no logic.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add sentry_flutter`
Expected: `pubspec.yaml` gains `sentry_flutter`, `pubspec.lock` updates.

- [ ] **Step 2: Write the failing test**

Create `test/unit/data/telemetry/sentry_error_reporter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/telemetry/sentry_error_reporter.dart';

class _FakeSink implements SentrySink {
  final List<String> captured = [];
  final List<String> breadcrumbs = [];
  Map<String, String> lastTags = const {};
  String? lastUserId;

  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  ) {
    captured.add('$error|$reason');
    lastTags = tags;
    lastUserId = userId;
  }

  @override
  void breadcrumb(String message, String? category) {
    breadcrumbs.add(message);
  }
}

void main() {
  test('a report never forwards a student synthetic email to the sink', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.recordError(
      Exception('no user for ahmad.ali@alrasikhoon.local'),
      StackTrace.current,
      reason: 'login failed for ahmad.ali@alrasikhoon.local',
    );

    expect(sink.captured.single, isNot(contains('ahmad.ali')));
    expect(sink.captured.single, contains('<redacted>'));
  });

  test('a report never forwards a raw document id to the sink', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.recordError(
      Exception('PERMISSION_DENIED on students/aB3xY9kL2mN7pQ4rS8tU'),
      null,
    );

    expect(sink.captured.single, isNot(contains('aB3xY9kL2mN7pQ4rS8tU')));
    expect(sink.captured.single, contains('students/:id'));
  });

  test('a closed gate suppresses every report and breadcrumb', () {
    final sink = _FakeSink();
    final gate = TelemetryGate(isOpen: false);
    final reporter = SentryErrorReporter(gate: gate, sink: sink);

    reporter.recordError(Exception('boom'), null);
    reporter.addBreadcrumb('opened screen');

    expect(sink.captured, isEmpty);
    expect(sink.breadcrumbs, isEmpty);

    gate.open();
    reporter.recordError(Exception('boom'), null);
    expect(sink.captured, hasLength(1));
  });

  test('context is forwarded as tags with the uid kept out of them', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.updateContext(
      const TelemetryContext(
        userId: 'uid123',
        role: 'teacher',
        instituteId: 'inst456',
        route: '/students/:id',
        connectivity: 'offline',
      ),
    );
    reporter.recordError(Exception('boom'), null);

    expect(sink.lastTags['role'], 'teacher');
    expect(sink.lastTags['connectivity'], 'offline');
    expect(sink.lastTags.values, isNot(contains('uid123')));
    expect(sink.lastUserId, 'uid123');
  });

  test('a sink failure is swallowed rather than propagated', () {
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: _ThrowingSink(),
    );
    expect(() => reporter.recordError(Exception('boom'), null), returnsNormally);
    expect(() => reporter.addBreadcrumb('x'), returnsNormally);
  });
}

class _ThrowingSink implements SentrySink {
  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  ) {
    throw Exception('sink is broken');
  }

  @override
  void breadcrumb(String message, String? category) {
    throw Exception('sink is broken');
  }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unit/data/telemetry/sentry_error_reporter_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 4: Write the implementation**

Create `lib/data/services/telemetry/sentry_error_reporter.dart`:

```dart
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/pii_scrubber.dart';
import '../../../core/telemetry/telemetry_context.dart';
import '../../../core/telemetry/telemetry_gate.dart';

/// The seam between the adapter's logic and the Sentry SDK, so the PII rules
/// can be tested without a DSN or a network.
abstract interface class SentrySink {
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  );
  void breadcrumb(String message, String? category);
}

class LiveSentrySink implements SentrySink {
  const LiveSentrySink();

  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (userId != null) {
          scope.setUser(SentryUser(id: userId));
        }
        for (final entry in tags.entries) {
          scope.setTag(entry.key, entry.value);
        }
        if (reason != null) {
          scope.setContexts('reason', reason);
        }
      },
    );
  }

  @override
  void breadcrumb(String message, String? category) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, category: category));
  }
}

/// Reports errors to Sentry, scrubbing every string on the way out and
/// honouring the [TelemetryGate].
class SentryErrorReporter implements ErrorReporter {
  SentryErrorReporter({required TelemetryGate gate, required SentrySink sink})
    : _gate = gate,
      _sink = sink;

  final TelemetryGate _gate;
  final SentrySink _sink;

  TelemetryContext _context = TelemetryContext.empty;

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_gate.isOpen) return;
    try {
      // The error object itself is stringified and scrubbed rather than passed
      // through: a FirebaseException's message routinely embeds document paths,
      // and UserModel.toString() embeds a username and a name.
      final scrubbed = scrubMessage(error.toString());
      final scrubbedReason = reason == null ? null : scrubMessage(reason);
      _sink.captureException(
        _ScrubbedError(scrubbed),
        stackTrace,
        scrubbedReason,
        _context.toTags(),
        _context.userId,
      );
    } catch (_) {}
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    if (!_gate.isOpen) return;
    try {
      _sink.breadcrumb(scrubMessage(message), category);
    } catch (_) {}
  }

  @override
  void updateContext(TelemetryContext context) {
    _context = context;
  }
}

/// Carries an already-scrubbed message to Sentry. Its `toString()` is what
/// Sentry renders, so nothing unscrubbed can reach the console through it.
class _ScrubbedError implements Exception {
  _ScrubbedError(this.message);
  final String message;

  @override
  String toString() => message;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/unit/data/telemetry/sentry_error_reporter_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Verify the Sentry API against the installed version**

Run: `flutter analyze --no-fatal-infos`
Expected: no errors. If `setContexts`, `withScope`, `SentryUser`, or `Breadcrumb` signatures differ in the installed version, read the real API at `~/.pub-cache/hosted/pub.dev/sentry_flutter-*/lib/` and `~/.pub-cache/hosted/pub.dev/sentry-*/lib/sentry.dart`, then adjust `LiveSentrySink` only. Do NOT change `SentryErrorReporter` or the tests — the seam exists precisely so SDK drift is confined to `LiveSentrySink`.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/services/telemetry/sentry_error_reporter.dart test/unit/data/telemetry/sentry_error_reporter_test.dart
git commit -m "feat(telemetry): add Sentry error reporter with PII scrubbing at the seam (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Adapter selection and app bootstrap

**Files:**
- Create: `lib/data/services/telemetry/telemetry_providers.dart`
- Modify: `lib/main.dart`
- Test: `test/unit/data/telemetry/telemetry_selection_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 4–6
- Produces: `bool telemetryIsPermitted({required bool isDebug, required bool isEmulator, required String dsn})`; `Future<ErrorReporter> createErrorReporter({required TelemetryGate gate, required String dsn})`; `final errorReporterProvider = Provider<ErrorReporter>((_) => throw UnimplementedError())` (overridden in `main`); `const String kSentryDsn = String.fromEnvironment('SENTRY_DSN')`

- [ ] **Step 1: Write the failing test**

Create `test/unit/data/telemetry/telemetry_selection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';

void main() {
  const dsn = 'https://examplePublicKey@o0.ingest.sentry.io/0';

  test('telemetry is permitted in a release build with a configured dsn', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: false, dsn: dsn),
      isTrue,
    );
  });

  test('telemetry is disabled in debug builds', () {
    expect(
      telemetryIsPermitted(isDebug: true, isEmulator: false, dsn: dsn),
      isFalse,
    );
  });

  test('telemetry is disabled in emulator mode', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: true, dsn: dsn),
      isFalse,
    );
  });

  test('telemetry is disabled when no dsn is configured', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: false, dsn: ''),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/telemetry/telemetry_selection_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/data/services/telemetry/telemetry_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/config/firebase_emulator_config.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/usage_analytics.dart';
import 'noop_telemetry.dart';
import 'sentry_error_reporter.dart';

/// Supplied at build time: `--dart-define=SENTRY_DSN=...`. Empty by default so
/// local runs and CI (which have no secret) fall back to the no-op adapter.
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Pure predicate so the four disable conditions are directly testable.
bool telemetryIsPermitted({
  required bool isDebug,
  required bool isEmulator,
  required String dsn,
}) {
  if (isDebug) return false;
  if (isEmulator) return false;
  if (dsn.isEmpty) return false;
  return true;
}

/// Initialises Sentry and returns the live reporter, or returns the no-op
/// reporter when telemetry is not permitted. Never throws: an initialisation
/// failure degrades to no-op rather than blocking startup.
Future<ErrorReporter> createErrorReporter({
  required TelemetryGate gate,
  required String dsn,
}) async {
  final permitted = telemetryIsPermitted(
    isDebug: kDebugMode,
    isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
    dsn: dsn,
  );
  if (!permitted) return const NoopErrorReporter();

  try {
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      // Student names appear on screen in nearly every view.
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      options.sendDefaultPii = false;
      // A closed gate must suppress SDK-captured native events too, not just
      // the ones this app reports explicitly.
      options.beforeSend = (event, hint) => gate.isOpen ? event : null;
    });
    return SentryErrorReporter(gate: gate, sink: const LiveSentrySink());
  } catch (_) {
    return const NoopErrorReporter();
  }
}

/// Overridden in `main()` with the instance created before `runApp`.
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => throw UnimplementedError('errorReporterProvider must be overridden'),
);

/// Overridden in `main()`. Replaced with the live adapter in Task 11.
final usageAnalyticsProvider = Provider<UsageAnalytics>(
  (ref) => const NoopUsageAnalytics(),
);

/// Overridden in `main()` with the single shared gate.
final telemetryGateProvider = Provider<TelemetryGate>(
  (ref) => throw UnimplementedError('telemetryGateProvider must be overridden'),
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/data/telemetry/telemetry_selection_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Wire the bootstrap in main.dart**

In `lib/main.dart`, add these imports alongside the existing ones:

```dart
import 'package:flutter/foundation.dart';
import 'core/telemetry/telemetry_gate.dart';
import 'data/services/telemetry/telemetry_providers.dart';
import 'shared/providers/telemetry_provider_observer.dart';
```

Then, after the existing `final sharedPreferences = results[1] as SharedPreferences;` line and before `runApp(`, insert:

```dart
  // Telemetry is created before runApp so the ProviderObserver can be handed
  // to ProviderScope, and so an uncaught error during the first frame is
  // already covered. SharedPreferences is already loaded above, so the user's
  // opt-out is known without a second async hop.
  final telemetryGate = TelemetryGate(
    isOpen: sharedPreferences.getBool('telemetry_enabled') ?? true,
  );
  final errorReporter = await createErrorReporter(
    gate: telemetryGate,
    dsn: kSentryDsn,
  );

  // Widget build/layout errors. presentError keeps the normal red-screen and
  // console behaviour intact for developers.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    errorReporter.recordError(
      details.exception,
      details.stack,
      // details.context can render widget text; the library name cannot.
      reason: 'flutter error in ${details.library}',
    );
  };

  // Uncaught async errors that escape to the platform.
  PlatformDispatcher.instance.onError = (error, stack) {
    errorReporter.recordError(error, stack, fatal: true);
    return true;
  };
```

Then change the `runApp` call to add the observer and the two overrides:

```dart
  runApp(
    ProviderScope(
      observers: [TelemetryProviderObserver(errorReporter)],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionBoxProvider.overrideWithValue(sessionBox),
        errorReporterProvider.overrideWithValue(errorReporter),
        telemetryGateProvider.overrideWithValue(telemetryGate),
      ],
      child: const AlRasikhoonApp(),
    ),
  );
```

`PlatformDispatcher` comes from `dart:ui`; if the analyzer cannot resolve it, add `import 'dart:ui';`.

- [ ] **Step 6: Verify the app still builds and the suite is green**

Run: `flutter analyze --no-fatal-infos`
Expected: no errors.

Run: `flutter test test/`
Expected: PASS — the whole existing suite, unchanged. Telemetry is no-op in tests because `kDebugMode` is true and the DSN is empty.

- [ ] **Step 7: Commit**

```bash
git add lib/data/services/telemetry/telemetry_providers.dart lib/main.dart test/unit/data/telemetry/telemetry_selection_test.dart
git commit -m "feat(telemetry): install global error handlers and select adapter at startup (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Route and connectivity breadcrumbs

**Files:**
- Create: `lib/shared/providers/telemetry_context_provider.dart`
- Modify: `lib/app.dart`
- Test: `test/unit/shared/telemetry_context_provider_test.dart`

**Interfaces:**
- Consumes: `errorReporterProvider`, `usageAnalyticsProvider`, `currentUserProvider`, `isConnectedProvider`, `TelemetryContext`, `templateRoute`
- Produces: `final telemetryContextControllerProvider = Provider<void>(...)` — watched once from the app root, exactly like the existing `offlineSyncControllerProvider`

Route breadcrumbs are attached by listening to the router rather than by a `NavigatorObserver`, because `go_router` route names are not reliably present in `Route.settings`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/shared/telemetry_context_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/shared/providers/connectivity_provider.dart';
import 'package:al_rasikhoon/shared/providers/telemetry_context_provider.dart';

class _RecordingReporter implements ErrorReporter {
  final List<TelemetryContext> contexts = [];
  final List<String> breadcrumbs = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void addBreadcrumb(String message, {String? category}) {
    breadcrumbs.add(message);
  }

  @override
  void updateContext(TelemetryContext context) {
    contexts.add(context);
  }
}

void main() {
  test('losing connectivity updates the context and leaves a breadcrumb', () {
    final reporter = _RecordingReporter();
    final connected = StateProvider<bool>((ref) => true);

    final container = ProviderContainer(
      overrides: [
        errorReporterProvider.overrideWithValue(reporter),
        isConnectedProvider.overrideWith((ref) => ref.watch(connected)),
      ],
    );
    addTearDown(container.dispose);

    container.read(telemetryContextControllerProvider);
    container.read(connected.notifier).state = false;

    expect(reporter.contexts.last.connectivity, 'offline');
    expect(reporter.breadcrumbs.last, contains('offline'));
  });

  test('a route change is recorded as a templated route', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
    );
    addTearDown(container.dispose);

    container.read(telemetryContextControllerProvider);
    container
        .read(telemetryRouteReporterProvider)
        .reportRoute('/students/aB3xY9kL2mN7pQ4rS8tU');

    expect(reporter.contexts.last.route, '/students/:id');
    expect(reporter.breadcrumbs.last, contains('/students/:id'));
    expect(reporter.breadcrumbs.last, isNot(contains('aB3xY9kL2')));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/shared/telemetry_context_provider_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/providers/telemetry_context_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/error_reporter.dart';
import '../../core/telemetry/telemetry_context.dart';
import '../../data/services/telemetry/telemetry_providers.dart';
import 'connectivity_provider.dart';
import 'user_provider.dart';

/// Owns the single mutable [TelemetryContext] and keeps it current.
///
/// Connectivity is the field that matters most for this app: teachers work in
/// halaqas that may have no signal, so "it failed" and "it failed offline" are
/// different bugs. Recording transitions as breadcrumbs makes the difference
/// visible in every subsequent report.
class TelemetryRouteReporter {
  TelemetryRouteReporter(this._reporter, this._read, this._write);

  final ErrorReporter _reporter;
  final TelemetryContext Function() _read;
  final void Function(TelemetryContext) _write;

  void reportRoute(String location) {
    final updated = _read().copyWith(route: location);
    _write(updated);
    _reporter.updateContext(updated);
    _reporter.addBreadcrumb('navigated to ${updated.route}', category: 'navigation');
  }
}

final _contextHolderProvider = Provider<_ContextHolder>(
  (ref) => _ContextHolder(),
);

class _ContextHolder {
  TelemetryContext value = TelemetryContext.empty;
}

final telemetryRouteReporterProvider = Provider<TelemetryRouteReporter>((ref) {
  final holder = ref.watch(_contextHolderProvider);
  return TelemetryRouteReporter(
    ref.watch(errorReporterProvider),
    () => holder.value,
    (updated) => holder.value = updated,
  );
});

/// Watched once from the app root, mirroring [offlineSyncControllerProvider].
final telemetryContextControllerProvider = Provider<void>((ref) {
  final reporter = ref.watch(errorReporterProvider);
  final holder = ref.watch(_contextHolderProvider);

  void push(TelemetryContext updated) {
    holder.value = updated;
    reporter.updateContext(updated);
  }

  ref.listen(currentUserProvider, (previous, next) {
    push(
      holder.value.copyWith(
        userId: next?.id,
        role: next?.role.name,
        instituteId: next?.instituteId,
      ),
    );
  }, fireImmediately: true);

  ref.listen(isConnectedProvider, (previous, next) {
    final label = next ? 'online' : 'offline';
    push(holder.value.copyWith(connectivity: label));
    reporter.addBreadcrumb('connectivity became $label', category: 'connectivity');
  }, fireImmediately: true);
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/shared/telemetry_context_provider_test.dart`
Expected: PASS, 2 tests.

If `ref.listen(..., fireImmediately: true)` is not available on a `Provider` in Riverpod 3.1.0, check the signature at `~/.pub-cache/hosted/pub.dev/riverpod-3.1.0/lib/src/core/ref.dart` and drop the argument, seeding the initial value with an explicit `push(...)` call instead.

- [ ] **Step 5: Activate it from the app root**

In `lib/app.dart`, add the import:

```dart
import 'shared/providers/telemetry_context_provider.dart';
```

and add this line immediately after the existing `ref.watch(offlineSyncControllerProvider);`:

```dart
    // Keeps role, institute, route and connectivity attached to every report.
    ref.watch(telemetryContextControllerProvider);
```

- [ ] **Step 6: Report route changes from the router**

In `lib/routing/app_router.dart`, locate the `routerProvider` definition (`grep -n "routerProvider" lib/routing/app_router.dart`). Immediately after the `GoRouter(...)` instance is constructed and before it is returned, add:

```dart
  // go_router does not reliably populate Route.settings.name, so route
  // breadcrumbs come from the delegate rather than a NavigatorObserver.
  final routeReporter = ref.read(telemetryRouteReporterProvider);
  router.routerDelegate.addListener(() {
    routeReporter.reportRoute(router.state.matchedLocation);
  });
```

adding the import `import '../shared/providers/telemetry_context_provider.dart';`.

Run: `flutter analyze --no-fatal-infos`
Expected: no errors. If `router.state` or `matchedLocation` does not exist in `go_router` 17, read `~/.pub-cache/hosted/pub.dev/go_router-17*/lib/src/router.dart` for the current accessor and use it — the location string is the only thing needed.

- [ ] **Step 7: Run the full suite and commit**

Run: `flutter test test/`
Expected: PASS.

```bash
git add lib/shared/providers/telemetry_context_provider.dart lib/app.dart lib/routing/app_router.dart test/unit/shared/telemetry_context_provider_test.dart
git commit -m "feat(telemetry): attach role, route and connectivity to every report (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Remove the 62 debugPrint calls and guard against their return

**Files:**
- Modify: every file under `lib/` containing `debugPrint`
- Test: `test/unit/core/telemetry/no_debug_print_guard_test.dart`

**Interfaces:**
- Consumes: the `ProviderObserver` from Task 5, which now covers every one of these call sites
- Produces: nothing consumed by later tasks

Each of these calls sits in a `.when(error:)` branch and reports a provider failure that the observer now captures — including for providers that never had such a branch. They are dead weight in release builds, where `debugPrint` is a no-op.

- [ ] **Step 1: Write the failing guard test**

Create `test/unit/core/telemetry/no_debug_print_guard_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no debugPrint survives under lib because telemetry replaced it', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('debugPrint(')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Provider failures are captured by TelemetryProviderObserver and '
          'errors by ErrorReporter. debugPrint is a no-op in release builds, '
          'so it reports nothing in production. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/core/telemetry/no_debug_print_guard_test.dart`
Expected: FAIL, listing 62 offenders.

- [ ] **Step 3: List every offending file**

Run: `grep -rln --include='*.dart' 'debugPrint' lib | sort`
Expected: roughly 20 files. Work through them one at a time.

- [ ] **Step 4: Remove each call**

For each occurrence, delete the `debugPrint(...)` statement. Three shapes appear:

Shape 1 — a statement inside a block, delete the statement only:

```dart
      } catch (e) {
        debugPrint('assignSupervisorToInstitute failed: $e');   // delete this line
        if (!context.mounted) return;
```

Shape 2 — the sole body of an error callback, replace the body with nothing while keeping the callback, since the widget still needs to build an error state:

```dart
      error: (e, _) {
        debugPrint('institutesProvider failed: $e');   // delete this line
        return const ErrorState();                      // keep
      },
```

Shape 3 — the callback exists only to print. Collapse it to the widget it returns:

```dart
      // before
      error: (e, st) {
        debugPrint('homeAssignmentProvider failed: $error\n$stackTrace');
        return const SizedBox.shrink();
      },
      // after
      error: (e, st) => const SizedBox.shrink(),
```

After removing the calls from a file, delete any `import 'package:flutter/foundation.dart';` that is now unused. Do NOT remove `package:flutter/material.dart` imports — `debugPrint` is re-exported from there and the file will still need Material.

- [ ] **Step 5: Run the guard test and the analyzer**

Run: `flutter test test/unit/core/telemetry/no_debug_print_guard_test.dart`
Expected: PASS.

Run: `flutter analyze --no-fatal-infos`
Expected: no errors, and no `unused_import` warnings.

- [ ] **Step 6: Run the full suite**

Run: `flutter test test/`
Expected: PASS. Any failure here means a deletion removed more than the print statement — re-read the diff for that file.

- [ ] **Step 7: Commit**

```bash
git add -A lib test/unit/core/telemetry/no_debug_print_guard_test.dart
git commit -m "refactor(telemetry): drop 62 release-invisible debugPrint calls (al_rasikhoon-ciba)

Provider failures now reach Sentry through TelemetryProviderObserver, which
also covers the providers that never had a debugPrint at all. A guard test
keeps them from returning.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Report swallowed repository failures as non-fatals

**Files:**
- Modify: the 8 files under `lib/data/` containing a swallowing `catch`
- Test: `test/unit/data/telemetry/repository_non_fatal_test.dart`

**Interfaces:**
- Consumes: `ErrorReporter`, `errorReporterProvider` (Task 7)
- Produces: an optional `ErrorReporter? errorReporter` constructor parameter on each affected repository/service, defaulting to `const NoopErrorReporter()`

`ProviderObserver` (Task 5) only sees failures that **escape** a provider. A `catch` that swallows and returns a fallback never reaches it, so these 8 sites are invisible even after Task 9. They matter disproportionately here: they are exactly the offline-cache fallbacks, so a silently-degrading offline path would otherwise look identical to a healthy one.

- [ ] **Step 1: Find every swallowing catch**

Run: `grep -rn --include='*.dart' -A4 'catch (' lib/data`
Expected: 8 catch sites. Note which file and line each is in, and confirm none of them `rethrow` — a `rethrow` site is already covered by the observer and must be left alone.

- [ ] **Step 2: Write the failing test**

Create `test/unit/data/telemetry/repository_non_fatal_test.dart`. Pick the first swallowing catch found in Step 1, read its enclosing method, and write a test that drives that method into its failure path with a `FakeFirebaseFirestore` (or by passing a deliberately broken collaborator), asserting the reporter saw it:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';

class RecordingReporter implements ErrorReporter {
  final List<String> reasons = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    reasons.add(reason ?? error.toString());
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

void main() {
  test('a swallowed repository failure is still reported as non-fatal', () {
    final reporter = RecordingReporter();
    // Construct the repository under test with `errorReporter: reporter`,
    // drive the method into its catch branch, and assert the fallback value is
    // still returned to the caller.
    expect(reporter.reasons, hasLength(1));
  });

  test('a repository built without a reporter still works', () {
    // Constructing with no errorReporter must not throw — every existing test
    // in the suite relies on this.
  });
}
```

Fill both test bodies with the real repository and method identified in Step 1. Do not leave them as comments.

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unit/data/telemetry/repository_non_fatal_test.dart`
Expected: FAIL — the constructor has no `errorReporter` parameter.

- [ ] **Step 4: Inject the reporter**

For each affected class, add the parameter as **optional with a no-op default**, so no existing test that constructs the class needs to change:

```dart
  final ErrorReporter _errorReporter;

  ExampleRepository({
    // ...existing optional parameters, unchanged...
    ErrorReporter? errorReporter,
  }) : // ...existing initialisers, unchanged...
       _errorReporter = errorReporter ?? const NoopErrorReporter();
```

adding the imports:

```dart
import '../../core/telemetry/error_reporter.dart';
import '../services/telemetry/noop_telemetry.dart';
```

(adjust the relative depth for files under `lib/data/services/`).

Update each class's Riverpod provider to pass `errorReporter: ref.watch(errorReporterProvider)`, importing `../services/telemetry/telemetry_providers.dart`.

- [ ] **Step 5: Report from each catch**

In each of the 8 catch blocks, add a report as the first statement, keeping the existing fallback behaviour exactly as it is:

```dart
    } catch (e, stackTrace) {
      _errorReporter.recordError(
        e,
        stackTrace,
        reason: 'ExampleRepository.methodName fell back',
      );
      // ...existing fallback, unchanged...
    }
```

If a catch currently binds no stack trace (`catch (e)`), widen it to `catch (e, stackTrace)`. If it binds nothing (`catch (_)`), widen it to `catch (e, stackTrace)`. **Never** interpolate a model object into `reason` — `UserModel.toString()` contains a username and a name.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/unit/data/telemetry/repository_non_fatal_test.dart`
Expected: PASS.

Run: `flutter test test/`
Expected: PASS — the whole suite. A failure here means a constructor parameter was made required rather than optional.

Run: `flutter analyze --no-fatal-infos`
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add lib/data test/unit/data/telemetry/repository_non_fatal_test.dart
git commit -m "feat(telemetry): report swallowed repository failures as non-fatals (al_rasikhoon-ciba)

These 8 catch sites return an offline fallback without rethrowing, so
ProviderObserver never sees them and a silently-degrading offline path looked
identical to a healthy one.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Firebase Analytics adapter

**Files:**
- Modify: `pubspec.yaml` (add `firebase_analytics`)
- Create: `lib/data/services/telemetry/firebase_usage_analytics.dart`
- Modify: `lib/data/services/telemetry/telemetry_providers.dart`
- Modify: `lib/main.dart`
- Test: `test/unit/data/telemetry/firebase_usage_analytics_test.dart`

**Interfaces:**
- Consumes: `UsageAnalytics`, `AnalyticsEvent`, `TelemetryGate`
- Produces: `abstract interface class AnalyticsSink` with `void logEvent(String name, Map<String, Object> parameters)` and `void setUserProperty(String name, String value)`; `class LiveAnalyticsSink implements AnalyticsSink`; `class FirebaseUsageAnalytics implements UsageAnalytics` with constructor `FirebaseUsageAnalytics({required TelemetryGate gate, required AnalyticsSink sink})`

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add firebase_analytics`
Expected: `pubspec.yaml` and `pubspec.lock` update.

- [ ] **Step 2: Write the failing test**

Create `test/unit/data/telemetry/firebase_usage_analytics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/telemetry/firebase_usage_analytics.dart';

class _FakeSink implements AnalyticsSink {
  final List<({String name, Map<String, Object> parameters})> events = [];
  final Map<String, String> properties = {};

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    events.add((name: name, parameters: parameters));
  }

  @override
  void setUserProperty(String name, String value) {
    properties[name] = value;
  }
}

void main() {
  test('a recorded event reaches the sink with bucketed parameters', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(gate: TelemetryGate(isOpen: true), sink: sink)
        .record(const SessionAbandoned(step: 'saving'));

    expect(sink.events.single.name, 'session_abandoned');
    expect(sink.events.single.parameters, {'step': 'saving'});
  });

  test('user properties carry role and institute but never a user id', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(gate: TelemetryGate(isOpen: true), sink: sink)
        .setUserProperties(role: 'teacher', instituteId: 'inst456');

    expect(sink.properties, {'role': 'teacher', 'institute_id': 'inst456'});
    expect(sink.properties.keys, isNot(contains('user_id')));
  });

  test('a closed gate suppresses every event', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(gate: TelemetryGate(isOpen: false), sink: sink)
      ..record(const TalqeenCompleted())
      ..setUserProperties(role: 'teacher', instituteId: 'i1')
      ..recordScreenView('/students/:id');

    expect(sink.events, isEmpty);
    expect(sink.properties, isEmpty);
  });

  test('a screen view is templated before it reaches the sink', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(gate: TelemetryGate(isOpen: true), sink: sink)
        .recordScreenView('/students/aB3xY9kL2mN7pQ4rS8tU');

    expect(sink.events.single.parameters['screen_name'], '/students/:id');
  });

  test('a sink failure is swallowed rather than propagated', () {
    final analytics = FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: _ThrowingSink(),
    );
    expect(() => analytics.record(const TalqeenCompleted()), returnsNormally);
  });
}

class _ThrowingSink implements AnalyticsSink {
  @override
  void logEvent(String name, Map<String, Object> parameters) {
    throw Exception('sink is broken');
  }

  @override
  void setUserProperty(String name, String value) {
    throw Exception('sink is broken');
  }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unit/data/telemetry/firebase_usage_analytics_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 4: Write the implementation**

Create `lib/data/services/telemetry/firebase_usage_analytics.dart`:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/telemetry/analytics_event.dart';
import '../../../core/telemetry/pii_scrubber.dart';
import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/usage_analytics.dart';

/// The seam between this adapter and the Firebase SDK, so the privacy rules
/// are testable without a Firebase app.
abstract interface class AnalyticsSink {
  void logEvent(String name, Map<String, Object> parameters);
  void setUserProperty(String name, String value);
}

class LiveAnalyticsSink implements AnalyticsSink {
  const LiveAnalyticsSink();

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  @override
  void setUserProperty(String name, String value) {
    FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
  }
}

/// Records aggregate product usage.
///
/// Deliberately never calls `setUserId`. Aggregate data answers "where do
/// teachers get stuck" without building a per-child behavioural profile — see
/// the design spec's privacy section.
class FirebaseUsageAnalytics implements UsageAnalytics {
  const FirebaseUsageAnalytics({
    required TelemetryGate gate,
    required AnalyticsSink sink,
  }) : _gate = gate,
       _sink = sink;

  final TelemetryGate _gate;
  final AnalyticsSink _sink;

  @override
  void record(AnalyticsEvent event) {
    if (!_gate.isOpen) return;
    try {
      _sink.logEvent(event.name, event.parameters);
    } catch (_) {}
  }

  @override
  void setUserProperties({
    required String role,
    required String instituteId,
  }) {
    if (!_gate.isOpen) return;
    try {
      _sink.setUserProperty('role', role);
      _sink.setUserProperty('institute_id', instituteId);
    } catch (_) {}
  }

  @override
  void recordScreenView(String templatedRoute) {
    if (!_gate.isOpen) return;
    try {
      _sink.logEvent('screen_view', {
        'screen_name': templateRoute(templatedRoute),
      });
    } catch (_) {}
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/unit/data/telemetry/firebase_usage_analytics_test.dart`
Expected: PASS, 5 tests.

Run: `flutter analyze --no-fatal-infos`
Expected: no errors. If `FirebaseAnalytics.logEvent`'s `parameters` type differs in the installed version (it has historically been `Map<String, Object>`), adjust `LiveAnalyticsSink` only.

- [ ] **Step 6: Select the adapter at startup**

In `lib/data/services/telemetry/telemetry_providers.dart`, add the import `import 'firebase_usage_analytics.dart';` and add this function:

```dart
/// Analytics has no separate initialisation and no DSN; it rides the same
/// permission predicate as the error reporter.
UsageAnalytics createUsageAnalytics({
  required TelemetryGate gate,
  required String dsn,
}) {
  final permitted = telemetryIsPermitted(
    isDebug: kDebugMode,
    isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
    dsn: dsn,
  );
  if (!permitted) return const NoopUsageAnalytics();
  return FirebaseUsageAnalytics(gate: gate, sink: const LiveAnalyticsSink());
}
```

In `lib/main.dart`, after the `errorReporter` is created, add:

```dart
  final usageAnalytics = createUsageAnalytics(gate: telemetryGate, dsn: kSentryDsn);
```

and add to the `ProviderScope` overrides:

```dart
        usageAnalyticsProvider.overrideWithValue(usageAnalytics),
```

- [ ] **Step 7: Run the full suite and commit**

Run: `flutter test test/`
Expected: PASS.

```bash
git add pubspec.yaml pubspec.lock lib/data/services/telemetry lib/main.dart test/unit/data/telemetry/firebase_usage_analytics_test.dart
git commit -m "feat(telemetry): add Firebase Analytics adapter with no user id (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: Instrument the product events

**Files:**
- Modify: `lib/data/repositories/session_repository.dart` (constructor at line 27, provider at line 833, `createSessionRecord` at 117, `createTalqeenRecord` at 211, `createSardRecord` at 382, `createExamRecord` at 480)
- Modify: `lib/data/repositories/home_practice_repository.dart` (`createHomePractice` at line 35)
- Modify: `lib/data/repositories/auth_repository.dart` (`signInWithUsernameAndPassword` at line 107)
- Modify: `lib/shared/providers/telemetry_context_provider.dart`
- Test: `test/unit/data/telemetry/session_instrumentation_test.dart`

**Interfaces:**
- Consumes: `UsageAnalytics`, `usageAnalyticsProvider`, the event classes from Task 3
- Produces: `SessionRepository({..., UsageAnalytics? analytics})` and the equivalent optional parameter on `HomePracticeRepository` and `AuthRepository`

The repository is the right seam: every caller of a write goes through it, so one insertion point covers all screens. The parameter is **optional with a no-op default**, so all existing repository tests keep working unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/unit/data/telemetry/session_instrumentation_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/usage_analytics.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';

class _RecordingAnalytics implements UsageAnalytics {
  final List<AnalyticsEvent> events = [];

  @override
  void record(AnalyticsEvent event) => events.add(event);

  @override
  void setUserProperties({
    required String role,
    required String instituteId,
  }) {}

  @override
  void recordScreenView(String templatedRoute) {}
}

void main() {
  test('a repository built without analytics still works', () {
    expect(
      () => SessionRepository(firestore: FakeFirebaseFirestore()),
      returnsNormally,
    );
  });

  test('an analytics-enabled repository exposes the injected recorder', () {
    final analytics = _RecordingAnalytics();
    final repository = SessionRepository(
      firestore: FakeFirebaseFirestore(),
      analytics: analytics,
    );
    expect(repository, isNotNull);
    expect(analytics.events, isEmpty);
  });
}
```

Then extend this file with a test that calls `createSardRecord` and asserts a `SessionRecorded` event was emitted. Read the real signature first:

Run: `sed -n '382,435p' lib/data/repositories/session_repository.dart`

Write the call with that exact signature, then assert:

```dart
    expect(analytics.events.whereType<SessionRecorded>(), hasLength(1));
    expect(
      analytics.events.whereType<SessionRecorded>().single.sessionType,
      'sard',
    );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/telemetry/session_instrumentation_test.dart`
Expected: FAIL — `SessionRepository` has no named parameter `analytics`.

- [ ] **Step 3: Add the optional dependency to SessionRepository**

**If Task 10 already added an `ErrorReporter? errorReporter` parameter to this
constructor and its provider, keep it and add `analytics` alongside it.** The
code below shows the constructor as it looks without Task 10's parameter — do
not paste it over a constructor that already has one, or you will silently drop
error reporting.

In `lib/data/repositories/session_repository.dart`, add the imports:

```dart
import '../../core/telemetry/analytics_event.dart';
import '../../core/telemetry/usage_analytics.dart';
import '../services/telemetry/noop_telemetry.dart';
import '../services/telemetry/telemetry_providers.dart';
```

Change the field block and constructor (currently lines 20–29) to:

```dart
  final FirebaseFirestore _firestore;

  /// Where reads resolve from — offline they pin to the local cache instead
  /// of waiting out a doomed server attempt (al_rasikhoon-gy4).
  final FirestoreReadSource _read;

  /// Optional with a no-op default so every existing test constructing this
  /// repository keeps working untouched.
  final UsageAnalytics _analytics;

  SessionRepository({
    FirebaseFirestore? firestore,
    FirestoreReadSource? readSource,
    UsageAnalytics? analytics,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _read = readSource ?? const FirestoreReadSource.alwaysOnline(),
       _analytics = analytics ?? const NoopUsageAnalytics();
```

Update the provider at line 833:

```dart
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(
    firestore: ref.watch(firestoreProvider),
    readSource: ref.watch(firestoreReadSourceProvider),
    analytics: ref.watch(usageAnalyticsProvider),
  );
});
```

- [ ] **Step 4: Emit an event from each write**

At the end of `createSessionRecord` (line 117), immediately before its `return`, add:

```dart
    _analytics.record(
      SessionRecorded(
        sessionType: 'hifz',
        errorCount: record.totalErrors,
        duration: record.duration ?? Duration.zero,
        wasOffline: !_read.isOnline,
      ),
    );
```

Run `sed -n '117,210p' lib/data/repositories/session_repository.dart` first and use the real field names on the returned record for `errorCount` and `duration`; if the record carries no duration, pass `Duration.zero`. Check `FirestoreReadSource` for the correct online accessor with `grep -n "bool" lib/data/services/firestore_read_source.dart` — if there is no `isOnline`, pass `wasOffline: false` and note it in the commit body.

Repeat the same insertion with `sessionType: 'talqeen'` in `createTalqeenRecord` (line 211) and `sessionType: 'sard'` in `createSardRecord` (line 382).

In `createExamRecord` (line 480), before the `return`, add instead:

```dart
    _analytics.record(AssessmentCompleted(result: record.evaluation.name));
```

using the real result field name from `sed -n '480,533p' lib/data/repositories/session_repository.dart`.

- [ ] **Step 5: Instrument home practice and login**

Apply the same optional-parameter pattern to `HomePracticeRepository` (`lib/data/repositories/home_practice_repository.dart`), and emit `const HomePracticeLogged()` at the end of `createHomePractice` (line 35). Update its provider to pass `analytics: ref.watch(usageAnalyticsProvider)`.

Apply the pattern to `AuthRepository` (`lib/data/repositories/auth_repository.dart`). In `signInWithUsernameAndPassword` (line 107), emit on success:

```dart
      _analytics.record(LoginSucceeded(role: user.role.name));
```

and in its `catch`, emit a **code**, never the exception text or the username:

```dart
      _analytics.record(
        LoginFailed(
          reasonCode: e is FirebaseAuthException ? e.code : 'unknown_error',
        ),
      );
```

- [ ] **Step 6: Set the user properties when the user is known**

In `lib/shared/providers/telemetry_context_provider.dart`, inside `telemetryContextControllerProvider`, add `final analytics = ref.watch(usageAnalyticsProvider);` next to the reporter, and inside the `currentUserProvider` listener add:

```dart
    if (next != null) {
      analytics.setUserProperties(
        role: next.role.name,
        instituteId: next.instituteId ?? 'none',
      );
    }
```

Also add a screen-view record in `TelemetryRouteReporter.reportRoute`, after the breadcrumb:

```dart
    _analytics.recordScreenView(updated.route ?? '/');
```

adding `UsageAnalytics _analytics` as a constructor parameter of `TelemetryRouteReporter` and passing `ref.watch(usageAnalyticsProvider)` from `telemetryRouteReporterProvider`. Update the existing test in `test/unit/shared/telemetry_context_provider_test.dart` so its container overrides `usageAnalyticsProvider` with `const NoopUsageAnalytics()`.

- [ ] **Step 7: Run the full suite**

Run: `flutter test test/`
Expected: PASS. If a repository test fails on the new constructor parameter, the parameter was made required — make it optional with a no-op default.

Run: `flutter analyze --no-fatal-infos`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add lib test/unit
git commit -m "feat(telemetry): record session, assessment, practice and login events (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 13: Settings opt-out toggle

**Files:**
- Create: `lib/features/settings/providers/telemetry_enabled_provider.dart`
- Create: `lib/features/settings/widgets/telemetry_toggle.dart`
- Modify: `lib/features/settings/screens/settings_screen.dart`
- Test: `test/unit/features/telemetry_enabled_provider_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `telemetryGateProvider`
- Produces: `final telemetryEnabledProvider = NotifierProvider<TelemetryEnabledNotifier, bool>(...)` with `void setEnabled(bool value)`; `class TelemetryToggle extends ConsumerWidget`

Follows the exact shape of the existing `ThemeModeNotifier` in `lib/features/settings/providers/theme_mode_provider.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/features/telemetry_enabled_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/features/settings/providers/telemetry_enabled_provider.dart';

Future<ProviderContainer> _container(
  Map<String, Object> initial,
  TelemetryGate gate,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      telemetryGateProvider.overrideWithValue(gate),
    ],
  );
}

void main() {
  test('telemetry is enabled by default when nothing is stored', () async {
    final container = await _container({}, TelemetryGate(isOpen: true));
    addTearDown(container.dispose);
    expect(container.read(telemetryEnabledProvider), isTrue);
  });

  test('a stored opt-out is honoured on start', () async {
    final container = await _container(
      {'telemetry_enabled': false},
      TelemetryGate(isOpen: false),
    );
    addTearDown(container.dispose);
    expect(container.read(telemetryEnabledProvider), isFalse);
  });

  test('opting out closes the gate immediately without a restart', () async {
    final gate = TelemetryGate(isOpen: true);
    final container = await _container({}, gate);
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(false);

    expect(container.read(telemetryEnabledProvider), isFalse);
    expect(gate.isOpen, isFalse);
  });

  test('opting back in reopens the gate', () async {
    final gate = TelemetryGate(isOpen: false);
    final container = await _container(
      {'telemetry_enabled': false},
      gate,
    );
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(true);

    expect(gate.isOpen, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/features/telemetry_enabled_provider_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the provider**

Create `lib/features/settings/providers/telemetry_enabled_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/shared_preferences_provider.dart';
import '../../../data/services/telemetry/telemetry_providers.dart';

const String kTelemetryEnabledKey = 'telemetry_enabled';

final telemetryEnabledProvider =
    NotifierProvider<TelemetryEnabledNotifier, bool>(
      TelemetryEnabledNotifier.new,
    );

/// The user's choice about diagnostics, persisted and applied immediately.
///
/// The same key is read in `main()` before `runApp`, so the choice is already
/// in force for the very first frame; flipping it here moves the shared
/// [TelemetryGate] so no restart is needed.
class TelemetryEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(kTelemetryEnabledKey) ??
        true;
  }

  void setEnabled(bool value) {
    ref.read(sharedPreferencesProvider).setBool(kTelemetryEnabledKey, value);
    final gate = ref.read(telemetryGateProvider);
    value ? gate.open() : gate.close();
    state = value;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/features/telemetry_enabled_provider_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the toggle widget**

Create `lib/features/settings/widgets/telemetry_toggle.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_card.dart';
import '../providers/telemetry_enabled_provider.dart';

/// Lets the user turn diagnostics off. Default is on, matching the revised
/// privacy policy.
class TelemetryToggle extends ConsumerWidget {
  const TelemetryToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(telemetryEnabledProvider);

    return AppCard(
      child: SwitchListTile(
        value: enabled,
        onChanged: (value) =>
            ref.read(telemetryEnabledProvider.notifier).setEnabled(value),
        title: const Text('إرسال تقارير الأعطال والاستخدام'),
        subtitle: const Text(
          'تساعدنا هذه التقارير على اكتشاف الأعطال وإصلاحها. '
          'لا تتضمن اسمك ولا بيانات حفظك.',
        ),
      ),
    );
  }
}
```

Confirm the real `AppCard` API first with `sed -n '1,40p' lib/shared/widgets/app_card.dart`; if its child parameter is named differently, or if it requires a title, match that. Follow the surrounding cards in `settings_screen.dart` for spacing conventions.

- [ ] **Step 6: Add it to the settings screen**

In `lib/features/settings/screens/settings_screen.dart`, add the import `import '../widgets/telemetry_toggle.dart';` and insert into the `SliverChildListDelegate` list immediately after `const ThemeModeSelector(),`:

```dart
                const SizedBox(height: 16),
                const TelemetryToggle(),
```

- [ ] **Step 7: Verify and commit**

Run: `flutter analyze --no-fatal-infos && flutter test test/`
Expected: both PASS.

```bash
git add lib/features/settings test/unit/features/telemetry_enabled_provider_test.dart
git commit -m "feat(settings): let users turn diagnostics off (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 14: Client-to-function trace correlation

**Files:**
- Modify: `lib/data/services/firebase_service.dart` (callables at lines 87 and 114)
- Modify: `lib/data/repositories/auth_repository.dart` (callable at line 159)
- Modify: `functions/src/index.ts` (`createUserAccount` line 105, `setUserPassword` line 301, `hardDeleteStudent` line 482)
- Test: `test/unit/core/telemetry/trace_id_test.dart`

**Interfaces:**
- Produces: `String newClientTraceId()` in `lib/core/telemetry/pii_scrubber.dart`'s sibling file `lib/core/telemetry/client_trace_id.dart`

This joins a client-side Sentry error to its Cloud Logging entry without adopting distributed tracing. The field is optional on the server, so an older client keeps working.

- [ ] **Step 1: Write the failing test**

Create `test/unit/core/telemetry/trace_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/client_trace_id.dart';

void main() {
  test('a trace id is unique per call', () {
    expect(newClientTraceId(), isNot(newClientTraceId()));
  });

  test('a trace id is short enough to read in a log line', () {
    expect(newClientTraceId().length, lessThanOrEqualTo(36));
    expect(newClientTraceId(), isNotEmpty);
  });

  test('a trace id carries no personal data', () {
    expect(newClientTraceId(), matches(RegExp(r'^[0-9a-fA-F-]+$')));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/core/telemetry/trace_id_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Write the implementation**

Create `lib/core/telemetry/client_trace_id.dart`:

```dart
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// A per-invocation id sent with every callable request and echoed into the
/// function's structured log, so a client-side error report and a server-side
/// log line can be joined.
String newClientTraceId() => _uuid.v4();
```

`uuid` is already a direct dependency (`pubspec.yaml`), so no new package is needed. This file imports a package and therefore is the one permitted exception to the ports-stay-pure rule — `uuid` is pure Dart with no framework or vendor coupling.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/core/telemetry/trace_id_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Send the id from every callable**

Run: `sed -n '80,125p' lib/data/services/firebase_service.dart` and `sed -n '155,175p' lib/data/repositories/auth_repository.dart` to see the current payload construction.

For each of the three call sites, add `'client_trace_id': newClientTraceId()` to the map passed to `callable.call(...)`, importing `../../core/telemetry/client_trace_id.dart` (adjust the relative depth per file). Capture the id in a local first so the same value can be attached to an error report in the `catch`:

```dart
    final traceId = newClientTraceId();
    try {
      final result = await callable.call({...existing, 'client_trace_id': traceId});
      ...
    } catch (e, st) {
      // The reason is the join key; it contains no personal data.
      rethrow;
    }
```

- [ ] **Step 6: Log the id on the server**

In `functions/src/index.ts`, add `clientTraceId?: string | null;` to each of `CreateUserAccountPayload`, `SetUserPasswordPayload`, and `HardDeleteStudentPayload` — matching the existing naming style in that file (the payloads use camelCase in TypeScript while the wire uses snake_case, so read the surrounding handler to see how fields are pulled off `request.data` and follow it exactly).

Then add the id to the existing `logger` calls in each handler. For example, `createUserAccount`'s success log at line 280 becomes:

```ts
    logger.info("createUserAccount: created", {
      // ...existing fields...
      clientTraceId: request.data.client_trace_id ?? null,
    });
```

Do the same for the error logs at lines 216, 264, 272, and for `setUserPassword` (line 424) and `hardDeleteStudent` (lines 544, 556).

- [ ] **Step 7: Typecheck the functions and commit**

Run: `cd functions && ./node_modules/.bin/tsc --noEmit && cd ..`
Expected: no errors.

Run: `flutter analyze --no-fatal-infos && flutter test test/`
Expected: both PASS.

```bash
git add lib functions/src/index.ts test/unit/core/telemetry/trace_id_test.dart
git commit -m "feat(telemetry): join client errors to function logs via a trace id (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 15: Alerting runbook

**Files:**
- Create: `docs/guides/observability-runbook.md`

**Interfaces:**
- Consumes: nothing in code
- Produces: nothing consumed by later tasks

Alert policies are four console configurations. Infra-as-code for four rules would be over-engineering; a runbook that says exactly what to create and what to do when it fires is the deliverable.

- [ ] **Step 1: Write the runbook**

Create `docs/guides/observability-runbook.md` containing, at minimum:

- **Where to look:** the Sentry project URL, the Firebase Analytics console path, and the Google Cloud Monitoring console for project `alrasikhoon-57151` (region `europe-west6`).
- **Alert 1 — Cloud Functions error rate.** Metric `cloudfunctions.googleapis.com/function/execution_count` filtered to `status != "ok"`, condition: more than 5 in 5 minutes, notification channel: maintainer email. Response: open Cloud Logging, filter by the failing function, search the `clientTraceId` of a failed execution in Sentry to find the client-side half.
- **Alert 2 — Firestore permission denied.** Metric `firestore.googleapis.com/api/request_count` filtered to `response_code = "PERMISSION_DENIED"`, condition: more than 20 in 10 minutes. Response: this means either a `firestore.rules` regression locking out legitimate users, or someone probing. Check the most recent rules deploy first; institute scoping is documented in `docs/agdr/AgDR-0003-supervisor-institute-scoping.md`.
- **Alert 3 — Firestore read budget.** Metric `firestore.googleapis.com/document/read_count`, condition: daily total above 50,000. Response: identify the screen driving reads; the offline cache is unbounded by design, so a spike usually means a provider re-fetching in a loop.
- **Alert 4 — Crash-free session rate.** Configured in Sentry (Alerts → Create Alert → Crash Free Session Rate), condition: below 99% over 24 hours.
- **The DSN.** `SENTRY_DSN` is supplied as a `--dart-define` at build time and stored as a GitHub Actions secret. It is never committed. An unset DSN silently disables telemetry — if reports stop arriving after a release, check the secret first.
- **Turning it all off.** Users can opt out in the app under الملف الشخصي. Server-side, remove the DSN secret and cut a new build.

- [ ] **Step 2: Add the DSN to CI**

In `.github/workflows/distribute-android.yml` and `.github/workflows/distribute-ios.yml`, add `--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}` to the `flutter build` invocation. Read the existing build step first (`grep -n "flutter build" .github/workflows/distribute-*.yml`) and append the flag to the existing argument list rather than replacing it.

Do NOT add it to `.github/workflows/ci.yml` — CI runs tests, which must stay no-op.

- [ ] **Step 3: Commit**

```bash
git add docs/guides/observability-runbook.md .github/workflows
git commit -m "docs(observability): add alerting runbook and wire the DSN into release builds (al_rasikhoon-ciba)

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 16: Privacy policy, store labels, and changelog

**Files:**
- Modify: `web/privacy.html`
- Modify: `CHANGELOG.md`
- Create: `docs/guides/app-store-privacy-labels.md`

**Interfaces:**
- Consumes: nothing in code
- Produces: nothing consumed by later tasks

**This task is not optional paperwork.** The published policy currently promises «لا نجمع تقارير الأعطال» and «لا نستخدم أدوات تحليلات». Shipping the previous tasks without this one puts the app out of compliance with its own published policy and makes the App Store privacy labels inaccurate.

- [ ] **Step 1: Read the current policy sections**

Run: `grep -n "ما لا نجمعه\|مقدّمو الخدمة\|آخر تحديث" web/privacy.html`
Expected: the line numbers of §2ج, §5, and the last-updated line.

- [ ] **Step 2: Revise §2ج (ما لا نجمعه)**

Remove these two bullets, which are now false:
- «لا نستخدم أدوات تحليلات أو قياس سلوك أو إعلانات»
- «لا نجمع تقارير الأعطال»

Keep the remaining true bullets (no location, no photos/contacts/microphone/payment, no cross-app tracking).

- [ ] **Step 3: Add a new subsection for diagnostics**

Add a new «د. بيانات التشخيص والاستخدام» subsection under §2 stating, in the same register as the surrounding Arabic:

- that the app collects crash and error reports containing the technical error, the app version, the device type, the screen the user was on, and an internal account identifier — and **not** the name, username, phone number, or any memorization data;
- that the app collects aggregate usage statistics (which screens are used and whether a session was completed) that are **not linked to an individual user**;
- that the user can turn both off from within the app, under الملف الشخصي.

- [ ] **Step 4: Revise §5 (مقدّمو الخدمة)**

Add Sentry (Functional Software, Inc.) as a service provider for crash and error diagnostics alongside the existing Google Firebase paragraph, and add Firebase Analytics to the list of Firebase services used. Remove the trailing sentence «ولا نستخدم أي خدمات إعلانية أو تحليلية» and replace it with a sentence stating that no advertising services are used and that analytics data is aggregate and not sold.

- [ ] **Step 5: Bump the last-updated date**

Change «آخر تحديث» to the current date in the same Arabic-numeral format used by the existing line.

- [ ] **Step 6: Write the store-label guide**

Create `docs/guides/app-store-privacy-labels.md` recording exactly what to declare, so the next submission does not have to re-derive it:

- **App Store Connect → App Privacy:**
  - Diagnostics → Crash Data: collected, **linked to identity** (the Firebase uid is attached), not used for tracking.
  - Diagnostics → Performance Data: collected, linked to identity, not used for tracking.
  - Usage Data → Product Interaction: collected, **not linked to identity** (no Analytics user id is ever set), not used for tracking.
  - Identifiers → User ID: collected, linked to identity, not used for tracking.
- **Play Console → Data safety:** the same four declarations; mark data as encrypted in transit and users as able to request deletion (via their institute, per policy §1).
- **Why "not linked" is accurate for usage data:** `FirebaseUsageAnalytics` never calls `setUserId`, and this is pinned by the test `user properties carry role and institute but never a user id`.

- [ ] **Step 7: Add the changelog entry**

Per `CLAUDE.md`, add to the top `## Unreleased` section of `CHANGELOG.md`, written for a non-technical stakeholder:

```markdown
- حُدِّثت سياسة الخصوصية: صار التطبيق يجمع تقارير الأعطال وإحصاءات استخدام
  مجمّعة لاكتشاف المشكلات وإصلاحها قبل أن تؤثّر على الحلقات، ولا تتضمّن هذه
  التقارير أسماء المستخدمين ولا بيانات حفظهم.
- يستطيع كل مستخدم إيقاف إرسال تقارير الأعطال والاستخدام من شاشة الملف الشخصي.
```

Match the language and formatting of the existing entries in that file (`sed -n '1,30p' CHANGELOG.md`).

- [ ] **Step 8: Verify and commit**

Run: `flutter analyze --no-fatal-infos && flutter test test/`
Expected: both PASS (this task changes no Dart code, but confirms the branch is green before the final commit).

```bash
git add web/privacy.html CHANGELOG.md docs/guides/app-store-privacy-labels.md
git commit -m "docs(privacy): disclose crash diagnostics and aggregate analytics (al_rasikhoon-ciba)

The published policy promised no crash reports and no analytics. Both are now
collected, so §2ج and §5 are revised, a diagnostics subsection is added, and
the App Store / Play declarations are recorded for the next submission.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Done criteria

- [ ] `flutter test test/` passes.
- [ ] `flutter analyze --no-fatal-infos` reports no errors.
- [ ] `cd functions && ./node_modules/.bin/tsc --noEmit` reports no errors.
- [ ] `grep -rn --include='*.dart' 'debugPrint' lib` returns nothing.
- [ ] `grep -rn "^import" lib/core/telemetry/ | grep -E "package:(flutter|firebase|sentry|flutter_riverpod)"` returns nothing (the `uuid` import in `client_trace_id.dart` is the documented exception).
- [ ] A release build with `--dart-define=SENTRY_DSN=...` produces an event in Sentry when a deliberate test error is thrown.
- [ ] A debug build produces **no** Sentry events.
- [ ] `web/privacy.html` no longer claims that crash reports and analytics are not collected.
- [ ] `bd close al_rasikhoon-ciba`
