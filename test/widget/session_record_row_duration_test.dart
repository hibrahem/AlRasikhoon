import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/core/constants/app_colors.dart';
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

  /// The color the flag pill paints its label in — the status→color mapping
  /// under test. Reads it off the flag's own [Text] rather than any of the
  /// row's other (pass/fail, subtitle) texts.
  Color? flagColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.color;

  testWidgets('shows the duration and an over-target flag colored warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SessionRecordRow(
          title: 'أحمد',
          subtitleLines: const ['الحلقة ٥'],
          passed: true,
          date: DateTime(2026, 1, 1),
          sessionDuration: SessionDuration(
            elapsed: const Duration(minutes: 40),
            target: SessionDuration.targetForPace(1), // 20 min → 40 is over
          ),
        ),
      ),
    );
    expect(find.textContaining('المدة'), findsOneWidget);
    expect(find.text('أطول من المستهدف'), findsOneWidget); // over-target label
    // An over-target session flags in the warning color, not success/info.
    expect(flagColor(tester, 'أطول من المستهدف'), AppColors.warning);
  });

  testWidgets('flags an on-target session in the success color', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SessionRecordRow(
          title: 'أحمد',
          subtitleLines: const ['الحلقة ٥'],
          passed: true,
          date: DateTime(2026, 1, 1),
          sessionDuration: SessionDuration(
            elapsed: const Duration(minutes: 20),
            target: SessionDuration.targetForPace(1), // 20 min → on target
          ),
        ),
      ),
    );
    expect(find.text('ضمن المستهدف'), findsOneWidget);
    expect(flagColor(tester, 'ضمن المستهدف'), AppColors.success);
  });

  testWidgets('flags an under-target session in the info color', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SessionRecordRow(
          title: 'أحمد',
          subtitleLines: const ['الحلقة ٥'],
          passed: true,
          date: DateTime(2026, 1, 1),
          sessionDuration: SessionDuration(
            elapsed: const Duration(minutes: 5),
            target: SessionDuration.targetForPace(1), // 20 min → under
          ),
        ),
      ),
    );
    expect(find.text('أقصر من المستهدف'), findsOneWidget);
    expect(flagColor(tester, 'أقصر من المستهدف'), AppColors.info);
  });

  testWidgets('shows the duration but no flag for an assessment (no target)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        SessionRecordRow(
          title: 'أحمد',
          subtitleLines: const ['سرد'],
          passed: true,
          date: DateTime(2026, 1, 1),
          sessionDuration: SessionDuration(
            elapsed: const Duration(minutes: 18),
          ),
        ),
      ),
    );
    expect(find.textContaining('المدة'), findsOneWidget);
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
          // sessionDuration omitted → no duration line, no flag.
        ),
      ),
    );
    expect(find.textContaining('المدة'), findsNothing);
  });
}
