import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/core/constants/app_colors.dart';
import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/domain/session/session_duration.dart';
import 'package:al_rasikhoon/shared/widgets/session_record_row.dart';

void main() {
  setUpAll(() async {
    // The row formats the date with the Arabic locale.
    await initializeDateFormatting('ar');
  });

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(body: child),
  );

  /// The color the duration text paints itself in — the status→color mapping
  /// under test. Reads it off the duration [Text] found by its `المدة:` prefix,
  /// not the row's other (pass/fail, subtitle) texts.
  Color? durationColor(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  SessionRecordRow rowWith(SessionDuration duration) => SessionRecordRow(
    title: 'أحمد',
    subtitleLines: const ['الحلقة ٥'],
    passed: true,
    date: DateTime(2026, 1, 1),
    sessionDuration: duration,
  );

  testWidgets('shows the duration as mm:ss including seconds', (tester) async {
    await tester.pumpWidget(
      host(
        rowWith(
          SessionDuration(elapsed: const Duration(minutes: 18, seconds: 7)),
        ),
      ),
    );
    // Seconds are shown, not rounded away to a whole-minute label.
    expect(find.text('المدة: 18:07'), findsOneWidget);
  });

  testWidgets('color-codes an over-target session red, with no band label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        rowWith(
          SessionDuration(
            elapsed: const Duration(minutes: 40, seconds: 30),
            target: SessionDuration.targetForPace(1), // 20 min → 40:30 is over
          ),
        ),
      ),
    );
    expect(find.text('المدة: 40:30'), findsOneWidget);
    // Beyond target is red (the maroon design token) — color carries the
    // meaning, so the old verbose Arabic band labels are gone.
    expect(durationColor(tester, 'المدة: 40:30'), AppTokens.light.maroon);
    expect(find.textContaining('أطول من المستهدف'), findsNothing);
  });

  testWidgets('color-codes an on-target session green', (tester) async {
    await tester.pumpWidget(
      host(
        rowWith(
          SessionDuration(
            elapsed: const Duration(minutes: 20),
            target: SessionDuration.targetForPace(1), // 20 min → on target
          ),
        ),
      ),
    );
    expect(durationColor(tester, 'المدة: 20:00'), AppColors.success);
    expect(find.textContaining('ضمن المستهدف'), findsNothing);
  });

  testWidgets('color-codes a faster-than-target session yellow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        rowWith(
          SessionDuration(
            elapsed: const Duration(minutes: 5),
            target: SessionDuration.targetForPace(1), // 20 min → under (faster)
          ),
        ),
      ),
    );
    // Faster than target is yellow (the amber status color), not blue/info.
    expect(durationColor(tester, 'المدة: 05:00'), AppColors.warning);
    expect(find.textContaining('أقصر من المستهدف'), findsNothing);
  });

  testWidgets('shows a neutral duration for an assessment (no target)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(rowWith(SessionDuration(elapsed: const Duration(minutes: 18)))),
    );
    // No target → time shown plainly in the neutral secondary color, no color
    // coding and no band label.
    expect(find.text('المدة: 18:00'), findsOneWidget);
    expect(durationColor(tester, 'المدة: 18:00'), AppTokens.light.sepia);
    expect(find.textContaining('أطول'), findsNothing);
    expect(find.textContaining('أقصر'), findsNothing);
    expect(find.textContaining('ضمن'), findsNothing);
  });

  testWidgets('renders no duration line when the record has no duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SessionRecordRow(
          title: 'أحمد',
          subtitleLines: const ['الحلقة ٥'],
          passed: true,
          date: DateTime(2026, 1, 1),
          // sessionDuration omitted → no duration line.
        ),
      ),
    );
    expect(find.textContaining('المدة'), findsNothing);
  });
}
