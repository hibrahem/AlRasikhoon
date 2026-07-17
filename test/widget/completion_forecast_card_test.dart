import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/domain/curriculum/completion_forecast.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/meetings_per_week.dart';
import 'package:al_rasikhoon/shared/providers/completion_forecast_provider.dart';
import 'package:al_rasikhoon/shared/widgets/completion_forecast_card.dart';

/// The "متى الختم؟" card: the headline is the student's ACTUAL plan; the
/// simulator below re-evaluates the same remainder at any pace × cadence and
/// NEVER writes — there is no repository in this test's graph at all, so any
/// write attempt would throw, and the card must not need one.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  // lesson runs [4, 2] + سرد + اختبار: 5 meetings at 2×, 4 at 10×.
  const remaining = RemainingCurriculum(standaloneCount: 2, lessonRuns: [4, 2]);

  StudentModel student() => StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.lesson,
    pace: CurriculumPace(2),
    meetingsPerWeek: MeetingsPerWeek(2),
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remainingCurriculumProvider((
            level: 1,
            order: 1,
            completed: false,
          )).overrideWith((ref) async => remaining),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: CompletionForecastCard(student: student()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the headline forecasts the student\'s actual plan', (
    tester,
  ) async {
    await pump(tester);

    // 5 meetings at the stored 2× plan, 2 a week → 3 weeks.
    expect(find.text('متى الختم؟'), findsOneWidget);
    expect(find.text('3 أسابيع'), findsOneWidget);
    expect(find.textContaining('5 لقاءات'), findsOneWidget);
    expect(find.textContaining('الختم المتوقع'), findsOneWidget);
    // The hint that explains why higher paces flatten: the 2 standalone
    // تقييم/تلقين rows keep their meetings at any pace.
    expect(find.textContaining('التقييمات والتلقين'), findsOneWidget);
  });

  testWidgets('the simulator re-evaluates locally and never writes', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('ماذا لو تغيّرت الخطة؟'));
    await tester.pumpAndSettle();

    // Seeded from the student's real plan: the sim result equals the headline.
    expect(
      find.text('محاكاة فقط — لا تغيّر خطة الطالب المسجلة.'),
      findsOneWidget,
    );
    expect(find.text('3 أسابيع'), findsNWidgets(2));

    // The slider offers only the useful range — past it, assessments dominate
    // and higher paces stop buying time (see CurriculumPace.maxUsefulMultiplier).
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.max, CurriculumPace.maxUsefulMultiplier.toDouble());

    // Push the what-if pace to the 5× cap → 4 meetings → 2 weeks.
    slider.onChanged!(CurriculumPace.maxUsefulMultiplier.toDouble());
    await tester.pumpAndSettle();

    expect(find.text('أسبوعان'), findsOneWidget);
    // The headline still shows the stored plan, untouched.
    expect(find.text('3 أسابيع'), findsOneWidget);
  });
}
