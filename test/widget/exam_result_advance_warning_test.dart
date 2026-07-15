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
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_result_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// Regression test for hibrahem/AlRasikhoon final-review finding #1 — the mirror
/// of `sard_result_advance_warning_test.dart` for the supervisor's اختبار flow.
/// `advanceStudentSession` can silently no-op when no seeded curriculum data
/// exists ahead of the student. Before the fix, ExamResultScreen always showed
/// the plain "تم حفظ الاختبار - ناجح" success message on a pass, even when the
/// student's position never actually moved — leaving the supervisor unaware the
/// student is stuck re-sitting the same اختبار forever. This drives the real
/// save flow against a StudentRepository backed by FakeFirebaseFirestore in
/// which the student's OWN اختبار is the only session seeded and no levels
/// catalog exists, so the walk forward finds nothing ahead and is guaranteed to
/// report `curriculumDataMissing`.
void main() {
  testWidgets(
    'ExamResultScreen warns instead of claiming plain success when the student '
    'cannot actually be advanced',
    (tester) async {
      final firestore = FakeFirebaseFirestore();

      // The اختبار the student stands on — the hizb-59 (unit-tier) اختبار of
      // juz 30, which is session 32. Its scope is what the record must carry.
      await firestore.collection('sessions').doc('L1_J30_S32').set({
        'level_id': 1,
        'juz_number': 30,
        'session_number': 32,
        'order_in_level': 32,
        'kind': 'exam',
        'assessed_by': 'supervisor',
        'hizb_number': 59,
        'scope': {
          'tier': 'unit',
          'label_ar': 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
          'hizb_number': 59,
          'juz_numbers': [30],
        },
      });
      // Nothing at order_in_level 33, and no `levels` catalog at all: the walk
      // forward can find no session ahead and cannot conclude the level is over.

      await firestore.collection('students').doc('student1').set({
        'user_id': 'user1',
        'institute_id': 'institute1',
        'current_level': 1,
        'current_juz': 30,
        'current_hizb': 59,
        'current_session': 32,
        'current_order_in_level': 32,
        'current_session_id': 'L1_J30_S32',
        'current_session_kind': 'exam',
        'current_session_tier': 'unit',
        'current_session_label_ar':
            'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
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
        currentSession: 32,
        currentOrderInLevel: 32,
        currentSessionId: 'L1_J30_S32',
        currentSessionKind: SessionKind.exam,
        currentSessionTier: AssessmentTier.unit,
        currentSessionLabelAr:
            'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
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
        id: 'supervisor1',
        username: 'supervisor',
        email: 'supervisor@alrasikhoon.local',
        name: 'مشرف',
        role: UserRole.supervisor,
        instituteId: 'institute1',
        authProvider: UserAuthProvider.emailPassword,
        createdAt: DateTime(2026, 1, 1),
      );

      // A real StudentRepository over a Firestore with no `sessions` ahead and
      // no `levels` documents at all: the walk forward from order 32 finds
      // nothing seeded anywhere ahead, so _nextSession is guaranteed to report
      // `_CurriculumDataMissing` -> `StudentAdvanceOutcome.curriculumDataMissing`.
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
                const ExamResultScreen(studentId: 'student1', errorCount: 0),
          ),
          GoRoute(
            path: AppRoutes.examQueue,
            builder: (context, state) =>
                const Scaffold(body: Text('قائمة الاختبارات')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // The screen resolves the اختبار's SCOPE from the curriculum itself,
            // so the curriculum repository must read the same fake Firestore.
            firestoreProvider.overrideWithValue(firestore),
            currentUserProvider.overrideWithValue(supervisor),
            studentRepositoryProvider.overrideWithValue(studentRepository),
            sessionRepositoryProvider.overrideWithValue(sessionRepository),
            examStudentProvider.overrideWith(
              (ref, id) async =>
                  StudentWithUser(student: student, user: studentUser),
            ),
            examQueueProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('حفظ النتيجة'));
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
      expect(find.textContaining('تم حفظ الاختبار - ناجح'), findsNothing);
      // Instead, a clear warning that progress could not be updated.
      expect(find.textContaining('تعذر تحديث تقدم الطالب'), findsOneWidget);
    },
  );
}
