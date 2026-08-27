import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/usage_analytics.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/home_practice_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/firestore_read_source.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_result_screen.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

class _RecordingAnalytics implements UsageAnalytics {
  final List<AnalyticsEvent> events = [];

  @override
  void record(AnalyticsEvent event) => events.add(event);

  @override
  void setUserProperties({required String role, required String instituteId}) {}

  @override
  void recordScreenView(String templatedRoute) {}
}

/// A [WriteBatch] that stages writes normally (delegating to a real batch)
/// but always fails on [commit] — simulating an offline/rejected sync. Same
/// approach as `test/unit/providers/teacher_provider_offline_save_test.dart`'s
/// `_CommitFailingWriteBatch`, duplicated here (that one is private to its
/// own file) so the fire-and-forget `batch.commit().then(...).catchError(...)`
/// chain in `ActiveSessionNotifier.completeSession` can be exercised without
/// a real network.
class _CommitFailingWriteBatch implements WriteBatch {
  _CommitFailingWriteBatch(this._delegate);

  final WriteBatch _delegate;

  @override
  Future<void> commit() {
    // A real Firestore commit failure surfaces asynchronously — return a
    // rejected Future rather than throwing synchronously, so `.catchError`
    // on the caller's chain actually attaches and runs.
    return Future<void>.error(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'simulated offline commit failure',
      ),
    );
  }

  @override
  void delete(DocumentReference<Object?> document) =>
      _delegate.delete(document);

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _delegate.set(document, data, options);

  @override
  void update(DocumentReference<Object?> document, Map<Object, Object?> data) =>
      _delegate.update(document, data);
}

class _FailingBatchSessionRepository extends SessionRepository {
  _FailingBatchSessionRepository({required super.firestore});

  @override
  WriteBatch newWriteBatch() => _CommitFailingWriteBatch(super.newWriteBatch());
}

void main() {
  test('a HomePracticeRepository built without analytics still works', () {
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

  group('ActiveSessionNotifier.completeSession — commit-gated analytics', () {
    late FakeFirebaseFirestore firestore;
    late CurriculumRepository curriculumRepository;
    late StudentRepository studentRepository;

    SessionModel session({required int order}) => SessionModel(
      id: 'L1_J30_S$order',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: order,
      orderInLevel: order,
      kind: SessionKind.lesson,
      currentLevelContent: QuranContent(
        fromSurah: 'النبأ',
        fromVerse: order,
        toSurah: 'النبأ',
        toVerse: order + 1,
      ),
    );

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      curriculumRepository = CurriculumRepository(firestore: firestore);
      // studentRepository is built per-test against whichever SessionRepository
      // (succeeding or failing) that test needs.

      for (final s in [session(order: 1), session(order: 2)]) {
        await firestore.collection('sessions').doc(s.id).set(s.toFirestore());
      }
      await firestore.collection('users').doc('user-1').set({
        'username': 'pupil',
        'email': 'pupil@alrasikhoon.local',
        'name': 'طالب',
        'role': 'student',
        'is_active': true,
        'created_at': Timestamp.now(),
      });
      await firestore.collection('students').doc('student-1').set({
        'user_id': 'user-1',
        'institute_id': 'institute-1',
        'teacher_id': 'teacher-1',
        'current_level': 1,
        'current_juz': 30,
        'current_session': 1,
        'current_order_in_level': 1,
        'current_hizb': null,
        'current_session_id': 'L1_J30_S1',
        'current_session_kind': 'lesson',
        'current_attempt': 1,
        'completed_levels': <int>[],
        'unlocked_levels': const [1],
        'is_active': true,
        'created_at': Timestamp.now(),
        'pace': CurriculumPace.standard.toJson(),
      });
    });

    UserModel teacher() => UserModel(
      id: 'teacher-1',
      username: 'teacher_one',
      email: 'teacher_one@alrasikhoon.local',
      name: 'معلم',
      role: UserRole.teacher,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );

    ActiveSessionNotifier startedNotifier(ProviderContainer container) {
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 0);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);
      return notifier;
    }

    test('a completed session records SessionRecorded ONLY AFTER the batch '
        'commit succeeds', () async {
      final analytics = _RecordingAnalytics();
      studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: UserRepository(firestore: firestore),
        curriculumRepository: curriculumRepository,
        sessionRepository: SessionRepository(firestore: firestore),
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(teacher()),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(
            SessionRepository(firestore: firestore),
          ),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
          usageAnalyticsProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);

      final notifier = startedNotifier(container);

      // Before completeSession resolves, no commit has happened yet, so
      // no event can have fired.
      expect(analytics.events, isEmpty);

      await notifier.completeSession();
      // The batch commit is fire-and-forget — drain the event queue so the
      // success continuation has a chance to run before asserting.
      await pumpEventQueue();

      expect(analytics.events.whereType<SessionRecorded>(), hasLength(1));
      final event = analytics.events.whereType<SessionRecorded>().single;
      expect(event.sessionType, 'hifz');
      expect(event.wasOffline, isFalse);
    });

    test(
      'a session whose batch commit FAILS emits NO SessionRecorded event',
      () async {
        final analytics = _RecordingAnalytics();
        final failingSessionRepository = _FailingBatchSessionRepository(
          firestore: firestore,
        );
        studentRepository = StudentRepository(
          firestore: firestore,
          firebaseService: _MockFirebaseService(),
          userRepository: UserRepository(firestore: firestore),
          curriculumRepository: curriculumRepository,
          sessionRepository: failingSessionRepository,
        );

        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWithValue(teacher()),
            studentRepositoryProvider.overrideWithValue(studentRepository),
            sessionRepositoryProvider.overrideWithValue(
              failingSessionRepository,
            ),
            curriculumRepositoryProvider.overrideWithValue(
              curriculumRepository,
            ),
            usageAnalyticsProvider.overrideWithValue(analytics),
          ],
        );
        addTearDown(container.dispose);

        final notifier = startedNotifier(container);

        // completeSession() itself does not throw — the commit is
        // fire-and-forget — but its rejection must suppress the event.
        final record = await notifier.completeSession();
        expect(record, isNotNull);
        await pumpEventQueue();

        expect(analytics.events, isEmpty);
      },
    );

    test('a session created while offline and later committed still reports '
        'was_offline as 1', () async {
      final analytics = _RecordingAnalytics();
      studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: UserRepository(firestore: firestore),
        curriculumRepository: curriculumRepository,
        sessionRepository: SessionRepository(firestore: firestore),
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(teacher()),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(
            SessionRepository(firestore: firestore),
          ),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
          usageAnalyticsProvider.overrideWithValue(analytics),
          // The fake batch's commit resolves successfully regardless of
          // this — connectivity here only decides what gets CAPTURED as
          // `wasOffline` at record-creation time, exactly like a real
          // offline session that syncs once connectivity returns.
          firestoreReadSourceProvider.overrideWithValue(
            FirestoreReadSource(isOnline: () => false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = startedNotifier(container);
      await notifier.completeSession();
      await pumpEventQueue();

      final event = analytics.events.whereType<SessionRecorded>().single;
      expect(event.wasOffline, isTrue);
      expect(event.parameters['was_offline'], 1);
    });
  });

  group('ExamResultScreen — commit-gated analytics', () {
    testWidgets('an exam whose commit succeeds emits AssessmentCompleted', (
      tester,
    ) async {
      final firestore = FakeFirebaseFirestore();
      final analytics = _RecordingAnalytics();

      await firestore.collection('sessions').doc('L1_J30_S32').set({
        'level_id': 1,
        'juz_number': 30,
        'session_number': 32,
        'order_in_level': 32,
        'kind': 'exam',
        'assessed_by': 'supervisor',
        'hizb_number': 59,
        'scope': {
          'tier': 'unit',
          'label_ar': 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
          'hizb_number': 59,
          'juz_numbers': [30],
        },
      });

      await firestore.collection('students').doc('student1').set({
        'user_id': 'user1',
        'institute_id': 'institute1',
        'current_level': 1,
        'current_juz': 30,
        'current_hizb': 59,
        'current_session': 32,
        'current_order_in_level': 32,
        'current_session_id': 'L1_J30_S32',
        'current_session_kind': 'exam',
        'current_session_tier': 'unit',
        'current_session_label_ar':
            'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
        'current_attempt': 1,
        'completed_levels': <int>[],
        'unlocked_levels': [1],
        'is_active': true,
        'created_at': Timestamp.now(),
      });

      final student = StudentModel(
        id: 'student1',
        userId: 'user1',
        instituteId: 'institute1',
        currentLevel: 1,
        currentJuz: 30,
        currentHizb: 59,
        currentSession: 32,
        currentOrderInLevel: 32,
        currentSessionId: 'L1_J30_S32',
        currentSessionKind: SessionKind.exam,
        currentSessionTier: AssessmentTier.unit,
        currentSessionLabelAr:
            'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
        createdAt: DateTime(2026, 1, 1),
      );
      final studentUser = UserModel(
        id: 'user1',
        username: 'pupil',
        email: 'pupil@alrasikhoon.local',
        name: 'طالب',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );
      final supervisor = UserModel(
        id: 'supervisor1',
        username: 'supervisor',
        email: 'supervisor@alrasikhoon.local',
        name: 'مشرف',
        role: UserRole.supervisor,
        instituteId: 'institute1',
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );

      final sessionRepository = SessionRepository(firestore: firestore);
      final studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: UserRepository(firestore: firestore),
        curriculumRepository: CurriculumRepository(firestore: firestore),
        sessionRepository: sessionRepository,
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ExamResultScreen(
              studentId: 'student1',
              questions: [
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
              ],
            ),
          ),
          GoRoute(
            path: AppRoutes.examQueue,
            builder: (context, state) =>
                const Scaffold(body: Text('قائمة الاختبارات')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(firestore),
            currentUserProvider.overrideWithValue(supervisor),
            studentRepositoryProvider.overrideWithValue(studentRepository),
            sessionRepositoryProvider.overrideWithValue(sessionRepository),
            examStudentProvider.overrideWith(
              (ref, id) async =>
                  StudentWithUser(student: student, user: studentUser),
            ),
            examQueueProvider.overrideWith((ref) async => []),
            usageAnalyticsProvider.overrideWithValue(analytics),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('حفظ النتيجة'));
      await tester.pumpAndSettle();

      // Before tapping save, nothing has been committed yet.
      expect(analytics.events, isEmpty);

      await tester.tap(find.text('حفظ النتيجة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(analytics.events.whereType<AssessmentCompleted>(), hasLength(1));
      expect(
        analytics.events.whereType<AssessmentCompleted>().single.result,
        'muwaffaq',
      );
    });
  });
}
