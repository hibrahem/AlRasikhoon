import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

/// Real level-1 rows (see `data/curriculum/sessions_level_1.json`).
const firstLesson = SessionModel(
  id: 'L1_J30_S1',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 1,
  orderInLevel: 1,
  kind: SessionKind.lesson,
  unitIndex: 1,
  hizbNumber: 59,
);

/// L1_J30_S35 is an ordinary lesson — the old model would have called 35 a سرد.
const lessonNumberedThirtyFive = SessionModel(
  id: 'L1_J30_S35',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 35,
  orderInLevel: 35,
  kind: SessionKind.lesson,
  unitIndex: 2,
  hizbNumber: 60,
);

/// L1_J30_S30: the hizb-59 سرد, recited to the teacher.
const hizbSard = SessionModel(
  id: 'L1_J30_S30',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 30,
  orderInLevel: 30,
  kind: SessionKind.sard,
  assessedBy: AssessedBy.teacher,
  unitIndex: 1,
  hizbNumber: 59,
  scope: SessionScope(
    tier: AssessmentTier.unit,
    labelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
    hizbNumber: 59,
    juzNumbers: [30],
  ),
);

/// L1_J30_S68: the juz-30 اختبار, sat with the supervisor.
const juzExam = SessionModel(
  id: 'L1_J30_S68',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 68,
  orderInLevel: 68,
  kind: SessionKind.exam,
  assessedBy: AssessedBy.supervisor,
  scope: SessionScope(
    tier: AssessmentTier.juz,
    labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
    juzNumbers: [30],
  ),
);

/// A level-3 lesson: no hizb label outside levels 1-2.
const level3Lesson = SessionModel(
  id: 'L3_J24_S12',
  levelId: 3,
  juzNumber: 24,
  sessionNumber: 12,
  orderInLevel: 12,
  kind: SessionKind.lesson,
  unitIndex: 1,
);

StudentModel studentOn(SessionModel session, {int attempt = 1}) =>
    StudentModel.enrolledAt(
      id: 's1',
      userId: 'u1',
      instituteId: 'i1',
      session: session,
      createdAt: DateTime(2026, 7, 13),
    ).copyWith(currentAttempt: attempt);

void main() {
  group('StudentModel', () {
    group('a student who has just joined', () {
      final student = StudentModel(
        id: 'student123',
        userId: 'user123',
        instituteId: 'institute123',
        createdAt: DateTime.now(),
      );

      test('stands at the first session of the curriculum', () {
        expect(student.currentLevel, 1);
        expect(student.currentJuz, 30);
        expect(student.currentSession, 1);
        expect(student.currentSessionId, 'L1_J30_S1');
        expect(student.currentOrderInLevel, 1);
        expect(student.currentAttempt, 1);
      });

      test('stands on a lesson, not an assessment', () {
        expect(student.currentSessionKind, SessionKind.lesson);
        expect(student.currentSessionTier, isNull);
        expect(student.canTakeSard, isFalse);
        expect(student.canTakeExam, isFalse);
      });

      test('has level 1 unlocked and nothing completed', () {
        expect(student.unlockedLevels, [1]);
        expect(student.completedLevels, isEmpty);
        expect(student.isActive, isTrue);
      });
    });

    group('placement', () {
      test('a student placed at the start earns no credit', () {
        final student = studentOn(firstLesson);

        expect(student.enrollmentPosition, CurriculumPosition.start);
        expect(student.completedLevels, isEmpty);
        expect(student.unlockedLevels, [1]);
      });

      test(
        'a student placed mid-curriculum is credited with the levels before them',
        () {
          final student = studentOn(level3Lesson);

          expect(student.currentLevel, 3);
          expect(student.currentJuz, 24);
          expect(student.currentSession, 12);
          expect(student.currentHizb, isNull);
          expect(student.completedLevels, [1, 2]);
          expect(student.unlockedLevels, [1, 2, 3]);
        },
      );

      test(
        'a student placed on a juz-tier اختبار is standing on that exam',
        () {
          final student = studentOn(juzExam);

          expect(student.currentSessionKind, SessionKind.exam);
          expect(student.currentSessionTier, AssessmentTier.juz);
          expect(
            student.currentSessionLabelAr,
            'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
          );
          expect(student.currentSessionId, 'L1_J30_S68');
          expect(student.currentOrderInLevel, 68);
          expect(student.canTakeExam, isTrue);
          expect(student.canTakeSard, isFalse);
        },
      );

      test('a student placed on a hizb سرد is standing on a unit-tier سرد', () {
        final student = studentOn(hizbSard);

        expect(student.canTakeSard, isTrue);
        expect(student.currentSessionTier, AssessmentTier.unit);
        expect(student.currentHizb, 59);
      });
    });

    group('what the student is standing on comes from the curriculum', () {
      test('a lesson numbered 35 is still a lesson', () {
        // The old model read `currentSession == 35` as "can take سرد".
        final student = studentOn(lessonNumberedThirtyFive);

        expect(student.currentSession, 35);
        expect(student.canTakeSard, isFalse);
        expect(student.canTakeExam, isFalse);
        expect(student.isOnAssessment, isFalse);
      });

      test('moving to a session carries its kind, tier and label along', () {
        final student = studentOn(firstLesson).movedTo(juzExam);

        expect(student.currentSessionKind, SessionKind.exam);
        expect(student.currentSessionTier, AssessmentTier.juz);
        expect(student.currentOrderInLevel, 68);
        expect(student.currentAttempt, 1);
        // The anchor does not move with the student.
        expect(student.enrollmentPosition, CurriculumPosition.start);
      });
    });

    group('attempts', () {
      test('a lesson may be attempted three times', () {
        expect(studentOn(firstLesson, attempt: 1).canStartSession, isTrue);
        expect(studentOn(firstLesson, attempt: 3).canStartSession, isTrue);
        expect(
          studentOn(firstLesson, attempt: 3).hasReachedMaxAttempts,
          isFalse,
        );
      });

      test('a fourth attempt at a lesson is refused', () {
        final student = studentOn(firstLesson, attempt: 4);

        expect(student.hasReachedMaxAttempts, isTrue);
        expect(student.canStartSession, isFalse);
      });

      test('a سرد may be retried without limit', () {
        final student = studentOn(hizbSard, attempt: 9);

        expect(student.hasReachedMaxAttempts, isFalse);
        expect(student.canStartSession, isTrue);
      });

      test('an اختبار may be retried without limit, at every tier', () {
        final student = studentOn(juzExam, attempt: 12);

        expect(student.hasReachedMaxAttempts, isFalse);
        expect(student.canStartSession, isTrue);
      });
    });

    group('persistence', () {
      test('the current session is denormalized onto the student', () async {
        final student = studentOn(juzExam);
        final data = student.toFirestore();

        expect(data['current_session_id'], 'L1_J30_S68');
        expect(data['current_session_kind'], 'exam');
        expect(data['current_session_tier'], 'juz');
        expect(
          data['current_session_label_ar'],
          'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
        );
        expect(data['current_order_in_level'], 68);
        expect(data['enrollment_position'], {
          'level': 1,
          'juz': 30,
          'session': 68,
        });

        final firestore = FakeFirebaseFirestore();
        await firestore.collection('students').doc('s1').set(data);
        final doc = await firestore.collection('students').doc('s1').get();
        final round = StudentModel.fromFirestore(doc);

        expect(round.currentSessionKind, SessionKind.exam);
        expect(round.currentSessionTier, AssessmentTier.juz);
        expect(round.currentOrderInLevel, 68);
        expect(round.canTakeExam, isTrue);
        expect(
          round.enrollmentPosition,
          const CurriculumPosition(level: 1, juz: 30, session: 68),
        );
      });

      test('a student stored before enrollment tracking reads back anchored at '
          'the start, with its session id rebuilt from the position', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('students').doc('old').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_session': 8,
          // current_session_kind IS present — every real document carries
          // it (see the "corrupted or unmigrated data" test below); this
          // fixture is only missing the LATER-added enrollment/session-id
          // fields, to lock in their own, unrelated fallbacks.
          'current_session_kind': 'lesson',
          'current_attempt': 1,
          'completed_levels': <int>[],
          'unlocked_levels': [1],
          'is_active': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

        final doc = await firestore.collection('students').doc('old').get();
        final student = StudentModel.fromFirestore(doc);

        expect(student.enrollmentPosition, CurriculumPosition.start);
        expect(student.currentSessionKind, SessionKind.lesson);
        expect(student.currentSessionId, 'L1_J30_S8');
      });

      test(
        'a document missing current_session_kind is corrupted or unmigrated '
        'data, and must surface — not be silently treated as a lesson',
        () async {
          // No production student document is missing this field: every
          // write path (_writePosition) sets it alongside the rest of the
          // position. Silently defaulting it to a lesson is exactly how a
          // student standing on an اختبار would drop unnoticed out of the
          // supervisor's exam queue.
          final firestore = FakeFirebaseFirestore();
          await firestore.collection('students').doc('broken').set({
            'user_id': 'u1',
            'institute_id': 'i1',
            'current_level': 1,
            'current_juz': 30,
            'current_session': 8,
            'current_attempt': 1,
            'completed_levels': <int>[],
            'unlocked_levels': [1],
            'is_active': true,
            'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
          });

          final doc = await firestore
              .collection('students')
              .doc('broken')
              .get();

          expect(() => StudentModel.fromFirestore(doc), throwsArgumentError);
        },
      );

      test('the current position is exposed as a curriculum position', () {
        final student = studentOn(hizbSard);

        expect(
          student.currentPosition,
          const CurriculumPosition(level: 1, juz: 30, session: 30),
        );
      });
    });

    group('a student standing on a talqeen session', () {
      StudentModel onTalqeen({int attempt = 1}) => StudentModel(
        id: 's1',
        userId: 'u1',
        instituteId: 'i1',
        currentSessionId: 'L1_J30_S1',
        currentSessionKind: SessionKind.talqeen,
        currentAttempt: attempt,
        createdAt: DateTime(2026, 1, 1),
      );

      test('is not on an assessment', () {
        expect(onTalqeen().isOnAssessment, isFalse);
        expect(onTalqeen().isOnTalqeen, isTrue);
        expect(onTalqeen().canTakeSard, isFalse);
        expect(onTalqeen().canTakeExam, isFalse);
      });

      test('can never exhaust attempts at a session that cannot be failed', () {
        expect(onTalqeen(attempt: 9).hasReachedMaxAttempts, isFalse);
        expect(onTalqeen(attempt: 9).canStartSession, isTrue);
      });
    });

    group('a student carries the pace the teacher set for them', () {
      test(
        'a student created before paced curricula runs at the standard pace',
        () {
          final student = StudentModel.fromJson('s1', {
            'user_id': 'u1',
            'institute_id': 'i1',
            // current_session_kind is required on every real student
            // document (see the "corrupted or unmigrated data" test above);
            // it is unrelated to pace, so it is included here just to reach
            // a valid student.
            'current_session_kind': 'lesson',
            'created_at': null,
          });

          expect(student.pace, CurriculumPace.standard);
        },
      );

      test('a doubled student reads back doubled', () {
        final student = StudentModel.fromJson('s1', {
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_session_kind': 'lesson',
          'pace': 2,
          'created_at': null,
        });

        expect(student.pace, CurriculumPace(2));
        expect(student.toFirestore()['pace'], 2);
      });
    });

    group('identity', () {
      test('students are equal by id', () {
        final a = StudentModel(
          id: 'student123',
          userId: 'user123',
          instituteId: 'i1',
          createdAt: DateTime.now(),
        );
        final b = StudentModel(
          id: 'student123',
          userId: 'user456',
          instituteId: 'i2',
          createdAt: DateTime.now(),
        );
        final c = StudentModel(
          id: 'student456',
          userId: 'user123',
          instituteId: 'i1',
          createdAt: DateTime.now(),
        );

        expect(a, equals(b));
        expect(a, isNot(equals(c)));
      });
    });
  });
}
