import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/exam_record_model.dart';
import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

class MockInstituteRepository extends Mock implements InstituteRepository {}

class MockSessionRepository extends Mock implements SessionRepository {}

/// Tests for the supervisor-facing Riverpod providers (TEST_CASES.md §5.3):
/// `examQueueProvider` (students STANDING on an اختبار — whatever its number —
/// aggregated across the supervisor's institutes) and `supervisorStatsProvider`
/// (pending count + today's pass/fail stats).
void main() {
  late MockStudentRepository mockStudentRepository;
  late MockInstituteRepository mockInstituteRepository;
  late MockSessionRepository mockSessionRepository;

  setUpAll(() {
    // `getExamRecordsForSupervisor` takes nullable DateTime named args that
    // supervisorStatsProvider fills with DateTime.now()-derived bounds.
    // mocktail needs a fallback value registered for the matched type.
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    mockStudentRepository = MockStudentRepository();
    mockInstituteRepository = MockInstituteRepository();
    mockSessionRepository = MockSessionRepository();
  });

  UserModel buildSupervisor({String id = 'supervisor-1', String? instituteId}) {
    return UserModel(
      id: id,
      username: 'supervisor_one',
      email: 'supervisor_one@alrasikhoon.local',
      name: 'مشرف',
      role: UserRole.supervisor,
      authProvider: UserAuthProvider.emailPassword,
      instituteId: instituteId,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  InstituteModel buildInstitute({required String id}) {
    return InstituteModel(
      id: id,
      name: 'معهد $id',
      location: 'الرياض',
      createdBy: 'admin-1',
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentWithUser buildStudentWithUser({
    required String studentId,
    String instituteId = 'institute-1',
  }) {
    return StudentWithUser(
      // A student waiting for an اختبار is one STANDING on an exam session —
      // the juz-30 اختبار of level 1 is session 68, not 36.
      student: StudentModel(
        id: studentId,
        userId: 'user-$studentId',
        instituteId: instituteId,
        currentSession: 68,
        currentOrderInLevel: 68,
        currentSessionId: 'L1_J30_S68',
        currentSessionKind: SessionKind.exam,
        currentSessionTier: AssessmentTier.juz,
        currentSessionLabelAr:
            'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
        createdAt: DateTime(2026, 1, 1),
      ),
      user: UserModel(
        id: 'user-$studentId',
        username: 'pupil_$studentId',
        email: 'pupil_$studentId@alrasikhoon.local',
        name: 'طالب $studentId',
        role: UserRole.student,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  ExamRecordModel buildExam({required String id, required bool passed}) {
    return ExamRecordModel(
      id: id,
      studentId: 'student-$id',
      supervisorId: 'supervisor-1',
      curriculumSessionId: 'L1_J30_S31',
      tier: AssessmentTier.unit,
      juzNumbers: const [30],
      hizbNumber: 59,
      scopeLabelAr: 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
      levelId: 1,
      date: DateTime(2026, 1, 2),
      errorCount: passed ? 1 : 5,
      grade: passed ? 'متقن' : 'محب',
      passed: passed,
      attemptNumber: 1,
      createdAt: DateTime(2026, 1, 2),
    );
  }

  ProviderContainer makeContainer({UserModel? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
        instituteRepositoryProvider.overrideWithValue(mockInstituteRepository),
        sessionRepositoryProvider.overrideWithValue(mockSessionRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('examQueueProvider', () {
    test(
      'aggregates exam-standing students across all supervisor institutes',
      () async {
        when(
          () => mockInstituteRepository.getInstitutesForSupervisor(
            'supervisor-1',
          ),
        ).thenAnswer(
          (_) async => [
            buildInstitute(id: 'inst-a'),
            buildInstitute(id: 'inst-b'),
          ],
        );
        when(
          () => mockStudentRepository.getStudentsReadyForExam('inst-a'),
        ).thenAnswer((_) async => [buildStudentWithUser(studentId: 's-1')]);
        when(
          () => mockStudentRepository.getStudentsReadyForExam('inst-b'),
        ).thenAnswer(
          (_) async => [
            buildStudentWithUser(studentId: 's-2'),
            buildStudentWithUser(studentId: 's-3'),
          ],
        );

        final container = makeContainer(user: buildSupervisor());

        final queue = await container.read(examQueueProvider.future);

        expect(queue, hasLength(3));
        verify(
          () => mockStudentRepository.getStudentsReadyForExam('inst-a'),
        ).called(1);
        verify(
          () => mockStudentRepository.getStudentsReadyForExam('inst-b'),
        ).called(1);
      },
    );

    test('returns empty list when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final queue = await container.read(examQueueProvider.future);

      expect(queue, isEmpty);
      verifyNever(
        () => mockInstituteRepository.getInstitutesForSupervisor(any()),
      );
    });

    test('returns empty list when supervisor has no institutes', () async {
      when(
        () =>
            mockInstituteRepository.getInstitutesForSupervisor('supervisor-1'),
      ).thenAnswer((_) async => []);

      final container = makeContainer(user: buildSupervisor());

      final queue = await container.read(examQueueProvider.future);

      expect(queue, isEmpty);
      verifyNever(() => mockStudentRepository.getStudentsReadyForExam(any()));
    });
  });

  group('supervisorStatsProvider', () {
    test('returns empty stats when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final stats = await container.read(supervisorStatsProvider.future);

      expect(stats.pendingExams, 0);
      expect(stats.completedToday, 0);
      expect(stats.passedToday, 0);
      expect(stats.failedToday, 0);
    });

    test('pendingExams equals the exam-queue length', () async {
      when(
        () =>
            mockInstituteRepository.getInstitutesForSupervisor('supervisor-1'),
      ).thenAnswer((_) async => [buildInstitute(id: 'inst-a')]);
      when(
        () => mockStudentRepository.getStudentsReadyForExam('inst-a'),
      ).thenAnswer(
        (_) async => [
          buildStudentWithUser(studentId: 's-1'),
          buildStudentWithUser(studentId: 's-2'),
        ],
      );
      when(
        () => mockSessionRepository.getExamRecordsForSupervisor(
          'supervisor-1',
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) async => []);

      final container = makeContainer(user: buildSupervisor());

      final stats = await container.read(supervisorStatsProvider.future);

      expect(stats.pendingExams, 2);
    });

    test(
      "today's stats split completed exams into passed and failed",
      () async {
        when(
          () => mockInstituteRepository.getInstitutesForSupervisor(
            'supervisor-1',
          ),
        ).thenAnswer((_) async => [buildInstitute(id: 'inst-a')]);
        when(
          () => mockStudentRepository.getStudentsReadyForExam('inst-a'),
        ).thenAnswer((_) async => [buildStudentWithUser(studentId: 's-1')]);
        when(
          () => mockSessionRepository.getExamRecordsForSupervisor(
            'supervisor-1',
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer(
          (_) async => [
            buildExam(id: 'e1', passed: true),
            buildExam(id: 'e2', passed: true),
            buildExam(id: 'e3', passed: false),
          ],
        );

        final container = makeContainer(user: buildSupervisor());

        final stats = await container.read(supervisorStatsProvider.future);

        expect(stats.pendingExams, 1);
        expect(stats.completedToday, 3);
        expect(stats.passedToday, 2);
        expect(stats.failedToday, 1);
      },
    );
  });

  // #28 / AgDR-0003 — institute-scoped, teacher-parity student management.
  // The supervisor's scope is read off users/{uid}.institute_id; the providers
  // must only ever surface that one institute's students.
  group('supervisorInstituteIdProvider', () {
    test('exposes the institute bound on the supervisor user doc', () {
      final container = makeContainer(
        user: buildSupervisor(instituteId: 'inst-a'),
      );

      expect(container.read(supervisorInstituteIdProvider), 'inst-a');
    });

    test('is null when no user is authenticated', () {
      final container = makeContainer(user: null);

      expect(container.read(supervisorInstituteIdProvider), isNull);
    });

    test('is null when the supervisor has no institute bound', () {
      final container = makeContainer(user: buildSupervisor());

      expect(container.read(supervisorInstituteIdProvider), isNull);
    });
  });

  group('supervisorStudentsProvider', () {
    test(
      "returns only the supervisor's institute students (scoped read)",
      () async {
        when(
          () => mockStudentRepository.getStudentsForInstitute('inst-a'),
        ).thenAnswer(
          (_) async => [
            buildStudentWithUser(studentId: 's-1', instituteId: 'inst-a'),
            buildStudentWithUser(studentId: 's-2', instituteId: 'inst-a'),
          ],
        );

        final container = makeContainer(
          user: buildSupervisor(instituteId: 'inst-a'),
        );

        final students = await container.read(
          supervisorStudentsProvider.future,
        );

        expect(students, hasLength(2));
        expect(
          students.every((s) => s.student.instituteId == 'inst-a'),
          isTrue,
        );
        // The scoped query is the ONLY query issued — the provider never
        // reaches for a cross-institute or unscoped listing.
        verify(
          () => mockStudentRepository.getStudentsForInstitute('inst-a'),
        ).called(1);
        verifyNever(() => mockStudentRepository.getAllStudents());
        verifyNever(
          () => mockStudentRepository.getStudentsForInstitute(
            any(that: isNot('inst-a')),
          ),
        );
      },
    );

    test('queries the bound institute, never another institute', () async {
      when(
        () => mockStudentRepository.getStudentsForInstitute('inst-a'),
      ).thenAnswer((_) async => []);

      final container = makeContainer(
        user: buildSupervisor(instituteId: 'inst-a'),
      );

      await container.read(supervisorStudentsProvider.future);

      // A supervisor bound to inst-a can never trigger a read for inst-b —
      // cross-institute access is impossible at the provider layer.
      verifyNever(
        () => mockStudentRepository.getStudentsForInstitute('inst-b'),
      );
    });

    test('returns empty when the supervisor has no institute bound', () async {
      final container = makeContainer(user: buildSupervisor());

      final students = await container.read(supervisorStudentsProvider.future);

      expect(students, isEmpty);
      verifyNever(() => mockStudentRepository.getStudentsForInstitute(any()));
    });

    test('returns empty when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final students = await container.read(supervisorStudentsProvider.future);

      expect(students, isEmpty);
      verifyNever(() => mockStudentRepository.getStudentsForInstitute(any()));
    });
  });

  group('supervisorStudentProvider', () {
    test('resolves a student that is in the institute scope', () async {
      when(
        () => mockStudentRepository.getStudentsForInstitute('inst-a'),
      ).thenAnswer(
        (_) async => [
          buildStudentWithUser(studentId: 's-1', instituteId: 'inst-a'),
        ],
      );

      final container = makeContainer(
        user: buildSupervisor(instituteId: 'inst-a'),
      );

      final student = await container.read(
        supervisorStudentProvider('s-1').future,
      );

      expect(student, isNotNull);
      expect(student!.student.id, 's-1');
    });

    test('returns null for a student outside the institute scope '
        '(cross-institute access denied, no leak)', () async {
      // The scoped listing for inst-a does NOT contain s-other (which lives
      // in inst-b); resolving it must yield null rather than leak the record.
      when(
        () => mockStudentRepository.getStudentsForInstitute('inst-a'),
      ).thenAnswer(
        (_) async => [
          buildStudentWithUser(studentId: 's-1', instituteId: 'inst-a'),
        ],
      );

      final container = makeContainer(
        user: buildSupervisor(instituteId: 'inst-a'),
      );

      final student = await container.read(
        supervisorStudentProvider('s-other').future,
      );

      expect(student, isNull);
    });
  });
}
