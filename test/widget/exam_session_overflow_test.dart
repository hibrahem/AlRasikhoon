import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_session_screen.dart';
import 'package:al_rasikhoon/shared/widgets/bottom_nav_bar.dart';

/// The اختبار screen runs inside the supervisor's shell, so its viewport is the
/// phone minus the status bar, the app bar, the bottom nav and the home
/// indicator. Its content — the student/exam card, the error counter and the
/// "إنهاء الاختبار" button — is taller than what is left on a normal phone, and
/// nothing scrolled: the screen overflowed the bottom and the button was
/// unreachable.

const _studentId = 'student3';

StudentWithUser _examStudent() {
  return StudentWithUser(
    student: StudentModel(
      id: _studentId,
      userId: 'user3',
      instituteId: 'institute1',
      currentLevel: 1,
      currentJuz: 30,
      currentSessionId: 'L1_J30_S8',
      currentSessionKind: SessionKind.exam,
      createdAt: DateTime(2024, 1, 1),
    ),
    user: UserModel(
      id: 'user3',
      email: 'student3@alrasikhoon.local',
      name: 'student3',
      role: UserRole.student,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

/// The اختبار the student stands on: a unit-tier exam over hizb 56, whose
/// verbatim label wraps to two lines on a phone — the tallest realistic header.
SessionModel _examSession() {
  return const SessionModel(
    id: 'L1_J30_S8',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 8,
    orderInLevel: 8,
    kind: SessionKind.exam,
    assessedBy: AssessedBy.supervisor,
    hizbNumber: 56,
    scope: SessionScope(
      tier: AssessmentTier.unit,
      labelAr: 'اختبار في الحزب رقم 56 كاملًا من قِبل إدارة الحلقات',
      hizbNumber: 56,
      juzNumbers: [30],
    ),
  );
}

/// Pumps the screen the way the router does: inside the supervisor shell (a
/// Scaffold whose bottom nav eats ~56px), on a phone-sized viewport with the
/// status bar and home-indicator insets the device reports.
Future<void> _pumpInSupervisorShell(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        examStudentProvider.overrideWith((ref, id) async => _examStudent()),
        examSessionProvider.overrideWith((ref, id) async => _examSession()),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: const ExamSessionScreen(studentId: _studentId),
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 1,
              onTap: (_) {},
              role: UserRole.supervisor,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the اختبار screen fits inside the supervisor shell', (
    tester,
  ) async {
    await _pumpInSupervisorShell(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the end-exam button is reachable on a phone', (tester) async {
    await _pumpInSupervisorShell(tester);

    final endButton = find.text('إنهاء الاختبار');
    expect(endButton, findsOneWidget);

    // Scrolling to it must be possible — and once there it must be on screen,
    // not clipped under the bottom nav.
    await tester.scrollUntilVisible(endButton, 100);
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(endButton);
    final viewport = tester.getRect(find.byType(Scaffold).first);
    expect(buttonRect.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a tall screen the button still sits at the bottom', (
    tester,
  ) async {
    // Making the screen scroll must not turn the layout into a top-aligned
    // list: with room to spare, the Spacer still pushes the button down.
    await _pumpInSupervisorShell(tester, size: const Size(390, 1200));

    final buttonBottom = tester.getRect(find.text('إنهاء الاختبار')).bottom;
    final contentBottom = tester.getRect(find.byType(CustomScrollView)).bottom;
    expect(contentBottom - buttonBottom, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
