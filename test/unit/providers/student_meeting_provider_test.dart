import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

QuranContent _content(String surah, int from, int to) => QuranContent(
  fromSurah: surah,
  fromVerse: from,
  toSurah: surah,
  toVerse: to,
);

SessionModel _session({
  required int order,
  SessionKind kind = SessionKind.lesson,
  QuranContent? newContent,
  QuranContent? recent,
  QuranContent? distant,
}) => SessionModel(
  id: 'L1_J30_S$order',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: order,
  orderInLevel: order,
  kind: kind,
  currentLevelContent: newContent,
  recentReviewContent: recent,
  distantReviewContent: distant,
);

/// The same unit shape `paced_session_real_curriculum_test.dart` composes
/// from — a تلقين that opens it, and lessons whose recent review slides over
/// the previous two. This is what lets `newContentAr` merge two DISTINCT
/// ranges (31-37, 38-40) rather than the uniform placeholder content the
/// plain `seedSession` fixture would give every lesson.
///
/// order 1  تلقين   new: النبأ 1-11
/// order 2  lesson  new: النبأ 1-11    (the تلقين's passage, now recited)
/// order 3  lesson  new: النبأ 12-20   recent: النبأ 1-11
/// order 4  lesson  new: النبأ 21-30   recent: النبأ 1-20
/// order 5  lesson  new: النبأ 31-37   recent: النبأ 12-30   distant: الفاتحة 1-3
/// order 6  lesson  new: النبأ 38-40   recent: النبأ 21-37   distant: الفاتحة 4-7
List<SessionModel> _unit() => [
  _session(
    order: 1,
    kind: SessionKind.talqeen,
    newContent: _content('النبأ', 1, 11),
  ),
  _session(order: 2, newContent: _content('النبأ', 1, 11)),
  _session(
    order: 3,
    newContent: _content('النبأ', 12, 20),
    recent: _content('النبأ', 1, 11),
  ),
  _session(
    order: 4,
    newContent: _content('النبأ', 21, 30),
    recent: _content('النبأ', 1, 20),
  ),
  _session(
    order: 5,
    newContent: _content('النبأ', 31, 37),
    recent: _content('النبأ', 12, 30),
    distant: _content('الفاتحة', 1, 3),
  ),
  _session(
    order: 6,
    newContent: _content('النبأ', 38, 40),
    recent: _content('النبأ', 21, 37),
    distant: _content('الفاتحة', 4, 7),
  ),
];

/// Tests for the three MEETING providers Task 8 adds — the teacher, the
/// institute-scoped supervisor, and the student-dashboard twins of the three
/// existing "current session" providers. Setup mirrors
/// `teacher_provider_test.dart`'s "paced meetings" group: real
/// `FakeFirebaseFirestore`-backed repositories, because composing a meeting
/// walks the curriculum for real rather than standing in for it with a mock.
void main() {
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
      sessionRepository: sessionRepository,
    );

    for (final session in _unit()) {
      await firestore
          .collection('sessions')
          .doc(session.id)
          .set(session.toFirestore());
    }
  });

  Future<void> seedUnderlyingUser(String userId) async {
    await firestore.collection('users').doc(userId).set({
      'username': 'pupil_$userId',
      'email': 'pupil_$userId@alrasikhoon.local',
      'name': 'طالب',
      'role': 'student',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
  }

  Future<void> seedStudent({
    required String id,
    required String userId,
    String? teacherId,
    String instituteId = 'institute-1',
    required int currentOrderInLevel,
    CurriculumPace? pace,
  }) async {
    final session = await curriculumRepository.getSessionByOrderInLevel(
      level: 1,
      orderInLevel: currentOrderInLevel,
    );
    await firestore.collection('students').doc(id).set({
      'user_id': userId,
      'institute_id': instituteId,
      'teacher_id': teacherId,
      'current_level': 1,
      'current_juz': session!.juzNumber,
      'current_session': session.sessionNumber,
      'current_order_in_level': currentOrderInLevel,
      'current_hizb': null,
      'current_session_id': session.id,
      'current_session_kind': session.kind.value,
      'current_session_tier': session.scope?.tier.value,
      'current_session_label_ar': session.scope?.labelAr,
      'current_attempt': 1,
      'completed_levels': <int>[],
      'unlocked_levels': const [1],
      'is_active': true,
      'created_at': Timestamp.now(),
      'pace': (pace ?? CurriculumPace.standard).toJson(),
    });
  }

  UserModel buildTeacher() => UserModel(
    id: 'teacher-1',
    username: 'teacher_one',
    email: 'teacher_one@alrasikhoon.local',
    name: 'معلم',
    role: UserRole.teacher,
    authProvider: UserAuthProvider.emailPassword,
    createdAt: DateTime(2026, 1, 1),
  );

  UserModel buildSupervisor() => UserModel(
    id: 'supervisor-1',
    username: 'supervisor_one',
    email: 'supervisor_one@alrasikhoon.local',
    name: 'مشرف',
    role: UserRole.supervisor,
    authProvider: UserAuthProvider.emailPassword,
    instituteId: 'institute-1',
    createdAt: DateTime(2026, 1, 1),
  );

  UserModel buildStudentUser({required String id}) => UserModel(
    id: id,
    username: 'pupil_$id',
    email: 'pupil_$id@alrasikhoon.local',
    name: 'طالب',
    role: UserRole.student,
    authProvider: UserAuthProvider.emailPassword,
    createdAt: DateTime(2026, 1, 1),
  );

  ProviderContainer makeContainer({UserModel? user}) {
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

  group('studentCurrentMeetingProvider', () {
    test(
      "a standard student's meeting is the single session he stands on",
      () async {
        await seedUnderlyingUser('user-1');
        await seedStudent(
          id: 's1',
          userId: 'user-1',
          teacherId: 'teacher-1',
          currentOrderInLevel: 5,
        );

        final container = makeContainer(user: buildTeacher());
        final meeting = await container.read(
          studentCurrentMeetingProvider('s1').future,
        );

        expect(meeting!.coversSessionIds, ['L1_J30_S5']);
        expect(meeting.isBatched, isFalse);
      },
    );

    test("a doubled student's meeting covers the next two lessons", () async {
      await seedUnderlyingUser('user-1');
      await seedStudent(
        id: 's1',
        userId: 'user-1',
        teacherId: 'teacher-1',
        currentOrderInLevel: 5,
        pace: CurriculumPace(2),
      );

      final container = makeContainer(user: buildTeacher());
      final meeting = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );

      expect(meeting!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.toOrderInLevel, 6);
    });

    // Load-bearing: the student stores where a meeting STARTS, never how far
    // it extends, so a pace change must need no migration — the very next
    // read widens the meeting.
    test(
      'changing the pace mid-level recomposes the pending meeting',
      () async {
        await seedUnderlyingUser('user-1');
        await seedStudent(
          id: 's1',
          userId: 'user-1',
          teacherId: 'teacher-1',
          currentOrderInLevel: 5,
        );

        final container = makeContainer(user: buildTeacher());
        final before = await container.read(
          studentCurrentMeetingProvider('s1').future,
        );
        expect(before!.coversSessionIds, ['L1_J30_S5']);

        await studentRepository.setStudentPace('s1', CurriculumPace(2));
        // `studentProvider` derives from the cached `teacherStudentsProvider`
        // list, so both must be invalidated for the fresh pace to surface —
        // exactly the pair `ActiveSessionNotifier.completeSession` already
        // invalidates after every write.
        container.invalidate(teacherStudentsProvider);
        container.invalidate(studentProvider('s1'));

        final after = await container.read(
          studentCurrentMeetingProvider('s1').future,
        );
        expect(after!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
        expect(after.fromOrderInLevel, 5, reason: 'he did not move');
      },
    );

    test('a meeting renders its passages merged', () async {
      await seedUnderlyingUser('user-1');
      await seedStudent(
        id: 's1',
        userId: 'user-1',
        teacherId: 'teacher-1',
        currentOrderInLevel: 5,
        pace: CurriculumPace(2),
      );

      final container = makeContainer(user: buildTeacher());
      final meeting = await container.read(
        studentCurrentMeetingProvider('s1').future,
      );

      expect(meeting!.newContentAr, 'النبأ: 31 - 40');
      expect(meeting.recentReviewAr, 'النبأ: 1 - 30');
      expect(meeting.distantReviewAr, 'الفاتحة: 1 - 7');
    });
  });

  group('supervisorStudentCurrentMeetingProvider', () {
    // AgDR-0003: a supervisor-created student has a null teacher_id, and the
    // teacher-scoped provider would report "Student not found" for him.
    test('resolves an institute student with no teacher assigned', () async {
      await seedUnderlyingUser('user-2');
      await seedStudent(
        id: 's2',
        userId: 'user-2',
        teacherId: null,
        instituteId: 'institute-1',
        currentOrderInLevel: 5,
        pace: CurriculumPace(2),
      );

      // The supervisor is scoped to institute-1 through supervisor_institutes
      // membership (al_rasikhoon-3n6), which is how the supervisor student
      // providers resolve which institutes' students they may see.
      await firestore.collection('institutes').doc('institute-1').set({
        'name': 'معهد الاختبار',
        'location': 'الرياض',
        'created_by': 'admin',
        'created_at': Timestamp.now(),
        'is_active': true,
      });
      await firestore.collection('supervisor_institutes').add({
        'supervisor_id': 'supervisor-1',
        'institute_id': 'institute-1',
        'is_active': true,
      });

      final container = ProviderContainer(
        overrides: [
          firestoreProvider.overrideWithValue(firestore),
          currentUserProvider.overrideWithValue(buildSupervisor()),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);

      final meeting = await container.read(
        supervisorStudentCurrentMeetingProvider('s2').future,
      );

      expect(meeting!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.newContentAr, 'النبأ: 31 - 40');
    });
  });

  group('studentDashboardMeetingProvider', () {
    test("resolves the signed-in student's own meeting", () async {
      await seedUnderlyingUser('user-3');
      await seedStudent(
        id: 's3',
        userId: 'user-3',
        teacherId: 'teacher-1',
        currentOrderInLevel: 5,
        pace: CurriculumPace(2),
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(buildStudentUser(id: 'user-3')),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);

      final meeting = await container.read(
        studentDashboardMeetingProvider.future,
      );

      expect(meeting!.coversSessionIds, ['L1_J30_S5', 'L1_J30_S6']);
      expect(meeting.newContentAr, 'النبأ: 31 - 40');
    });
  });
}
