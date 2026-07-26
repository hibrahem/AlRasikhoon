import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/domain/session/home_practice_log.dart';
import 'package:al_rasikhoon/shared/providers/home_assignment_status_provider.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import 'package:al_rasikhoon/shared/widgets/home_practice_status_card.dart';

/// The teacher/supervisor/admin-facing card that answers, before a session
/// starts, whether the student did the assigned home repetition — and WHEN.
/// The dated per-submission lines are the feature: a bare total can't tell
/// "practised all week" from "logged everything five minutes ago".
void main() {
  setUpAll(() async {
    // The card formats each submission's date with the Arabic locale.
    await initializeDateFormatting('ar');
  });

  Future<void> pump(WidgetTester tester, HomeAssignmentStatus? status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeAssignmentStatusProvider.overrideWith(
            (ref, studentId) async => status,
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomePracticeStatusCard(studentId: 'student-1'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows done-of-required and one dated line per submission', (
    tester,
  ) async {
    await pump(
      tester,
      HomeAssignmentStatus(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 10,
        practices: [
          HomePracticeLog(date: DateTime(2026, 7, 20), repetitions: 3),
          HomePracticeLog(date: DateTime(2026, 7, 18), repetitions: 1),
        ],
      ),
    );

    expect(find.text('التكرار في المنزل'), findsOneWidget);
    expect(find.text('أنجز الطالب 4 من 10 تكرارًا مطلوبًا'), findsOneWidget);
    expect(find.text('غير مكتمل'), findsOneWidget);
    // Each submission keeps its own date — the count phrase follows Arabic
    // singular/plural agreement.
    expect(find.textContaining('3 مرات'), findsOneWidget);
    expect(find.textContaining('مرة واحدة'), findsOneWidget);
    expect(find.textContaining('2026/07/20'), findsOneWidget);
    expect(find.textContaining('2026/07/18'), findsOneWidget);
  });

  testWidgets('reads مكتمل once the assignment is met', (tester) async {
    await pump(
      tester,
      HomeAssignmentStatus(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 5,
        practices: [
          HomePracticeLog(date: DateTime(2026, 7, 20), repetitions: 5),
        ],
      ),
    );

    expect(find.text('مكتمل'), findsOneWidget);
  });

  testWidgets('says the student has not started when nothing was logged', (
    tester,
  ) async {
    await pump(
      tester,
      const HomeAssignmentStatus(
        curriculumSessionId: 'L1_J30_S2',
        repetitionsRequired: 5,
        practices: [],
      ),
    );

    expect(find.text('لم يبدأ'), findsOneWidget);
    expect(
      find.text('لم يسجّل الطالب أي تكرار في المنزل بعد'),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing at all when there is no assignment', (
    tester,
  ) async {
    await pump(tester, null);

    // No visible surface — not an empty card shell with a dangling title.
    expect(find.text('التكرار في المنزل'), findsNothing);
    expect(find.byType(AppCard), findsNothing);
    expect(tester.getSize(find.byType(HomePracticeStatusCard)), Size.zero);
  });
}
