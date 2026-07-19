import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  StudentHistoryEntry entry({required bool pending}) => StudentHistoryEntry(
    id: 'r1',
    kind: StudentHistoryKind.lesson,
    levelId: 1,
    sessionNumber: 3,
    passed: true,
    date: DateTime(2026, 1, 1),
    isPendingSync: pending,
  );

  Widget host(StudentHistoryEntry e) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: SessionHistoryList(
            entries: [e],
            sessionDetailRoute: '/session/:recordId',
            assessmentDetailRoute: '/assessment/:kind/:recordId',
          ),
        ),
      ),
    ),
  );

  testWidgets('an unsynced record carries the pending-sync chip', (
    tester,
  ) async {
    await tester.pumpWidget(host(entry(pending: true)));
    expect(find.text('بانتظار المزامنة'), findsOneWidget);
  });

  testWidgets('a synced record carries no pending-sync chip', (tester) async {
    await tester.pumpWidget(host(entry(pending: false)));
    expect(find.text('بانتظار المزامنة'), findsNothing);
  });
}
