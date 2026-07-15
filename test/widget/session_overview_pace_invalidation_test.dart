import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
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
import 'package:al_rasikhoon/features/teacher/screens/session_overview_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// Pins a bug found by driving the real app against the Firebase emulator: a
/// teacher on `SessionOverviewScreen` tapped `2x` on a student who had been
/// showing 1x content, the write reached Firestore, but the screen kept
/// showing the OLD, 1x meeting until the app was reloaded.
///
/// The cause lived in the provider-invalidation graph, not in composition —
/// `_setPace` invalidated only `studentProvider(studentId)`, which is
/// DERIVED (it picks the student out of `teacherStudentsProvider`'s already-
/// fetched list). Invalidating it alone re-ran its body against that CACHED
/// list, so it served the same, still-1x student straight back out. The fix
/// also invalidates `teacherStudentsProvider`, the actual source.
///
/// This is deliberately wired with REAL repositories over
/// `FakeFirebaseFirestore` rather than stubbed providers: stubbing
/// `studentProvider` or `studentCurrentMeetingProvider` would bypass the very
/// provider graph the bug lived in and could not have caught it.
void main() {
  testWidgets(
    "doubling a student's pace widens the pending meeting on screen, not "
    'just in Firestore',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final curriculumRepository = CurriculumRepository(firestore: firestore);
      final userRepository = UserRepository(firestore: firestore);
      final studentRepository = StudentRepository(
        firestore: firestore,
        firebaseService: _MockFirebaseService(),
        userRepository: userRepository,
        curriculumRepository: curriculumRepository,
        sessionRepository: SessionRepository(firestore: firestore),
      );

      await firestore.collection('levels').doc('level_1').set({
        'id': 1,
        'session_count': 210,
        'order': 1,
      });

      SessionModel session({
        required int order,
        required SessionKind kind,
        QuranContent? newContent,
        QuranContent? recentReview,
      }) => SessionModel(
        id: 'L1_J30_S$order',
        levelId: 1,
        juzNumber: 30,
        sessionNumber: order,
        orderInLevel: order,
        kind: kind,
        unitIndex: 1,
        hizbNumber: 59,
        currentLevelContent: newContent,
        recentReviewContent: recentReview,
      );

      final sessions = [
        session(
          order: 1,
          kind: SessionKind.talqeen,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 1,
            toSurah: 'النبأ',
            toVerse: 11,
          ),
        ),
        session(
          order: 2,
          kind: SessionKind.lesson,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 1,
            toSurah: 'النبأ',
            toVerse: 11,
          ),
        ),
        session(
          order: 3,
          kind: SessionKind.lesson,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 12,
            toSurah: 'النبأ',
            toVerse: 20,
          ),
        ),
        session(
          order: 4,
          kind: SessionKind.lesson,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 21,
            toSurah: 'النبأ',
            toVerse: 30,
          ),
        ),
        session(
          order: 5,
          kind: SessionKind.lesson,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 31,
            toSurah: 'النبأ',
            toVerse: 37,
          ),
          recentReview: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 12,
            toSurah: 'النبأ',
            toVerse: 30,
          ),
        ),
        session(
          order: 6,
          kind: SessionKind.lesson,
          newContent: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 38,
            toSurah: 'النبأ',
            toVerse: 40,
          ),
          recentReview: const QuranContent(
            fromSurah: 'النبأ',
            fromVerse: 21,
            toSurah: 'النبأ',
            toVerse: 37,
          ),
        ),
      ];
      for (final s in sessions) {
        await firestore.collection('sessions').doc(s.id).set(s.toFirestore());
      }

      await firestore.collection('users').doc('u1').set({
        'username': 'student_one',
        'email': 'student_one@alrasikhoon.local',
        'name': 'طالب',
        'role': 'student',
        'is_active': true,
        'created_at': Timestamp.now(),
      });

      // Standing on order 5, still at the default pace — no `pace` field at
      // all, which must read back as 1x.
      await firestore.collection('students').doc('s1').set({
        'user_id': 'u1',
        'institute_id': 'inst1',
        'teacher_id': 'teacher-1',
        'current_level': 1,
        'current_juz': 30,
        'current_session': 5,
        'current_order_in_level': 5,
        'current_hizb': null,
        'current_session_id': 'L1_J30_S5',
        'current_session_kind': 'lesson',
        'current_attempt': 1,
        'completed_levels': <int>[],
        'unlocked_levels': const [1],
        'is_active': true,
        'created_at': Timestamp.now(),
      });

      final teacher = UserModel(
        id: 'teacher-1',
        username: 'teacher_one',
        email: 'teacher_one@alrasikhoon.local',
        name: 'معلم',
        role: UserRole.teacher,
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(teacher),
          firestoreProvider.overrideWithValue(firestore),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: SessionOverviewScreen(studentId: 's1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1x: the authored content of session 5 alone.
      expect(find.text('النبأ: 31 - 37'), findsOneWidget);

      await tester.tap(find.text('2x'));
      await tester.pumpAndSettle();

      // 2x: sessions 5 and 6 merged into one contiguous range. If the pace
      // change failed to reach the screen, the OLD 1x block would still be
      // showing here.
      expect(find.text('النبأ: 31 - 40'), findsOneWidget);
      expect(find.text('النبأ: 31 - 37'), findsNothing);
    },
  );
}
