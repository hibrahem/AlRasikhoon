import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_history_screen.dart';

/// Listing-display test for hibrahem/AlRasikhoon#24.
///
/// The session-list row must show ONLY a binary outcome (نجح / رسب) — never
/// an averaged grade and never the per-component (new/near/far) grade
/// breakdown. The breakdown belongs in the session detail view only.
SessionRecordModel _record({
  required String id,
  required bool passed,
  required SessionGrades grades,
}) {
  final now = DateTime(2024, 3, 15);
  return SessionRecordModel(
    id: id,
    studentId: 'student1',
    teacherId: 'teacher1',
    curriculumSessionId: 'cs1',
    levelId: 1,
    hizbNumber: 59,
    sessionNumber: 1,
    date: now,
    attemptNumber: 1,
    grades: grades,
    passed: passed,
    createdAt: now,
  );
}

Future<void> _pumpHistory(
  WidgetTester tester,
  List<SessionRecordModel> records,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentHistoryProvider.overrideWith((ref) async => records),
      ],
      child: const MaterialApp(
        home: SessionHistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // The screen formats dates with the Arabic locale.
    await initializeDateFormatting('ar');
  });

  group('SessionHistoryScreen listing (#24)', () {
    testWidgets('failed session row shows رسب (binary), not a grade name',
        (tester) async {
      // far = محب (4 errors @ level 1) ⇒ failed. The other two are good, but
      // the listing must not surface an averaged grade — only رسب.
      await _pumpHistory(tester, [
        _record(
          id: 'r1',
          passed: false,
          grades: const SessionGrades(
            newMemorizationErrors: 0,
            recentReviewErrors: 1,
            distantReviewErrors: 4,
          ),
        ),
      ]);

      expect(find.text('رسب'), findsOneWidget);
      expect(find.text('نجح'), findsNothing);

      // No per-component grade breakdown leaks into the list row.
      expect(find.text('راسخ'), findsNothing);
      expect(find.text('متقن'), findsNothing);
      expect(find.text('محب'), findsNothing);
      // No averaged "X أخطاء" total shown in the row.
      expect(find.textContaining('أخطاء'), findsNothing);
    });

    testWidgets('passed session row shows نجح (binary), not a grade name',
        (tester) async {
      await _pumpHistory(tester, [
        _record(
          id: 'r2',
          passed: true,
          grades: const SessionGrades(
            newMemorizationErrors: 0,
            recentReviewErrors: 1,
            distantReviewErrors: 3,
          ),
        ),
      ]);

      expect(find.text('نجح'), findsOneWidget);
      expect(find.text('رسب'), findsNothing);
      expect(find.text('مجتهد'), findsNothing);
    });
  });
}
