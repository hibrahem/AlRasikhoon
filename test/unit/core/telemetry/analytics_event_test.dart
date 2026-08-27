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

  test('a failed login with exception message becomes unknown', () {
    final event = LoginFailed(
      reasonCode:
          'FirebaseAuthException: no user for ahmad.ali@alrasikhoon.local',
    );
    expect(event.parameters, {'reason_code': 'unknown'});
    expect(event.parameters.values.join(), isNot(contains('@')));
  });

  test(
    'a failed login with legitimate firebase code passes through unchanged',
    () {
      final event = LoginFailed(reasonCode: 'wrong-password');
      expect(event.parameters, {'reason_code': 'wrong-password'});
    },
  );

  test('a session type with arabic text becomes unknown', () {
    final event = SessionRecorded(
      sessionType: 'حفظ-memorization',
      errorCount: 0,
      duration: Duration.zero,
      wasOffline: false,
    );
    expect(event.parameters['session_type'], 'unknown');
  });

  test('an uppercase legitimate value is lowercased', () {
    final event = LoginSucceeded(role: 'TEACHER');
    expect(event.parameters, {'role': 'teacher'});
  });

  test('a step value with spaces becomes unknown', () {
    final event = SessionAbandoned(step: 'errors recorded');
    expect(event.parameters, {'step': 'unknown'});
  });

  test('an assessment result with email becomes unknown', () {
    final event = AssessmentCompleted(result: 'passed:admin@example.com');
    expect(event.parameters, {'result': 'unknown'});
    expect(event.parameters.values.join(), isNot(contains('@')));
  });
}
