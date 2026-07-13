import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/sard_result_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// Regression test for hibrahem/AlRasikhoon final-review finding #2:
/// `advanceStudentSession` can silently no-op when no seeded curriculum data
/// exists ahead of the student. Before the fix, SardResultScreen always
/// showed the plain "تم حفظ السرد - ناجح" success message on a pass, even
/// when the student's position never actually moved — leaving the teacher
/// unaware the student is stuck re-taking the same session forever. This
/// drives the real save flow against a StudentRepository backed by
/// FakeFirebaseFirestore with NO curriculum sessions seeded, so the walk
/// forward is guaranteed to report `curriculumDataMissing`.
void main() {
  testWidgets('SardResultScreen warns instead of claiming plain success when the '
      'student cannot actually be advanced', (tester) async {
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('students').doc('student1').set({
      'user_id': 'user1',
      'institute_id': 'institute1',
      'current_level': 1,
      'current_juz': 30,
      'current_hizb': 59,
      'current_session': 1,
      'current_attempt': 1,
      'completed_levels': <int>[],
      'unlocked_levels': [1],
      'is_active': true,
      'created_at': Timestamp.now(),
    });

    final student = StudentModel(
      id: 'student1',
      userId: 'user1',
      instituteId: 'institute1',
      currentLevel: 1,
      currentJuz: 30,
      currentHizb: 59,
      currentSession: 1,
      createdAt: DateTime(2026, 1, 1),
    );
    final studentUser = UserModel(
      id: 'user1',
      username: 'pupil',
      email: 'pupil@alrasikhoon.local',
      name: 'طالب',
      role: UserRole.student,
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );
    final supervisor = UserModel(
      id: 'sup1',
      username: 'supervisor',
      email: 'sup@alrasikhoon.local',
      name: 'مشرف',
      role: UserRole.supervisor,
      instituteId: 'institute1',
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );

    // A real StudentRepository over a Firestore with no `sessions` and no
    // `levels` documents at all: the walk forward from hizb 59 finds
    // nothing seeded anywhere ahead, so _nextPosition is guaranteed to
    // report `_CurriculumDataMissing` -> `StudentAdvanceOutcome.curriculumDataMissing`.
    final studentRepository = StudentRepository(
      firestore: firestore,
      firebaseService: _MockFirebaseService(),
      userRepository: UserRepository(firestore: firestore),
      curriculumRepository: CurriculumRepository(firestore: firestore),
    );
    final sessionRepository = SessionRepository(firestore: firestore);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SardResultScreen(studentId: 'student1', errorCount: 0),
        ),
        GoRoute(
          path: AppRoutes.supervisorStudents,
          builder: (context, state) =>
              const Scaffold(body: Text('قائمة الطلاب')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(supervisor),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          supervisorStudentProvider.overrideWith(
            (ref, id) async =>
                StudentWithUser(student: student, user: studentUser),
          ),
          supervisorStudentsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('حفظ النتيجة'));
    // Let the async save flow run to completion (record save, advance
    // attempt, SnackBar, navigation) without waiting for the SnackBar's
    // multi-second auto-dismiss timer.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The plain, unqualified success message must NOT be what the user
    // sees — that would be exactly the silently-misleading behaviour the
    // fix removes.
    expect(find.textContaining('تم حفظ السرد - ناجح'), findsNothing);
    // Instead, a clear warning that progress could not be updated.
    expect(find.textContaining('تعذر تحديث تقدم الطالب'), findsOneWidget);
  });
}
