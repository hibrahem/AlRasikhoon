import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/widgets/student_institute_badge.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';
import 'package:al_rasikhoon/shared/widgets/institute_badge.dart';

/// An admin sees students across every institute, so the admin route injects
/// an `instituteBadge` into the shared progress screen naming the student's
/// institute (al_rasikhoon-gud). Teacher/supervisor shells are
/// institute-scoped and inject nothing. This pins that the header shows the
/// resolved institute name when injected, shows no badge when nothing is
/// injected, and renders nothing (not an empty badge) when the institute
/// can't be resolved.
void main() {
  final lesson = SessionModel(
    id: 'L1_J30_S5',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 5,
    orderInLevel: 5,
    kind: SessionKind.lesson,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 5,
    ),
  );

  final meeting = PacedSession(
    sessions: [lesson],
    newContent: [lesson.currentLevelContent!],
    recentReview: const [],
    distantReview: const [],
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S5',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 5,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  final institute = InstituteModel(
    id: 'inst1',
    name: 'معهد النور',
    location: 'الرياض',
    createdBy: 'admin1',
    createdAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester, {
    InstituteModel? resolvedInstitute,
    Widget Function(StudentModel)? instituteBadge,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          adminStudentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
          adminStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => <StudentHistoryEntry>[]),
          instituteProvider(
            'inst1',
          ).overrideWith((ref) async => resolvedInstitute),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentProgressScreen(
              studentId: 's1',
              studentProvider: adminStudentProvider,
              currentMeetingProvider: adminStudentCurrentMeetingProvider,
              sessionHistoryProvider: adminStudentSessionHistoryProvider,
              sessionDetailRoute: '/admin/students/history/:recordId',
              assessmentDetailRoute:
                  '/admin/students/assessment/:kind/:recordId',
              instituteBadge: instituteBadge,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'admin sees the student\'s institute named in the progress header',
    (tester) async {
      await pump(
        tester,
        resolvedInstitute: institute,
        instituteBadge: (s) =>
            StudentInstituteBadge(instituteId: s.instituteId),
      );

      expect(find.text('معهد النور'), findsOneWidget);
      expect(find.byType(InstituteBadge), findsOneWidget);
    },
  );

  testWidgets(
    'no badge when no instituteBadge is injected (teacher/supervisor shells)',
    (tester) async {
      await pump(tester, resolvedInstitute: institute, instituteBadge: null);

      expect(find.byType(InstituteBadge), findsNothing);
      expect(find.text('معهد النور'), findsNothing);
    },
  );

  testWidgets(
    'an unresolvable institute renders nothing, never an empty badge',
    (tester) async {
      await pump(
        tester,
        resolvedInstitute: null,
        instituteBadge: (s) =>
            StudentInstituteBadge(instituteId: s.instituteId),
      );

      expect(find.byType(InstituteBadge), findsNothing);
      // The rest of the header is intact without it.
      expect(find.text('طالب'), findsOneWidget);
    },
  );
}
