import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

class _MockFirebaseService extends Mock implements FirebaseService {}

/// A unit shaped like the real curriculum — the same fixture
/// `paced_session_test.dart` composes from: a تلقين that opens it, six
/// lessons whose recent review slides over the previous two, a سرد, a filler
/// lesson, an اختبار, and another filler lesson so the assessments' "stands
/// alone" behaviour is load-bearing.
///
/// order 1  تلقين
/// order 2-6 lesson
/// order 7  سرد     — a doubled student starting at order 6 must stop here.
/// order 8  lesson
/// order 9  اختبار
/// order 10 lesson
SessionModel _session({
  required int order,
  SessionKind kind = SessionKind.lesson,
}) => SessionModel(
  id: 'L1_J30_S$order',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: order,
  orderInLevel: order,
  kind: kind,
  currentLevelContent: kind == SessionKind.lesson || kind == SessionKind.talqeen
      ? QuranContent(
          fromSurah: 'النبأ',
          fromVerse: order,
          toSurah: 'النبأ',
          toVerse: order + 1,
        )
      : null,
);

Future<void> _seedUnit(FakeFirebaseFirestore firestore) async {
  final sessions = [
    _session(order: 1, kind: SessionKind.talqeen),
    _session(order: 2),
    _session(order: 3),
    _session(order: 4),
    _session(order: 5),
    _session(order: 6),
    _session(order: 7, kind: SessionKind.sard),
    _session(order: 8),
    _session(order: 9, kind: SessionKind.exam),
    _session(order: 10),
  ];
  for (final session in sessions) {
    await firestore
        .collection('sessions')
        .doc(session.id)
        .set(session.toFirestore());
  }
}

/// Tests for the teacher-facing Riverpod providers (TEST_CASES.md §5.2):
/// `teacherStudentsProvider` and the `activeSessionProvider`
/// (`ActiveSessionState` / `ActiveSessionNotifier`) — error tracking,
/// pass detection, and `completeSession` advance-on-pass /
/// increment-on-fail behaviour.
void main() {
  late MockStudentRepository mockStudentRepository;

  setUp(() {
    mockStudentRepository = MockStudentRepository();
  });

  UserModel buildTeacher({String id = 'teacher-1'}) {
    return UserModel(
      id: id,
      username: 'teacher_one',
      email: 'teacher_one@alrasikhoon.local',
      name: 'معلم',
      role: UserRole.teacher,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentModel buildStudent({
    String id = 'student-1',
    String userId = 'user-1',
    String instituteId = 'institute-1',
    int currentLevel = 1,
    int currentJuz = 30,
    int currentHizb = 59,
    int currentSession = 5,
    int currentAttempt = 1,
    // A distinctive non-default value (StudentModel defaults to 1) so a
    // record carrying the DEFAULT instead of the student's own value would
    // be caught, not masked by a coincidental match.
    int currentOrderInLevel = 8,
  }) {
    return StudentModel(
      id: id,
      userId: userId,
      instituteId: instituteId,
      teacherId: 'teacher-1',
      currentLevel: currentLevel,
      currentJuz: currentJuz,
      currentHizb: currentHizb,
      currentSession: currentSession,
      currentAttempt: currentAttempt,
      currentOrderInLevel: currentOrderInLevel,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentWithUser buildStudentWithUser({String studentId = 'student-1'}) {
    return StudentWithUser(
      student: buildStudent(id: studentId),
      user: UserModel(
        id: 'user-1',
        username: 'pupil',
        email: 'pupil@alrasikhoon.local',
        name: 'طالب',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  ProviderContainer makeContainer({UserModel? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('teacherStudentsProvider', () {
    test('returns the students assigned to the teacher', () async {
      final students = [
        buildStudentWithUser(studentId: 's-1'),
        buildStudentWithUser(studentId: 's-2'),
      ];
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => students);

      final container = makeContainer(user: buildTeacher());

      final result = await container.read(teacherStudentsProvider.future);

      expect(result, hasLength(2));
      verify(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).called(1);
    });

    test('returns empty list when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final result = await container.read(teacherStudentsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => mockStudentRepository.getStudentsForTeacher(any()));
    });
  });

  group('ActiveSessionState', () {
    test('starts null and is populated by startSession', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      expect(container.read(activeSessionProvider), isNull);

      notifier.startSession('student-1');

      final state = container.read(activeSessionProvider);
      expect(state, isNotNull);
      expect(state!.studentId, 'student-1');
      expect(state.currentPart, 1);
      expect(state.totalErrors, 0);
    });

    test('tracks per-part error counts as they are recorded', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 2);
      notifier.setPartErrors(2, 1);
      notifier.setPartErrors(3, 0);

      final state = container.read(activeSessionProvider)!;
      expect(state.part1Errors, 2);
      expect(state.part2Errors, 1);
      expect(state.part3Errors, 0);
      expect(state.totalErrors, 3);
    });

    test('errorsForPart reflects the current part', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 4);
      expect(container.read(activeSessionProvider)!.errorsForPart, 4);

      notifier.nextPart();
      notifier.setPartErrors(2, 7);
      expect(container.read(activeSessionProvider)!.currentPart, 2);
      expect(container.read(activeSessionProvider)!.errorsForPart, 7);
    });

    // Session pass/fail is level-based and fails on ANY محب component (#24).
    // At level 1, base B = 0: محب starts at 4 mistakes, مجتهد is exactly 3.
    test('passesForLevel is true when no part is محب (worst = مجتهد)', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.setPartErrors(1, 3);
      notifier.setPartErrors(2, 3);
      notifier.setPartErrors(3, 3);

      expect(container.read(activeSessionProvider)!.passesForLevel(1), isTrue);
    });

    test(
      'passesForLevel is false when any part is محب (4 errors at level 1)',
      () {
        final container = makeContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);

        notifier.startSession('student-1');
        notifier.setPartErrors(1, 3);
        notifier.setPartErrors(2, 4);
        notifier.setPartErrors(3, 0);

        expect(
          container.read(activeSessionProvider)!.passesForLevel(1),
          isFalse,
        );
      },
    );

    test('nextPart caps at part 3', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      notifier.nextPart();
      notifier.nextPart();
      notifier.nextPart();
      notifier.nextPart();

      expect(container.read(activeSessionProvider)!.currentPart, 3);
    });

    test('endSession clears the active state', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.startSession('student-1');
      expect(container.read(activeSessionProvider), isNotNull);

      notifier.endSession();
      expect(container.read(activeSessionProvider), isNull);
    });
  });

  // The zero-floor on both recitation counts is a domain invariant, not a UI
  // affordance: `RecitationCountsCard` disables its decrement button at zero,
  // but that is the only caller today. Any future caller — another screen, a
  // script, a test — must find the SAME floor enforced here, in the state
  // that actually holds the count, whatever it passes.
  group('ActiveSessionNotifier.setRepetitionsWithTeacher', () {
    test('accepts a non-negative value', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');

      notifier.setRepetitionsWithTeacher(6);

      expect(container.read(activeSessionProvider)!.repetitionsWithTeacher, 6);
    });

    test(
      'throws ArgumentError rather than silently clamping a negative value',
      () {
        final container = makeContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');

        expect(
          () => notifier.setRepetitionsWithTeacher(-1),
          throwsArgumentError,
        );
        // State is left untouched by the rejected call.
        expect(
          container.read(activeSessionProvider)!.repetitionsWithTeacher,
          0,
        );
      },
    );
  });

  group('ActiveSessionNotifier.setHomeRepetitionsRequired', () {
    test('accepts a non-negative value', () {
      final container = makeContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');

      notifier.setHomeRepetitionsRequired(15);

      expect(
        container.read(activeSessionProvider)!.homeRepetitionsRequired,
        15,
      );
    });

    test(
      'throws ArgumentError rather than silently clamping a negative value',
      () {
        final container = makeContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');

        expect(
          () => notifier.setHomeRepetitionsRequired(-1),
          throwsArgumentError,
        );
        expect(
          container.read(activeSessionProvider)!.homeRepetitionsRequired,
          0,
        );
      },
    );
  });

  // `completeSession` now composes a meeting from the curriculum before
  // writing anything (Task 7), so `curriculumRepositoryProvider` and
  // `sessionRepositoryProvider` must be REAL, fake-Firestore-backed
  // implementations rather than mocks — a mocked `createSessionRecord` can no
  // longer stand in for the whole `PacedSessionComposer` → `createSessionRecord`
  // → `advanceStudentSession` pipeline these tests exercise.
  group('ActiveSessionNotifier.completeSession', () {
    late FakeFirebaseFirestore firestore;
    late CurriculumRepository curriculumRepository;
    late SessionRepository sessionRepository;
    late StudentRepository studentRepository;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      curriculumRepository = CurriculumRepository(firestore: firestore);
      sessionRepository = SessionRepository(firestore: firestore);
      studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: UserRepository(firestore: firestore),
        curriculumRepository: curriculumRepository,
      );

      await _seedUnit(firestore);
      await firestore.collection('users').doc('user-1').set({
        'username': 'pupil',
        'email': 'pupil@alrasikhoon.local',
        'name': 'طالب',
        'role': 'student',
        'is_active': true,
        'created_at': Timestamp.now(),
      });
      // Level 1's catalog says the level runs far past order 10 — the seeded
      // unit above is a deliberately incomplete slice of it, which is exactly
      // what the "surfaces curriculumDataMissing" test needs.
      await firestore.collection('levels').doc('level_1').set({
        'id': 1,
        'session_count': 210,
        'order': 1,
      });
    });

    Future<void> seedStudent({
      String id = 'student-1',
      int currentOrderInLevel = 8,
      int currentAttempt = 1,
      CurriculumPace? pace,
    }) async {
      final session = await curriculumRepository.getSessionByOrderInLevel(
        level: 1,
        orderInLevel: currentOrderInLevel,
      );
      await firestore.collection('students').doc(id).set({
        'user_id': 'user-1',
        'institute_id': 'institute-1',
        'teacher_id': 'teacher-1',
        'current_level': 1,
        'current_juz': session!.juzNumber,
        'current_session': session.sessionNumber,
        'current_order_in_level': currentOrderInLevel,
        'current_hizb': null,
        'current_session_id': session.id,
        'current_session_kind': session.kind.value,
        'current_session_tier': session.scope?.tier.value,
        'current_session_label_ar': session.scope?.labelAr,
        'current_attempt': currentAttempt,
        'completed_levels': <int>[],
        'unlocked_levels': const [1],
        'is_active': true,
        'created_at': Timestamp.now(),
        'pace': (pace ?? CurriculumPace.standard).toJson(),
      });
    }

    ProviderContainer makeRealContainer({UserModel? user}) {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('advances the student session when the record passes', () async {
      await seedStudent();

      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 1);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();

      expect(record, isNotNull);
      expect(record!.passed, isTrue);
      expect(container.read(activeSessionProvider)!.isComplete, isTrue);
      expect(
        container.read(activeSessionProvider)!.advanceOutcome,
        StudentAdvanceOutcome.advanced,
      );

      // The student's OWN currentOrderInLevel (8, seeded above) must reach
      // the written record verbatim — never a hardcoded or recomputed value.
      expect(record.fromOrderInLevel, 8);
      expect(record.toOrderInLevel, 8);
      expect(container.read(activeSessionProvider)!.meeting!.toOrderInLevel, 8);

      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentOrderInLevel, 9);
    });

    // hibrahem/AlRasikhoon final-review finding #2: advanceStudentSession can
    // silently no-op (no seeded curriculum data ahead of the student). The
    // caller must be able to tell that apart from a real advance instead of
    // reporting an unqualified success — this is the signal
    // session_summary_screen.dart reads to decide between the plain "تم حفظ"
    // success SnackBar and the "تعذر تحديث تقدم الطالب" warning.
    test(
      'surfaces curriculumDataMissing instead of silently reporting success',
      () async {
        // Order 10 is the last session seeded by `_seedUnit`; the catalog
        // says level 1 keeps going past it, so the walk cannot tell whether
        // order 11 is really the end of the level or just unseeded.
        await seedStudent(currentOrderInLevel: 10);

        final container = makeRealContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');
        notifier.setPartErrors(1, 1);
        notifier.setPartErrors(2, 0);
        notifier.setPartErrors(3, 0);

        final record = await notifier.completeSession();

        // The record itself still reports a pass — the session was graded
        // correctly and saved. Only the progress update failed.
        expect(record, isNotNull);
        expect(record!.passed, isTrue);
        // This is the flag a screen must branch on to avoid telling the user
        // an unqualified "تم حفظ - ناجح" when the student didn't actually move.
        expect(
          container.read(activeSessionProvider)!.advanceOutcome,
          StudentAdvanceOutcome.curriculumDataMissing,
        );

        // Nothing was written: the student's position is untouched.
        final student = await studentRepository.getStudentById('student-1');
        expect(student!.currentOrderInLevel, 10);
      },
    );

    test('increments the attempt when the record fails', () async {
      await seedStudent();

      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 5);

      final record = await notifier.completeSession();

      expect(record, isNotNull);
      expect(record!.passed, isFalse);

      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentAttempt, 2, reason: 'incremented, not reset');
      expect(
        student.currentOrderInLevel,
        8,
        reason: 'unchanged — a failed session never advances',
      );
    });

    test('returns null when there is no active session state', () async {
      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);

      final record = await notifier.completeSession();

      expect(record, isNull);
    });

    test('returns null when no user is authenticated', () async {
      await seedStudent();

      final container = makeRealContainer(user: null);
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');

      final record = await notifier.completeSession();

      expect(record, isNull);
      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentOrderInLevel, 8, reason: 'nothing was written');
    });
  });

  // Task 7: the teacher composes and grades the whole MEETING a paced
  // student is due — possibly several curriculum sessions at once — writes
  // ONE record spanning it, and advances the student past everything it
  // covered.
  group('paced meetings — completeSession at the student\'s live pace', () {
    late FakeFirebaseFirestore firestore;
    late CurriculumRepository curriculumRepository;
    late SessionRepository sessionRepository;
    late StudentRepository studentRepository;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      curriculumRepository = CurriculumRepository(firestore: firestore);
      sessionRepository = SessionRepository(firestore: firestore);
      studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: UserRepository(firestore: firestore),
        curriculumRepository: curriculumRepository,
      );

      await _seedUnit(firestore);
      await firestore.collection('users').doc('user-1').set({
        'username': 'pupil',
        'email': 'pupil@alrasikhoon.local',
        'name': 'طالب',
        'role': 'student',
        'is_active': true,
        'created_at': Timestamp.now(),
      });
    });

    Future<void> seedStudent({
      String id = 'student-1',
      required int currentOrderInLevel,
      required CurriculumPace pace,
      int currentAttempt = 1,
    }) async {
      final session = await curriculumRepository.getSessionByOrderInLevel(
        level: 1,
        orderInLevel: currentOrderInLevel,
      );
      await firestore.collection('students').doc(id).set({
        'user_id': 'user-1',
        'institute_id': 'institute-1',
        'teacher_id': 'teacher-1',
        'current_level': 1,
        'current_juz': session!.juzNumber,
        'current_session': session.sessionNumber,
        'current_order_in_level': currentOrderInLevel,
        'current_hizb': null,
        'current_session_id': session.id,
        'current_session_kind': session.kind.value,
        'current_session_tier': session.scope?.tier.value,
        'current_session_label_ar': session.scope?.labelAr,
        'current_attempt': currentAttempt,
        'completed_levels': <int>[],
        'unlocked_levels': const [1],
        'is_active': true,
        'created_at': Timestamp.now(),
        'pace': pace.toJson(),
      });
    }

    ProviderContainer makeRealContainer({UserModel? user}) {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test("a doubled student's meeting discharges two sessions and advances "
        'past both', () async {
      // Student at order 5 of level 1, pace 2. Orders 5 and 6 are lessons.
      // One recitation → one record covering both → next meeting starts
      // at 7.
      await seedStudent(currentOrderInLevel: 5, pace: CurriculumPace(2));

      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 1);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 6);
      expect(record.paceAtTime, 2);
      expect(record.passed, isTrue);

      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentOrderInLevel, 7);
    });

    test(
      'a doubled student who fails repeats the whole meeting, not half of it',
      () async {
        // Errors high enough to fail at level 1.
        await seedStudent(currentOrderInLevel: 5, pace: CurriculumPace(2));

        final container = makeRealContainer(user: buildTeacher());
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.startSession('student-1');
        notifier.setPartErrors(1, 5);

        final record = await notifier.completeSession();

        expect(record!.passed, isFalse);
        final student = await studentRepository.getStudentById('student-1');
        expect(
          student!.currentOrderInLevel,
          5,
          reason: 'he stays on the meeting',
        );
        expect(student.currentAttempt, 2);
      },
    );

    test('a standard student is completely unaffected', () async {
      await seedStudent(currentOrderInLevel: 5, pace: CurriculumPace.standard);

      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 1);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S5']);
      expect(record.fromOrderInLevel, 5);
      expect(record.toOrderInLevel, 5);
      expect(record.paceAtTime, 1);

      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentOrderInLevel, 6);
    });

    test('a doubled student still meets the سرد alone', () async {
      // Student at order 6; order 7 is the سرد. The batch takes only order 6.
      await seedStudent(currentOrderInLevel: 6, pace: CurriculumPace(2));

      final container = makeRealContainer(user: buildTeacher());
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 1);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();

      expect(record!.coversSessionIds, ['L1_J30_S6']);
      final student = await studentRepository.getStudentById('student-1');
      expect(student!.currentOrderInLevel, 7, reason: 'he lands ON the سرد');
    });
  });
}
