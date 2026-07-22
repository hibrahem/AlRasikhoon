import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/shared/widgets/session_record_row.dart';

/// The pending-sync chip must be visible where the writing device shows its
/// history: `hasPendingWrites` is only ever true on the device that queued
/// the offline write — the teacher's — and both the teacher's and the
/// student's history render rows through [SessionRecordRow]
/// (al_rasikhoon-q4m). The admin/supervisor progress screen's chip alone can
/// never be seen in the offline scenario it was designed for.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  SessionRecordRow row({required bool pending}) => SessionRecordRow(
    title: 'أحمد',
    subtitleLines: const ['الحلقة ٥'],
    passed: true,
    date: DateTime(2026, 1, 1),
    isPendingSync: pending,
  );

  testWidgets('a record saved offline carries the pending-sync chip', (
    tester,
  ) async {
    await tester.pumpWidget(host(row(pending: true)));
    expect(find.text('بانتظار المزامنة'), findsOneWidget);
  });

  testWidgets('a synced record carries no pending-sync chip', (tester) async {
    await tester.pumpWidget(host(row(pending: false)));
    expect(find.text('بانتظار المزامنة'), findsNothing);
  });
}
