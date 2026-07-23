import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/domain/curriculum/completion_forecast.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/meetings_per_week.dart';
import 'package:al_rasikhoon/shared/curriculum/forecast_copy.dart';
import 'package:al_rasikhoon/shared/providers/completion_forecast_provider.dart';
import 'package:al_rasikhoon/shared/widgets/student_pace_control.dart';

/// The متى الختم؟ forecast inside the plan card must never starve the duration
/// text of width. Sharing a Row with the intrinsic-width label meant that on a
/// device with a large global font size the duration got only the leftover
/// sliver and Flutter broke its words mid-word into a vertical stack
/// ("7 / سنوا / ت و9 / أشهر"). The duration therefore renders on its own
/// full-width line beneath the title — same layout as CompletionForecastCard.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  // A long remainder so the duration is the multi-word "N سنوات وM أشهر" form
  // that exposed the bug — not a short single word.
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

  testWidgets(
    'duration renders on its own line below the title at a large font scale',
    (tester) async {
      final forecast = CompletionForecast.of(
        remaining: remaining,
        pace: CurriculumPace(student.pace.multiplier),
        meetingsPerWeek: MeetingsPerWeek(student.meetingsPerWeek.count),
      );
      final duration = approxDurationAr(forecast.weeks);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remainingCurriculumProvider((
              level: student.currentLevel,
              order: student.currentOrderInLevel,
              completed: false,
            )).overrideWith((ref) async => remaining),
          ],
          child: MaterialApp(
            home: MediaQuery(
              // A large device font setting — the condition that starved the
              // old Row layout.
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: Center(
                    // The AlertDialog content width the supervisor's تغيير
                    // خطة الحفظ dialog leaves on a 360dp-wide phone.
                    child: SizedBox(
                      width: 232,
                      child: SingleChildScrollView(
                        child: StudentPaceControl(
                          student: student,
                          onPlanChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('متى الختم؟');
      final durationText = find.text(duration);
      expect(title, findsOneWidget);
      expect(durationText, findsOneWidget);

      // Stacked, not squeezed beside the label: the duration starts below the
      // title line, so it owns the card's full content width.
      expect(
        tester.getRect(durationText).top,
        greaterThanOrEqualTo(tester.getRect(title).bottom),
      );
    },
  );
}
