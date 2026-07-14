import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';

/// A one-session meeting standing in for whatever `PacedSessionComposer`
/// would have produced — these tests exercise `SessionRepository`, not
/// composition, so the content blocks are irrelevant and left empty.
PacedSession _meeting({
  required String id,
  required int sessionNumber,
  required int orderInLevel,
  int levelId = 1,
  SessionKind kind = SessionKind.lesson,
}) {
  final session = SessionModel(
    id: id,
    levelId: levelId,
    juzNumber: 30,
    sessionNumber: sessionNumber,
    orderInLevel: orderInLevel,
    kind: kind,
  );
  return PacedSession(
    sessions: [session],
    newContent: const [],
    recentReview: const [],
    distantReview: const [],
  );
}

/// A genuine TWO-session meeting — what a 2x student's batch produces — so
/// the batching derivations in `createSessionRecord`/`createTalqeenRecord`
/// (which session names the record, whose `orderInLevel` is `from`/`to`,
/// what `coversSessionIds` holds) are exercised on more than one session.
/// `_meeting`, being single-session, cannot tell `.last` from `.first` or a
/// real span from a degenerate one-element one.
PacedSession _twoSessionMeeting({
  required String firstId,
  required String secondId,
  required int firstOrderInLevel,
  required int firstSessionNumber,
  int levelId = 1,
}) {
  final sessions = [
    SessionModel(
      id: firstId,
      levelId: levelId,
      juzNumber: 30,
      sessionNumber: firstSessionNumber,
      orderInLevel: firstOrderInLevel,
      kind: SessionKind.lesson,
    ),
    SessionModel(
      id: secondId,
      levelId: levelId,
      juzNumber: 30,
      sessionNumber: firstSessionNumber + 1,
      orderInLevel: firstOrderInLevel + 1,
      kind: SessionKind.lesson,
    ),
  ];
  return PacedSession(
    sessions: sessions,
    newContent: const [],
    recentReview: const [],
    distantReview: const [],
  );
}

void main() {
  group('SessionRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SessionRepository sessionRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      sessionRepository = SessionRepository(firestore: fakeFirestore);
    });

    group('createSessionRecord', () {
      test('creates record with passing grades', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
          levelId: 1,
          hizbNumber: 59,
          attemptNumber: 1,
          newMemorizationErrors: 2,
          recentReviewErrors: 1,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace.standard,
        );

        expect(record.studentId, 'student1');
        expect(record.teacherId, 'teacher1');
        expect(record.sessionNumber, 5);
        expect(record.grades.newMemorizationErrors, 2);
        expect(record.grades.recentReviewErrors, 1);
        expect(record.grades.distantReviewErrors, 0);
        expect(record.passed, true); // No part is محب at level 1
      });

      test(
        'fails when any part is محب — even if the others are good (#24)',
        () async {
          // Level 1, B = 0: new = محب (4 errors). The other two are good, but
          // the any-محب rule (no averaging) must fail the whole session.
          final record = await sessionRepository.createSessionRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
            levelId: 1,
            hizbNumber: 59,
            attemptNumber: 1,
            newMemorizationErrors: 4, // محب at level 1
            recentReviewErrors: 1,
            distantReviewErrors: 2,
            repetitionsWithTeacher: 0,
            homeRepetitionsRequired: 0,
            pace: CurriculumPace.standard,
          );

          expect(record.passed, false);
        },
      );

      test(
        'passes when worst part is مجتهد (3 errors @ level 1, not محب)',
        () async {
          final record = await sessionRepository.createSessionRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
            levelId: 1,
            hizbNumber: 59,
            attemptNumber: 1,
            newMemorizationErrors: 3,
            recentReviewErrors: 3,
            distantReviewErrors: 3,
            repetitionsWithTeacher: 0,
            homeRepetitionsRequired: 0,
            pace: CurriculumPace.standard,
          );

          expect(record.passed, true);
        },
      );

      test(
        'pass/fail is level-based — 4 errors passes at a high level (#24)',
        () async {
          // Level 9, B = 4: محب only at >= 8 mistakes, so 4 errors → راسخ.
          // The same input that fails at level 1 must PASS at level 9.
          final record = await sessionRepository.createSessionRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
            levelId: 9,
            hizbNumber: 59,
            attemptNumber: 1,
            newMemorizationErrors: 4,
            recentReviewErrors: 4,
            distantReviewErrors: 4,
            repetitionsWithTeacher: 0,
            homeRepetitionsRequired: 0,
            pace: CurriculumPace.standard,
          );

          expect(record.passed, true);
        },
      );

      test('persists record to Firestore', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
          levelId: 1,
          hizbNumber: 59,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace.standard,
          notes: 'ممتاز',
        );

        final doc = await fakeFirestore
            .collection('session_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['student_id'], 'student1');
        expect(doc.data()?['notes'], 'ممتاز');
      });

      test('stores the recitation counts', () async {
        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(id: 'cs1', sessionNumber: 5, orderInLevel: 5),
          levelId: 1,
          hizbNumber: 59,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 5,
          homeRepetitionsRequired: 8,
          pace: CurriculumPace.standard,
        );

        expect(record.repetitionsWithTeacher, 5);
        expect(record.homeRepetitionsRequired, 8);
      });

      test('a genuine two-session meeting (2x pace) is recorded by its LAST '
          'session — its span, and its full coverage — not collapsed to a '
          'one-session shape (al_rasikhoon-g63)', () async {
        final meeting = _twoSessionMeeting(
          firstId: 'L1_J30_S5',
          secondId: 'L1_J30_S6',
          firstOrderInLevel: 5,
          firstSessionNumber: 5,
        );

        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: meeting,
          levelId: 1,
          hizbNumber: 59,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace(2),
        );

        // Named by the LAST session, so a reader that knows nothing of
        // pace still lands on the right point in the curriculum.
        expect(record.curriculumSessionId, 'L1_J30_S6');
        expect(record.sessionNumber, 6);
        expect(record.fromOrderInLevel, 5);
        expect(record.toOrderInLevel, 6);
        expect(record.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
        expect(record.isBatched, isTrue);

        // The stored doc must carry the TO value under `order_in_level` —
        // writing the FROM value would make a 2x student's record sort
        // BEFORE a 1x record at the same position and corrupt
        // `getLatestSessionRecord`.
        final stored = await fakeFirestore
            .collection('session_records')
            .doc(record.id)
            .get();
        expect(stored.data()?['order_in_level'], 6);
      });

      test('a 2x student whose batch truncates to ONE session (a تلقين or a '
          'سرد boundary) still records his PACE SETTING, not the truncated '
          'batch size (al_rasikhoon-g63)', () async {
        // The meeting itself covers only one session — as if the batch
        // stopped early — but the student's pace setting is 2x.
        final meeting = _meeting(
          id: 'L1_J30_S5',
          sessionNumber: 5,
          orderInLevel: 5,
        );
        expect(meeting.coversSessionIds.length, 1);

        final record = await sessionRepository.createSessionRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: meeting,
          levelId: 1,
          hizbNumber: 59,
          attemptNumber: 1,
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
          repetitionsWithTeacher: 0,
          homeRepetitionsRequired: 0,
          pace: CurriculumPace(2),
        );

        expect(record.paceAtTime, 2);
        expect(record.coversSessionIds.length, 1);
      });
    });

    group('createTalqeenRecord', () {
      test(
        'records a talqeen as happened, with no errors and no failure',
        () async {
          final record = await sessionRepository.createTalqeenRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(
              id: 'L1_J30_S1',
              sessionNumber: 1,
              orderInLevel: 1,
              kind: SessionKind.talqeen,
            ),
            levelId: 1,
            hizbNumber: 59,
            repetitionsWithTeacher: 4,
            homeRepetitionsRequired: 10,
            pace: CurriculumPace.standard,
          );

          expect(record.passed, isTrue);
          expect(record.grades.totalErrors, 0);
          expect(record.attemptNumber, 1);
          expect(record.repetitionsWithTeacher, 4);
          expect(record.homeRepetitionsRequired, 10);

          final stored = await fakeFirestore
              .collection('session_records')
              .doc(record.id)
              .get();
          expect(stored.data()!['home_repetitions_required'], 10);
        },
      );
    });

    group('getLatestSessionRecord', () {
      // Determinism comes from the `now` seam on `createTalqeenRecord` (see
      // `_writeSessionRecord`), not a sleep: the two records get explicit,
      // distinct instants, so which one is "later" is fixed by the test
      // rather than by how fast the machine running it happens to be.
      test(
        'returns the most recent record, which carries the home assignment',
        () async {
          await sessionRepository.createTalqeenRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(
              id: 'L1_J30_S1',
              sessionNumber: 1,
              orderInLevel: 1,
              kind: SessionKind.talqeen,
            ),
            levelId: 1,
            repetitionsWithTeacher: 3,
            homeRepetitionsRequired: 7,
            pace: CurriculumPace.standard,
            now: DateTime(2026, 1, 1, 10, 0, 0),
          );
          final newer = await sessionRepository.createTalqeenRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(
              id: 'L1_J30_S2',
              sessionNumber: 2,
              orderInLevel: 2,
              kind: SessionKind.talqeen,
            ),
            levelId: 1,
            repetitionsWithTeacher: 2,
            homeRepetitionsRequired: 12,
            pace: CurriculumPace.standard,
            now: DateTime(2026, 1, 1, 10, 0, 1),
          );

          final latest = await sessionRepository.getLatestSessionRecord(
            'student1',
          );
          expect(latest!.id, newer.id);
          expect(latest.curriculumSessionId, 'L1_J30_S2');
          expect(latest.homeRepetitionsRequired, 12);
        },
      );

      // The scenario the fix is actually for: two records sharing the exact
      // same `date` (a real clock tick, or a backfill). Ordering by `date`
      // alone leaves Firestore's tie-break unspecified — and `created_at`
      // cannot help, because it is stamped from the SAME `DateTime.now()`
      // call as `date` (see `_writeSessionRecord`), so it ties right along
      // with it.
      //
      // Both records go through the REAL write path (`createTalqeenRecord`),
      // using the `now` seam to force the tie, rather than hand-writing a
      // Firestore document with divergent `created_at` values that the app
      // itself could never produce.
      //
      // The write order is deliberately adversarial: the EARLIER-curriculum
      // record (`orderInLevel: 1`) is written FIRST, and the record further
      // along (`orderInLevel: 3`) is written SECOND. `fake_cloud_firestore`
      // resolves a tie on `date` alone by falling back to insertion order —
      // i.e. without the `order_in_level` tie-break, this query would hand
      // back whichever doc was written first, which here is the WRONG
      // (earlier-curriculum) record. Only an explicit `order_in_level` DESC
      // clause gets this right regardless of write order — proven by
      // sabotage: deleting that `.orderBy` call makes this test return the
      // first-written, lower-`orderInLevel` record and fail.
      test('breaks a `date` tie deterministically using `order_in_level`, not '
          'write order', () async {
        final tiedInstant = DateTime(2026, 1, 1, 12);

        await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(
            id: 'L1_J30_S1',
            sessionNumber: 1,
            orderInLevel: 1,
            kind: SessionKind.talqeen,
          ),
          levelId: 1,
          repetitionsWithTeacher: 1,
          homeRepetitionsRequired: 7,
          pace: CurriculumPace.standard,
          now: tiedInstant,
        );
        final furtherAlong = await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(
            id: 'L1_J30_S3',
            sessionNumber: 3,
            orderInLevel: 3,
            kind: SessionKind.talqeen,
          ),
          levelId: 1,
          repetitionsWithTeacher: 1,
          homeRepetitionsRequired: 12,
          pace: CurriculumPace.standard,
          now: tiedInstant,
        );

        final latest = await sessionRepository.getLatestSessionRecord(
          'student1',
        );

        expect(latest!.id, furtherAlong.id);
        expect(latest.toOrderInLevel, 3);
        expect(latest.homeRepetitionsRequired, 12);
      });

      test('returns null for a student with no records', () async {
        expect(
          await sessionRepository.getLatestSessionRecord('nobody'),
          isNull,
        );
      });
    });

    group('getSessionRecordsForStudent', () {
      setUp(() async {
        for (int i = 1; i <= 5; i++) {
          await fakeFirestore.collection('session_records').doc('sr$i').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs$i',
            'level_id': 1,
            'hizb_number': 59,
            'session_number': i,
            'date': Timestamp.fromDate(DateTime(2024, 1, i)),
            'attempt_number': 1,
            'grades': {
              'new_memorization_errors': i,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': i <= 3,
            'repetitions': 0,
            'created_at': Timestamp.now(),
          });
        }
        // Another student's record
        await fakeFirestore.collection('session_records').doc('sr-other').set({
          'student_id': 'student2',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'cs1',
          'date': Timestamp.now(),
          'attempt_number': 1,
          'grades': {
            'new_memorization_errors': 0,
            'recent_review_errors': 0,
            'distant_review_errors': 0,
          },
          'passed': true,
          'created_at': Timestamp.now(),
        });
      });

      test('returns only records for specified student', () async {
        final records = await sessionRepository.getSessionRecordsForStudent(
          'student1',
        );

        expect(records.length, 5);
        expect(records.every((r) => r.studentId == 'student1'), true);
      });

      test('returns records ordered by date descending', () async {
        final records = await sessionRepository.getSessionRecordsForStudent(
          'student1',
        );

        for (int i = 0; i < records.length - 1; i++) {
          expect(
            records[i].date.isAfter(records[i + 1].date) ||
                records[i].date.isAtSameMomentAs(records[i + 1].date),
            true,
          );
        }
      });

      test('respects limit parameter', () async {
        final records = await sessionRepository.getSessionRecordsForStudent(
          'student1',
          limit: 2,
        );

        expect(records.length, 2);
      });

      test('returns empty list for unknown student', () async {
        final records = await sessionRepository.getSessionRecordsForStudent(
          'nonexistent',
        );

        expect(records, isEmpty);
      });
    });

    group('createSardRecord', () {
      test('creates record with passing grade (0 errors)', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S30',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          scopeLabelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
        );

        expect(record.passed, true);
        expect(record.grade, 'راسخ');
        expect(record.errorCount, 0);
      });

      test('creates record with failing grade (7+ errors)', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S30',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          levelId: 1,
          attemptNumber: 2,
          errorCount: 8,
        );

        expect(record.passed, false);
        expect(record.grade, 'محب');
      });

      test(
        'a JUZ-tier سرد produces a record carrying its scope — the whole juz, '
        'no hizb at all',
        () async {
          // L1_J30_S67 is `سرد الجزء رقم 30 كاملًا`. A record keyed on a hizb
          // could not represent it: it has none.
          final record = await sessionRepository.createSardRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            curriculumSessionId: 'L1_J30_S67',
            tier: AssessmentTier.juz,
            juzNumbers: const [30],
            scopeLabelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
            levelId: 1,
            attemptNumber: 1,
            errorCount: 1,
          );

          final doc = await fakeFirestore
              .collection('sard_records')
              .doc(record.id)
              .get();
          expect(doc.data()?['curriculum_session_id'], 'L1_J30_S67');
          expect(doc.data()?['tier'], 'juz');
          expect(doc.data()?['juz_numbers'], [30]);
          expect(doc.data()?['hizb_number'], isNull);
          expect(
            doc.data()?['scope_label_ar'],
            'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
          );
        },
      );

      test(
        'a LEVEL-tier (cumulative) سرد produces a record covering every juz of '
        'the level',
        () async {
          final record = await sessionRepository.createSardRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            curriculumSessionId: 'L1_J28_S66',
            tier: AssessmentTier.cumulative,
            juzNumbers: const [28, 29, 30],
            scopeLabelAr:
                'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
            levelId: 1,
            attemptNumber: 1,
            errorCount: 2,
          );

          expect(record.tier, AssessmentTier.cumulative);
          expect(record.juzNumbers, [28, 29, 30]);

          final doc = await fakeFirestore
              .collection('sard_records')
              .doc(record.id)
              .get();
          expect(doc.data()?['tier'], 'cumulative');
          expect(doc.data()?['juz_numbers'], [28, 29, 30]);
        },
      );

      test('persists sard record to Firestore', () async {
        final record = await sessionRepository.createSardRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          curriculumSessionId: 'L1_J30_S30',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 3,
          notes: 'جيد',
        );

        final doc = await fakeFirestore
            .collection('sard_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['notes'], 'جيد');
        expect(doc.data()?['error_count'], 3);
      });

      test('an assessment may be retried without limit — the tenth attempt is '
          'recorded like the first', () async {
        // A student who cannot yet recite a juz keeps working at it: the
        // 3-attempt cap belongs to ordinary lessons alone.
        for (var attempt = 1; attempt <= 10; attempt++) {
          await sessionRepository.createSardRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            curriculumSessionId: 'L1_J30_S67',
            tier: AssessmentTier.juz,
            juzNumbers: const [30],
            levelId: 1,
            attemptNumber: attempt,
            errorCount: 9, // failing, over and over
          );
        }

        final count = await sessionRepository.getSardAttemptCount(
          studentId: 'student1',
          curriculumSessionId: 'L1_J30_S67',
        );
        expect(count, 10);
      });
    });

    group('getSardRecordsForStudent', () {
      test('returns sard records for student', () async {
        await fakeFirestore.collection('sard_records').doc('sard1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 2,
          'grade': 'متقن',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final records = await sessionRepository.getSardRecordsForStudent(
          'student1',
        );

        expect(records.length, 1);
        expect(records.first.studentId, 'student1');
      });
    });

    group('createExamRecord', () {
      test('creates exam record with passing grade', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          curriculumSessionId: 'L1_J30_S31',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 2,
        );

        expect(record.passed, true);
        expect(record.supervisorId, 'supervisor1');
        expect(record.errorCount, 2);
      });

      test('creates exam record with failing grade', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          curriculumSessionId: 'L1_J30_S31',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 10,
        );

        expect(record.passed, false);
      });

      test('a JUZ-tier اختبار produces a record carrying its scope', () async {
        // L1_J30_S68 is `اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات`
        // — the session the supervisor's queue is built on.
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          curriculumSessionId: 'L1_J30_S68',
          tier: AssessmentTier.juz,
          juzNumbers: const [30],
          scopeLabelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
        );

        expect(record.tier, AssessmentTier.juz);
        expect(record.hizbNumber, isNull);

        final doc = await fakeFirestore
            .collection('exam_records')
            .doc(record.id)
            .get();
        expect(doc.data()?['curriculum_session_id'], 'L1_J30_S68');
        expect(doc.data()?['tier'], 'juz');
        expect(
          doc.data()?['scope_label_ar'],
          'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
        );
      });

      test(
        'a LEVEL-tier (cumulative) اختبار covers every juz of the level',
        () async {
          final record = await sessionRepository.createExamRecord(
            studentId: 'student1',
            supervisorId: 'supervisor1',
            curriculumSessionId: 'L1_J28_S67',
            tier: AssessmentTier.cumulative,
            juzNumbers: const [28, 29, 30],
            levelId: 1,
            attemptNumber: 1,
            errorCount: 1,
          );

          expect(record.tier, AssessmentTier.cumulative);
          expect(record.juzNumbers, [28, 29, 30]);
        },
      );

      test(
        'an اختبار may be retried without limit, like every assessment',
        () async {
          for (var attempt = 1; attempt <= 12; attempt++) {
            await sessionRepository.createExamRecord(
              studentId: 'student1',
              supervisorId: 'supervisor1',
              curriculumSessionId: 'L1_J30_S68',
              tier: AssessmentTier.juz,
              juzNumbers: const [30],
              levelId: 1,
              attemptNumber: attempt,
              errorCount: 9,
            );
          }

          final count = await sessionRepository.getExamAttemptCount(
            studentId: 'student1',
            curriculumSessionId: 'L1_J30_S68',
          );
          expect(count, 12);
        },
      );

      test('persists exam record to Firestore', () async {
        final record = await sessionRepository.createExamRecord(
          studentId: 'student1',
          supervisorId: 'supervisor1',
          curriculumSessionId: 'L1_J30_S31',
          tier: AssessmentTier.unit,
          juzNumbers: const [30],
          hizbNumber: 59,
          levelId: 1,
          attemptNumber: 1,
          errorCount: 0,
          notes: 'ممتاز',
        );

        final doc = await fakeFirestore
            .collection('exam_records')
            .doc(record.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['supervisor_id'], 'supervisor1');
      });
    });

    group('getExamRecordsForStudent', () {
      test('returns exam records for student', () async {
        await fakeFirestore.collection('exam_records').doc('exam1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final records = await sessionRepository.getExamRecordsForStudent(
          'student1',
        );

        expect(records.length, 1);
        expect(records.first.passed, true);
      });
    });

    group('getStudentStatistics', () {
      test('calculates statistics correctly', () async {
        // 3 session records: 2 passed, 1 failed
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('session_records').doc('sr$i').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs$i',
            'date': Timestamp.now(),
            'attempt_number': 1,
            'grades': {
              'new_memorization_errors': i <= 2 ? 1 : 5,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': i <= 2,
            'created_at': Timestamp.now(),
          });
        }

        // 1 sard record: passed
        await fakeFirestore.collection('sard_records').doc('sard1').set({
          'student_id': 'student1',
          'teacher_id': 'teacher1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        // 1 exam record: failed
        await fakeFirestore.collection('exam_records').doc('exam1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 10,
          'grade': 'محب',
          'passed': false,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final stats = await sessionRepository.getStudentStatistics('student1');

        expect(stats['total_sessions'], 3);
        expect(stats['passed_sessions'], 2);
        expect(stats['session_pass_rate'], closeTo(0.667, 0.01));
        expect(stats['total_sards'], 1);
        expect(stats['passed_sards'], 1);
        expect(stats['total_exams'], 1);
        expect(stats['passed_exams'], 0);
      });

      // hibrahem/AlRasikhoon final-review finding #3: a تلقين record used to
      // write `passed: true` with no `kind` to tell it apart, so it inflated
      // `total_sessions`/`passed_sessions` with a phantom pass — a student
      // who failed every lesson of a unit but sat its تلقين would show one
      // pass instead of zero.
      test('a تلقين is attendance, not a graded pass — it must not inflate '
          'total_sessions/passed_sessions', () async {
        // 6 failed lessons.
        for (var i = 1; i <= 6; i++) {
          await sessionRepository.createSessionRecord(
            studentId: 'student1',
            teacherId: 'teacher1',
            meeting: _meeting(
              id: 'L1_J30_S$i',
              sessionNumber: i,
              orderInLevel: i,
            ),
            levelId: 1,
            hizbNumber: 59,
            attemptNumber: 1,
            newMemorizationErrors: 5, // محب at level 1 — always fails
            recentReviewErrors: 0,
            distantReviewErrors: 0,
            repetitionsWithTeacher: 0,
            homeRepetitionsRequired: 0,
            pace: CurriculumPace.standard,
          );
        }

        // The unit's تلقين — never graded, always "passes" unconditionally
        // by contract, but that is attendance, not a graded outcome.
        await sessionRepository.createTalqeenRecord(
          studentId: 'student1',
          teacherId: 'teacher1',
          meeting: _meeting(
            id: 'L1_J30_S7',
            sessionNumber: 7,
            orderInLevel: 7,
            kind: SessionKind.talqeen,
          ),
          levelId: 1,
          hizbNumber: 59,
          repetitionsWithTeacher: 4,
          homeRepetitionsRequired: 10,
          pace: CurriculumPace.standard,
        );

        final stats = await sessionRepository.getStudentStatistics('student1');

        // 6, not 7 — the تلقين record must not be counted as a session at
        // all for these purposes.
        expect(stats['total_sessions'], 6);
        // 0, not 1 — the تلقين's unconditional `passed: true` must not
        // read as a graded pass.
        expect(stats['passed_sessions'], 0);
        expect(stats['session_pass_rate'], 0);
      });

      test('returns zero rates for student with no records', () async {
        final stats = await sessionRepository.getStudentStatistics(
          'new-student',
        );

        expect(stats['total_sessions'], 0);
        expect(stats['passed_sessions'], 0);
        expect(stats['session_pass_rate'], 0);
        expect(stats['total_sards'], 0);
        expect(stats['total_exams'], 0);
      });
    });

    group('getSessionRecordsForTeacher', () {
      setUp(() async {
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('session_records').doc('tr$i').set({
            'student_id': 'student$i',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs$i',
            'date': Timestamp.fromDate(DateTime(2024, 1, i)),
            'attempt_number': 1,
            'grades': {
              'new_memorization_errors': 0,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': true,
            'created_at': Timestamp.now(),
          });
        }
        await fakeFirestore.collection('session_records').doc('tr-other').set({
          'student_id': 'student1',
          'teacher_id': 'teacher2',
          'curriculum_session_id': 'cs1',
          'date': Timestamp.now(),
          'attempt_number': 1,
          'grades': {
            'new_memorization_errors': 0,
            'recent_review_errors': 0,
            'distant_review_errors': 0,
          },
          'passed': true,
          'created_at': Timestamp.now(),
        });
      });

      test('returns records for specified teacher only', () async {
        final records = await sessionRepository.getSessionRecordsForTeacher(
          'teacher1',
        );

        expect(records.length, 3);
        expect(records.every((r) => r.teacherId == 'teacher1'), true);
      });

      test('respects limit parameter', () async {
        final records = await sessionRepository.getSessionRecordsForTeacher(
          'teacher1',
          limit: 2,
        );

        expect(records.length, 2);
      });

      test('returns empty for unknown teacher', () async {
        final records = await sessionRepository.getSessionRecordsForTeacher(
          'nobody',
        );

        expect(records, isEmpty);
      });
    });

    group('getAttemptCount', () {
      test('returns correct count', () async {
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('session_records').doc('att$i').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'cs-target',
            'date': Timestamp.now(),
            'attempt_number': i,
            'grades': {
              'new_memorization_errors': 0,
              'recent_review_errors': 0,
              'distant_review_errors': 0,
            },
            'passed': true,
            'created_at': Timestamp.now(),
          });
        }

        final count = await sessionRepository.getAttemptCount(
          studentId: 'student1',
          curriculumSessionId: 'cs-target',
        );

        expect(count, 3);
      });

      test('returns zero for no attempts', () async {
        final count = await sessionRepository.getAttemptCount(
          studentId: 'student1',
          curriculumSessionId: 'no-session',
        );

        expect(count, 0);
      });
    });

    group('getSardAttemptCount', () {
      test(
        'counts the attempts at THIS سرد — keyed on the curriculum session, so '
        'the hizb-59 سرد and the juz-30 سرد do not share a count',
        () async {
          for (int i = 1; i <= 2; i++) {
            await fakeFirestore.collection('sard_records').doc('sa$i').set({
              'student_id': 'student1',
              'teacher_id': 'teacher1',
              'curriculum_session_id': 'L1_J30_S30',
              'tier': 'unit',
              'hizb_number': 59,
              'juz_numbers': [30],
              'level_id': 1,
              'date': Timestamp.now(),
              'error_count': i,
              'grade': 'متقن',
              'passed': true,
              'attempt_number': i,
              'created_at': Timestamp.now(),
            });
          }
          // A juz-tier سرد of the SAME juz: a different session, a different
          // count. Keying on the hizb would have merged the two.
          await fakeFirestore.collection('sard_records').doc('sa-juz').set({
            'student_id': 'student1',
            'teacher_id': 'teacher1',
            'curriculum_session_id': 'L1_J30_S67',
            'tier': 'juz',
            'hizb_number': null,
            'juz_numbers': [30],
            'level_id': 1,
            'date': Timestamp.now(),
            'error_count': 0,
            'grade': 'راسخ',
            'passed': true,
            'attempt_number': 1,
            'created_at': Timestamp.now(),
          });

          expect(
            await sessionRepository.getSardAttemptCount(
              studentId: 'student1',
              curriculumSessionId: 'L1_J30_S30',
            ),
            2,
          );
          expect(
            await sessionRepository.getSardAttemptCount(
              studentId: 'student1',
              curriculumSessionId: 'L1_J30_S67',
            ),
            1,
          );
        },
      );

      test('returns zero when no sard attempts', () async {
        final count = await sessionRepository.getSardAttemptCount(
          studentId: 'student1',
          curriculumSessionId: 'L1_J30_S67',
        );

        expect(count, 0);
      });
    });

    group('getExamAttemptCount', () {
      test('returns correct exam attempt count', () async {
        await fakeFirestore.collection('exam_records').doc('ea1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final count = await sessionRepository.getExamAttemptCount(
          studentId: 'student1',
          curriculumSessionId: 'L1_J30_S30',
        );

        expect(count, 1);
      });

      test('returns zero when no exam attempts', () async {
        final count = await sessionRepository.getExamAttemptCount(
          studentId: 'nobody',
          curriculumSessionId: 'L1_J30_S31',
        );

        expect(count, 0);
      });
    });

    group('getExamRecordsForSupervisor', () {
      test('returns records for specified supervisor', () async {
        await fakeFirestore.collection('exam_records').doc('es1').set({
          'student_id': 'student1',
          'supervisor_id': 'supervisor1',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('exam_records').doc('es2').set({
          'student_id': 'student2',
          'supervisor_id': 'supervisor2',
          'curriculum_session_id': 'L1_J30_S30',
          'tier': 'unit',
          'hizb_number': 59,
          'juz_numbers': [30],
          'level_id': 1,
          'date': Timestamp.now(),
          'error_count': 0,
          'grade': 'راسخ',
          'passed': true,
          'attempt_number': 1,
          'created_at': Timestamp.now(),
        });

        final records = await sessionRepository.getExamRecordsForSupervisor(
          'supervisor1',
        );

        expect(records.length, 1);
        expect(records.first.supervisorId, 'supervisor1');
      });
    });
  });
}
