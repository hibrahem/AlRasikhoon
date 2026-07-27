import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/completion_forecast.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/supervisor_students_screen.dart';
import 'package:al_rasikhoon/shared/providers/completion_forecast_provider.dart';
import 'package:al_rasikhoon/shared/widgets/text_scale_clamp.dart';

/// The supervisor's تغيير خطة الحفظ dialog hosts the full plan card — two
/// dials plus the متى الختم؟ forecast. On a small phone with the device font
/// size turned up the card is taller than the dialog's available height; the
/// dialog must scroll, not clip the forecast off the bottom edge.
class _FakeAuthRepository extends AuthRepository {
  @override
  AuthState build() => const AuthState();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  // A long remainder so the forecast renders its tallest form: duration line,
  // meetings-and-date line, and the pace hint.
  const remaining = RemainingCurriculum(
    standaloneCount: 100,
    lessonRuns: [300],
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 1,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  testWidgets(
    'the خطة الحفظ dialog scrolls instead of clipping on a small large-font phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supervisorStudentsProvider.overrideWith(
              (ref) async => [StudentWithUser(student: student, user: user)],
            ),
            authRepositoryProvider.overrideWith(_FakeAuthRepository.new),
            remainingCurriculumProvider((
              level: student.currentLevel,
              order: student.currentOrderInLevel,
              completed: false,
            )).overrideWith((ref) async => remaining),
          ],
          // The builder mirrors the real app shell (app.dart): the device
          // setting is 2.0 but the app never honors more than 1.3 — the scale
          // the clipping was reported at. In the builder (not around home) so
          // the clamp covers the sheet and dialog overlays too.
          child: MaterialApp(
            builder: (context, child) => TextScaleClamp(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
            ),
            home: const SupervisorStudentsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the student's actions sheet, then the plan dialog.
      await tester.tap(find.byTooltip('إجراءات الطالب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تغيير خطة الحفظ'));
      await tester.pumpAndSettle();

      // An unscrollable dialog overflows its bottom edge here.
      expect(tester.takeException(), isNull);

      // The whole card must be reachable: scroll the dialog to its
      // bottom-most line (the cadence hint sits under the second dial).
      final dialogScrollable = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      );
      expect(
        dialogScrollable,
        findsWidgets,
        reason: 'the plan dialog offers no way to reach clipped content',
      );
      await tester.scrollUntilVisible(
        find.text('كم لقاءً يحضره الطالب في الأسبوع'),
        100,
        scrollable: dialogScrollable.first,
      );
      expect(
        find.text('كم لقاءً يحضره الطالب في الأسبوع').hitTestable(),
        findsOneWidget,
      );
    },
  );
}
