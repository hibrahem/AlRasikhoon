import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/usage_analytics.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/services/firestore_read_source.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';

class _RecordingAnalytics implements UsageAnalytics {
  final List<AnalyticsEvent> events = [];
  final List<Map<String, String>> userProperties = [];

  @override
  void record(AnalyticsEvent event) => events.add(event);

  @override
  void setUserProperties({required String role, required String instituteId}) {
    userProperties.add({'role': role, 'institute_id': instituteId});
  }

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

  test('a saved سرد session records a SessionRecorded event', () async {
    final analytics = _RecordingAnalytics();
    final repository = SessionRepository(
      firestore: FakeFirebaseFirestore(),
      analytics: analytics,
    );

    await repository.createSardRecord(
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S30',
      tier: AssessmentTier.unit,
      juzNumbers: const [30],
      hizbNumber: 59,
      levelId: 1,
      attemptNumber: 1,
      evaluation: SardEvaluation([RecitationErrorTally(tanbeehat: 3)]),
    );

    expect(analytics.events.whereType<SessionRecorded>(), hasLength(1));
    final event = analytics.events.whereType<SessionRecorded>().single;
    expect(event.sessionType, 'sard');
    expect(event.errorCount, 3);
    expect(event.wasOffline, isFalse);
  });

  test('a session saved while offline records was_offline as 1', () async {
    final analytics = _RecordingAnalytics();
    final repository = SessionRepository(
      firestore: FakeFirebaseFirestore(),
      readSource: FirestoreReadSource(isOnline: () => false),
      analytics: analytics,
    );

    await repository.createSardRecord(
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S30',
      tier: AssessmentTier.unit,
      juzNumbers: const [30],
      hizbNumber: 59,
      levelId: 1,
      attemptNumber: 1,
      evaluation: SardEvaluation([RecitationErrorTally(tanbeehat: 0)]),
    );

    final event = analytics.events.whereType<SessionRecorded>().single;
    expect(event.wasOffline, isTrue);
    expect(event.parameters['was_offline'], 1);
  });

  test('a home practice repository built without analytics still works', () {
    expect(
      () => HomePracticeRepository(firestore: FakeFirebaseFirestore()),
      returnsNormally,
    );
  });

  test('creating a home practice records HomePracticeLogged', () async {
    final analytics = _RecordingAnalytics();
    final repository = HomePracticeRepository(
      firestore: FakeFirebaseFirestore(),
      analytics: analytics,
    );

    await repository.createHomePractice(
      studentId: 'student1',
      curriculumSessionId: 'L1_J30_S30',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: 1,
      repetitions: 3,
    );

    expect(analytics.events.whereType<HomePracticeLogged>(), hasLength(1));
  });
}
