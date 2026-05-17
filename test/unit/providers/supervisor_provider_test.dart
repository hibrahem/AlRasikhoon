import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/exam_record_model.dart';
import 'package:al_rasikhoon/data/models/institute_model.dart';
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
/// `examQueueProvider` (session-36 students aggregated across the
/// supervisor's institutes) and `supervisorStatsProvider`
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

  UserModel buildSupervisor({String id = 'supervisor-1'}) {
    return UserModel(
      id: id,
      username: 'supervisor_one',
      email: 'supervisor_one@alrasikhoon.local',
      name: 'مشرف',
      role: UserRole.supervisor,
      authProvider: UserAuthProvider.emailPassword,
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

  StudentWithUser buildStudentWithUser({required String studentId}) {
    return StudentWithUser(
      student: StudentModel(
        id: studentId,
        userId: 'user-$studentId',
        instituteId: 'institute-1',
        currentSession: 36,
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
      hizbNumber: 59,
      juzNumber: 30,
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
      'aggregates session-36 students across all supervisor institutes',
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
        () => mockInstituteRepository.getInstitutesForSupervisor(
          'supervisor-1',
        ),
      ).thenAnswer((_) async => []);

      final container = makeContainer(user: buildSupervisor());

      final queue = await container.read(examQueueProvider.future);

      expect(queue, isEmpty);
      verifyNever(
        () => mockStudentRepository.getStudentsReadyForExam(any()),
      );
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

    test(
      'pendingExams equals the exam-queue length',
      () async {
        when(
          () => mockInstituteRepository.getInstitutesForSupervisor(
            'supervisor-1',
          ),
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
      },
    );

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
}
