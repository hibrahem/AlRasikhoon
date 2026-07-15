import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/sard_result_screen.dart';
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
/// FakeFirebaseFirestore in which the student's OWN سرد is the only session
/// seeded and no levels catalog exists, so the walk forward finds nothing ahead
/// and is guaranteed to report `curriculumDataMissing`.
void main() {
  testWidgets('SardResultScreen warns instead of claiming plain success when the '
      'student cannot actually be advanced', (tester) async {
    final firestore = FakeFirebaseFirestore();

    // The سرد the student stands on — the hizb-59 (unit-tier) سرد of juz 30,
    // which is session 30, NOT 35. Its scope is what the record must carry.
    await firestore.collection('sessions').doc('L1_J30_S30').set({
      'level_id': 1,
      'juz_number': 30,
      'session_number': 30,
      'order_in_level': 30,
      'kind': 'sard',
      'assessed_by': 'teacher',
      'hizb_number': 59,
      'scope': {
        'tier': 'unit',
        'label_ar': 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
        'hizb_number': 59,
        'juz_numbers': [30],
      },
    });
    // Nothing at order_in_level 31, and no `levels` catalog at all: the walk
    // forward can find no session ahead and cannot conclude the level is over.

    await firestore.collection('students').doc('student1').set({
      'user_id': 'user1',
      'institute_id': 'institute1',
      'current_level': 1,
      'current_juz': 30,
      'current_hizb': 59,
      'current_session': 30,
      'current_order_in_level': 30,
      'current_session_id': 'L1_J30_S30',
      'current_session_kind': 'sard',
      'current_session_tier': 'unit',
      'current_session_label_ar': 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
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
      currentSession: 30,
      currentOrderInLevel: 30,
      currentSessionId: 'L1_J30_S30',
      currentSessionKind: SessionKind.sard,
      currentSessionTier: AssessmentTier.unit,
      currentSessionLabelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
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
    final teacher = UserModel(
      id: 'teacher1',
      username: 'teacher',
      email: 'teacher@alrasikhoon.local',
      name: 'معلم',
      role: UserRole.teacher,
      instituteId: 'institute1',
      authProvider: UserAuthProvider.emailPassword,
      createdAt: DateTime(2026, 1, 1),
    );

    // A real StudentRepository over a Firestore with no `sessions` and no
    // `levels` documents at all: the walk forward from hizb 59 finds
    // nothing seeded anywhere ahead, so _nextPosition is guaranteed to
    // report `_CurriculumDataMissing` -> `StudentAdvanceOutcome.curriculumDataMissing`.
    final sessionRepository = SessionRepository(firestore: firestore);
    final studentRepository = StudentRepository(
      firestore: firestore,
      firebaseService: _MockFirebaseService(),
      userRepository: UserRepository(firestore: firestore),
      curriculumRepository: CurriculumRepository(firestore: firestore),
      sessionRepository: sessionRepository,
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SardResultScreen(studentId: 'student1', errorCount: 0),
        ),
        GoRoute(
          path: AppRoutes.teacherStudents,
          builder: (context, state) =>
              const Scaffold(body: Text('قائمة الطلاب')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The screen resolves the سرد's SCOPE from the curriculum itself, so
          // the curriculum repository must read the same fake Firestore.
          firestoreProvider.overrideWithValue(firestore),
          currentUserProvider.overrideWithValue(teacher),
          studentRepositoryProvider.overrideWithValue(studentRepository),
          sessionRepositoryProvider.overrideWithValue(sessionRepository),
          studentProvider.overrideWith(
            (ref, id) async =>
                StudentWithUser(student: student, user: studentUser),
          ),
          teacherStudentsProvider.overrideWith((ref) async => []),
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
