import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// The talqeen step that closes a session (`NextContentTalqeenScreen`) previews
/// the next passage via [activeSessionNextMeetingProvider] and, on the same
/// screen, lets the teacher edit two recitation counts held on the active
/// session. Those counts have nothing to do with which passage comes next, so
/// editing one must NOT invalidate the passage preview — otherwise the screen
/// flashes a spinner over the passage card on every tap.
void main() {
  late MockStudentRepository mockStudentRepository;
  late FakeFirebaseFirestore firestore;
  late SessionRepository sessionRepository;
  late CurriculumRepository curriculumRepository;

  const session = SessionModel(
    id: 'L1_J30_S1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 7,
    kind: SessionKind.lesson,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 11,
    ),
  );

  final meeting = PacedSession(
    sessions: const [session],
    newContent: const [
      QuranContent(
        fromSurah: 'النبأ',
        fromVerse: 1,
        toSurah: 'النبأ',
        toVerse: 11,
      ),
    ],
    recentReview: const [],
    distantReview: const [],
  );

  setUp(() async {
    mockStudentRepository = MockStudentRepository();
    firestore = FakeFirebaseFirestore();
    sessionRepository = SessionRepository(firestore: firestore);
    curriculumRepository = CurriculumRepository(firestore: firestore);

    await firestore.collection('sessions').doc('L1_J30_S1').set({
      'level_id': 1,
      'juz_number': 30,
      'session_number': 1,
      'order_in_level': 7,
      'kind': 'lesson',
      'hizb_number': 59,
    });
  });

  UserModel buildTeacher() => UserModel(
    id: 'teacher-1',
    username: 'teacher_one',
    email: 'teacher_one@alrasikhoon.local',
    name: 'معلم',
    role: UserRole.teacher,
    authProvider: UserAuthProvider.emailPassword,
    createdAt: DateTime(2026, 1, 1),
  );

  StudentWithUser buildStudentWithUser() => StudentWithUser(
    student: StudentModel(
      id: 'student-1',
      userId: 'user-1',
      instituteId: 'institute-1',
      teacherId: 'teacher-1',
      currentLevel: 1,
      currentJuz: 30,
      currentHizb: 59,
      currentSession: 1,
      currentAttempt: 1,
      currentSessionId: 'L1_J30_S1',
      currentOrderInLevel: 7,
      createdAt: DateTime(2026, 1, 1),
    ),
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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(buildTeacher()),
        studentRepositoryProvider.overrideWithValue(mockStudentRepository),
        sessionRepositoryProvider.overrideWithValue(sessionRepository),
        curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'editing a recitation count does not reload the next-passage preview',
    () async {
      when(
        () => mockStudentRepository.getStudentsForTeacher('teacher-1'),
      ).thenAnswer((_) async => [buildStudentWithUser()]);

      final container = makeContainer();
      final notifier = container.read(activeSessionProvider.notifier);

      // Seed an active session that already carries the meeting being taught,
      // exactly as `NextContentTalqeenScreen` sees it once the session started.
      notifier.seedForTest(
        ActiveSessionState(studentId: 'student-1', meeting: meeting),
      );

      // Warm the student first so the preview composes from resolved data and
      // settles, rather than being re-invalidated once the student resolves.
      await container.read(studentProvider('student-1').future);
      await container.read(activeSessionNextMeetingProvider.future);
      expect(
        container.read(activeSessionNextMeetingProvider),
        isA<AsyncData>(),
      );

      // Editing a count the next passage does not depend on must leave the
      // preview serving its resolved data — never bouncing back to loading,
      // which is the on-screen spinner flash.
      notifier.setRepetitionsWithTeacher(3);

      expect(
        container.read(activeSessionNextMeetingProvider).isLoading,
        isFalse,
      );
    },
  );
}
