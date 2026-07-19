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
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// The offline-save contract of `completeSession` (spec §3): the record and
/// the student-progress update land through ONE WriteBatch, and the method
/// returns without awaiting server acknowledgement — the fake's commit
/// resolves immediately, so both effects are observable right after the call.
void main() {
  late FakeFirebaseFirestore firestore;
  late CurriculumRepository curriculumRepository;
  late SessionRepository sessionRepository;
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
    sessionRepository = SessionRepository(firestore: firestore);
    studentRepository = StudentRepository(
      firestore: firestore,
      firebaseService: _MockFirebaseService(),
      userRepository: UserRepository(firestore: firestore),
      curriculumRepository: curriculumRepository,
      sessionRepository: sessionRepository,
    );

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

  test(
    'completing a session lands record and advancement together via one batch',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(
            UserModel(
              id: 'teacher-1',
              username: 'teacher_one',
              email: 'teacher_one@alrasikhoon.local',
              name: 'معلم',
              role: UserRole.teacher,
              authProvider: UserAuthProvider.emailPassword,
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(activeSessionProvider.notifier);
      notifier.startSession('student-1');
      notifier.setPartErrors(1, 0);
      notifier.setPartErrors(2, 0);
      notifier.setPartErrors(3, 0);

      final record = await notifier.completeSession();
      // The batch commit is fire-and-forget (offline support): drain the
      // event queue so the staged writes land before asserting on them.
      await pumpEventQueue();

      final recordDoc = await firestore
          .collection('session_records')
          .doc(record!.id)
          .get();
      expect(recordDoc.exists, isTrue);

      final studentDoc = await firestore
          .collection('students')
          .doc('student-1')
          .get();
      expect(studentDoc.data()!['current_order_in_level'], 2);
    },
  );
}
