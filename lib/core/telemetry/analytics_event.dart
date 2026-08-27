import 'pii_scrubber.dart';

/// Normalizes a closed-vocabulary parameter value to prevent free-form text
/// from reaching the analytics backend.
///
/// Legitimate values are short lowercase codes (`wrong-password`, `hifz`,
/// `teacher`, `errors_recorded`). Anything containing a space, an `@`, or
/// non-ASCII text is by definition not a code — it is a message or a name
/// that must never reach the analytics backend. Coercing to `'unknown'` loses
/// a little diagnostic detail and that is the correct trade: these events
/// describe usage by students and teachers, many of them minors.
String _normalizeClosed(String value) {
  final normalized = value.trim().toLowerCase();
  // Only allow alphanumeric, underscore, dot, and hyphen, up to 40 chars.
  if (RegExp(r'^[a-z0-9_.\-]{1,40}$').hasMatch(normalized)) {
    return normalized;
  }
  return 'unknown';
}

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
  Map<String, Object> get parameters => {'role': _normalizeClosed(role)};
}

final class LoginFailed extends AnalyticsEvent {
  const LoginFailed({required this.reasonCode});

  /// A stable code such as `wrong_password` or `network_error`. Never the
  /// username or the message returned by Firebase.
  final String reasonCode;

  @override
  String get name => 'login_failed';

  @override
  Map<String, Object> get parameters => {
    'reason_code': _normalizeClosed(reasonCode),
  };
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
    'session_type': _normalizeClosed(sessionType),
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
  Map<String, Object> get parameters => {'step': _normalizeClosed(step)};
}

final class AssessmentCompleted extends AnalyticsEvent {
  const AssessmentCompleted({required this.result});
  final String result;

  @override
  String get name => 'assessment_completed';

  @override
  Map<String, Object> get parameters => {'result': _normalizeClosed(result)};
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
