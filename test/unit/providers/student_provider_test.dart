import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/shared/providers/current_student_provider.dart';
import 'package:al_rasikhoon/shared/providers/stats_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

class MockSessionRepository extends Mock implements SessionRepository {}

/// Tests for the student-facing Riverpod providers (TEST_CASES.md §5.1).
///
/// Strategy: `currentStudentProvider` / `studentStatsProvider` depend on
/// `currentUserProvider` (a plain `Provider<UserModel?>`) plus the
/// `studentRepositoryProvider` / `sessionRepositoryProvider`. We override
/// `currentUserProvider` directly with a value (bypassing the Firebase auth
/// chain entirely) and override the repo providers with mocktail mocks, then
/// drive everything through a `ProviderContainer` exactly as the existing
/// `auth_repository_test.dart` does.
void main() {
  late MockStudentRepository mockStudentRepository;
  late MockSessionRepository mockSessionRepository;

  setUp(() {
    mockStudentRepository = MockStudentRepository();
    mockSessionRepository = MockSessionRepository();
  });

  UserModel buildUser({
    String id = 'user-1',
    UserRole role = UserRole.student,
  }) {
    return UserModel(
      id: id,
      username: 'student_one',
      email: 'student_one@alrasikhoon.local',
      name: 'طالب',
      role: role,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  StudentModel buildStudent({
    String id = 'student-1',
    String userId = 'user-1',
    int currentLevel = 1,
    int currentJuz = 30,
    int currentHizb = 59,
    int currentSession = 1,
    List<int> completedLevels = const [],
    List<int> unlockedLevels = const [1],
  }) {
    return StudentModel(
      id: id,
      userId: userId,
      instituteId: 'institute-1',
      teacherId: 'teacher-1',
      currentLevel: currentLevel,
      currentJuz: currentJuz,
      currentHizb: currentHizb,
      currentSession: currentSession,
      completedLevels: completedLevels,
      unlockedLevels: unlockedLevels,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  /// Builds a container with the current user overridden to [user] (or null)
  /// and the two data repositories wired to the mocks above.
  ProviderContainer makeContainer({UserModel? user}) {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
        sessionRepositoryProvider.overrideWithValue(mockSessionRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('currentStudentProvider', () {
    test('returns the logged-in student record for a student user', () async {
      final student = buildStudent();
      when(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).thenAnswer((_) async => student);

      final container = makeContainer(user: buildUser());

      final result = await container.read(currentStudentProvider.future);

      expect(result, isNotNull);
      expect(result?.id, 'student-1');
      expect(result?.userId, 'user-1');
      verify(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).called(1);
    });

    test('returns null when no user is authenticated', () async {
      final container = makeContainer(user: null);

      final result = await container.read(currentStudentProvider.future);

      expect(result, isNull);
      verifyNever(() => mockStudentRepository.getStudentByUserId(any()));
    });

    test('resolves the selected child for a guardian user', () async {
      final child = buildStudent(id: 'child-2', userId: 'kid-2');
      when(
        () => mockStudentRepository.getStudentById('child-2'),
      ).thenAnswer((_) async => child);

      final container = makeContainer(
        user: buildUser(id: 'guardian-1', role: UserRole.guardian),
      );
      container.read(selectedChildIdProvider.notifier).set('child-2');

      final result = await container.read(currentStudentProvider.future);

      expect(result?.id, 'child-2');
      verify(() => mockStudentRepository.getStudentById('child-2')).called(1);
    });

    test(
      'falls back to first child for a guardian with no selection',
      () async {
        final child = buildStudent(id: 'child-first', userId: 'kid-1');
        when(
          () => mockStudentRepository.getFirstStudentByGuardianId('guardian-1'),
        ).thenAnswer((_) async => child);

        final container = makeContainer(
          user: buildUser(id: 'guardian-1', role: UserRole.guardian),
        );

        final result = await container.read(currentStudentProvider.future);

        expect(result?.id, 'child-first');
        verify(
          () => mockStudentRepository.getFirstStudentByGuardianId('guardian-1'),
        ).called(1);
      },
    );
  });

  group('studentStatsProvider', () {
    test('returns empty stats when there is no current student', () async {
      final container = makeContainer(user: null);

      final stats = await container.read(studentStatsProvider.future);

      expect(stats.totalSessions, 0);
      expect(stats.passedSessions, 0);
      expect(stats.currentLevel, 1);
    });

    test('maps the student progress and session statistics', () async {
      final student = buildStudent(
        currentLevel: 2,
        currentJuz: 27,
        currentHizb: 53,
        currentSession: 12,
        completedLevels: [1],
        unlockedLevels: [1, 2],
      );
      when(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).thenAnswer((_) async => student);
      when(
        () => mockSessionRepository.getStudentStatistics('student-1'),
      ).thenAnswer((_) async => {'total_sessions': 10, 'passed_sessions': 8});

      final container = makeContainer(user: buildUser());

      final stats = await container.read(studentStatsProvider.future);

      expect(stats.currentLevel, 2);
      expect(stats.currentJuz, 27);
      expect(stats.currentHizb, 53);
      expect(stats.currentSession, 12);
      expect(stats.totalSessions, 10);
      expect(stats.passedSessions, 8);
      expect(stats.completedLevels, 1);
      expect(stats.completedLevelsList, [1]);
      expect(stats.unlockedLevelsList, [1, 2]);
    });

    test('computes pass rate as passed / total sessions', () async {
      final student = buildStudent();
      when(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).thenAnswer((_) async => student);
      when(
        () => mockSessionRepository.getStudentStatistics('student-1'),
      ).thenAnswer((_) async => {'total_sessions': 4, 'passed_sessions': 3});

      final container = makeContainer(user: buildUser());

      final stats = await container.read(studentStatsProvider.future);

      expect(stats.passRate, closeTo(0.75, 1e-9));
    });

    test(
      'pass rate is 0 when there are no sessions (no divide-by-zero)',
      () async {
        final student = buildStudent();
        when(
          () => mockStudentRepository.getStudentByUserId('user-1'),
        ).thenAnswer((_) async => student);
        when(
          () => mockSessionRepository.getStudentStatistics('student-1'),
        ).thenAnswer((_) async => {'total_sessions': 0, 'passed_sessions': 0});

        final container = makeContainer(user: buildUser());

        final stats = await container.read(studentStatsProvider.future);

        expect(stats.passRate, 0);
      },
    );

    test('isLevelLocked is true for a level not in unlockedLevels', () async {
      final student = buildStudent(unlockedLevels: [1, 2]);
      when(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).thenAnswer((_) async => student);
      when(
        () => mockSessionRepository.getStudentStatistics('student-1'),
      ).thenAnswer((_) async => <String, dynamic>{});

      final container = makeContainer(user: buildUser());

      final stats = await container.read(studentStatsProvider.future);

      expect(stats.isLevelLocked(3), isTrue);
      expect(stats.isLevelLocked(2), isFalse);
      expect(stats.isLevelLocked(1), isFalse);
    });

    test('isLevelCompleted is true only for completed levels', () async {
      final student = buildStudent(
        completedLevels: [1, 2],
        unlockedLevels: [1, 2, 3],
      );
      when(
        () => mockStudentRepository.getStudentByUserId('user-1'),
      ).thenAnswer((_) async => student);
      when(
        () => mockSessionRepository.getStudentStatistics('student-1'),
      ).thenAnswer((_) async => <String, dynamic>{});

      final container = makeContainer(user: buildUser());

      final stats = await container.read(studentStatsProvider.future);

      expect(stats.isLevelCompleted(1), isTrue);
      expect(stats.isLevelCompleted(2), isTrue);
      expect(stats.isLevelCompleted(3), isFalse);
    });
  });
}
