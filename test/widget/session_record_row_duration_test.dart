import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

  testWidgets('shows the duration and an over-target flag', (tester) async {
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
    expect(find.textContaining('أطول'), findsOneWidget); // over-target label
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
