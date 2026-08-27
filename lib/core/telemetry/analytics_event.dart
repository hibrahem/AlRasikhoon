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
