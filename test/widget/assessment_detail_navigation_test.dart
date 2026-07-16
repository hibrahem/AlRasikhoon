import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/sard_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/assessment_detail_screen.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';

/// A سرد history row navigates to its assessment detail view
/// (al_rasikhoon-nyp) — through the shell-injected `assessmentDetailRoute`,
/// exactly as lesson rows use the injected `sessionDetailRoute` — and the
/// detail view shows the sheet's verdict and per-face error table.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S31',
    currentSessionKind: SessionKind.exam,
    currentOrderInLevel: 31,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  // A saved سرد with a per-face breakdown: face 1 is within its allowance,
  // face 2 broke the تشكيل allowance (2 > 1) — so the verdict is غير موفق.
  final sardRecord = SardRecordModel(
    id: 'sard1',
    studentId: 's1',
    teacherId: 't1',
    curriculumSessionId: 'L1_J30_S30',
    tier: AssessmentTier.unit,
    juzNumbers: const [30],
    hizbNumber: 59,
    scopeLabelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
    levelId: 1,
    date: DateTime(2026, 7, 15),
    errorCount: 5,
    grade: 'غير موفق',
    passed: false,
    attemptNumber: 1,
    createdAt: DateTime(2026, 7, 15),
    faceErrors: const [
      RecitationErrorTally(tanbeehat: 3),
      RecitationErrorTally(tashkeel: 2),
    ],
  );

  final sardEntry = StudentHistoryEntry(
    id: sardRecord.id,
    kind: StudentHistoryKind.sard,
    levelId: sardRecord.levelId,
    scopeLabelAr: sardRecord.scopeLabelAr,
    passed: sardRecord.passed,
    date: sardRecord.date,
    detailRecordId: sardRecord.id,
  );

  testWidgets('tapping a سرد history row opens the assessment detail with the '
      'verdict and the per-face error table', (tester) async {
    final router = GoRouter(
      initialLocation: '/shell/students/s1',
      routes: [
        GoRoute(
          path: '/shell/students/:id',
          builder: (context, state) => StudentProgressScreen(
            studentId: 's1',
            studentProvider: adminStudentProvider,
            currentMeetingProvider: adminStudentCurrentMeetingProvider,
            sessionHistoryProvider: adminStudentSessionHistoryProvider,
            sessionDetailRoute: '/shell/history/:recordId',
            assessmentDetailRoute: '/shell/assessment/:kind/:recordId',
          ),
        ),
        GoRoute(
          path: '/shell/assessment/:kind/:recordId',
          builder: (context, state) => AssessmentDetailScreen(
            kind: assessmentKindFromPath(state.pathParameters['kind']!),
            recordId: state.pathParameters['recordId']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          adminStudentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => null),
          adminStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => [sardEntry]),
          // Feeds the destination detail screen.
          sardRecordByIdProvider(
            sardRecord.id,
          ).overrideWith((ref) async => sardRecord),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The سرد row renders, titled by its scope, and is tappable.
    final row = find.text(sardRecord.scopeLabelAr);
    expect(row, findsOneWidget);

    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    // Landed on the assessment detail — via the injected shell-local route.
    expect(find.text('تفاصيل السرد'), findsOneWidget);
    final location =
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    expect(location, '/shell/assessment/sard/sard1');

    // The verdict and the per-face table are shown.
    expect(find.text('غير موفق'), findsOneWidget);
    expect(find.text('الوجه 1'), findsOneWidget);
    expect(find.text('الوجه 2'), findsOneWidget);
    // The face-2 تشكيل count that failed the سرد.
    expect(find.text('التشكيل'), findsOneWidget);
  });

  testWidgets('a hand-crafted assessment URL with an unknown kind surfaces '
      'instead of guessing a record type', (tester) async {
    expect(() => assessmentKindFromPath('lesson'), throwsArgumentError);
  });
}
