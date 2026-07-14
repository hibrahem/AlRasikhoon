import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

/// hibrahem/AlRasikhoon final-review finding #3: a تلقين record must render
/// in the detail view as what it is (a تلقين that happened), never with the
/// grade/pass-fail machinery meant for a graded lesson — it carries no
/// errors and no pass/fail at all.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<void> pump(WidgetTester tester, SessionRecordModel record) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            record.id,
          ).overrideWith((ref) async => record),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionDetailScreen(recordId: record.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a تلقين record shows no grade, no pass/fail, and no error breakdown',
    (tester) async {
      final record = SessionRecordModel(
        id: 'r1',
        studentId: 'student1',
        teacherId: 'teacher1',
        curriculumSessionId: 'L1_J30_S1',
        levelId: 1,
        kind: SessionKind.talqeen,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 1,
        orderInLevel: 1,
        date: DateTime(2026, 7, 14),
        attemptNumber: 1,
        grades: const SessionGrades(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        ),
        passed: true,
        repetitionsWithTeacher: 4,
        homeRepetitionsRequired: 10,
        createdAt: DateTime(2026, 7, 14),
      );

      await pump(tester, record);

      // It reads as what it is.
      expect(find.textContaining('تلقين'), findsWidgets);

      // No pass/fail language, and no per-component grade breakdown.
      expect(find.textContaining('نجح'), findsNothing);
      expect(find.textContaining('رسب'), findsNothing);
      expect(find.text('تفاصيل الأجزاء'), findsNothing);
      expect(find.text('الحفظ الجديد'), findsNothing);
      expect(find.text('المراجعة القريبة'), findsNothing);
      expect(find.text('المراجعة البعيدة'), findsNothing);
      expect(find.textContaining('أخطاء'), findsNothing);
    },
  );

  testWidgets('a graded lesson record still shows its grade and breakdown', (
    tester,
  ) async {
    final record = SessionRecordModel(
      id: 'r2',
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S5',
      levelId: 1,
      kind: SessionKind.lesson,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 5,
      orderInLevel: 5,
      date: DateTime(2026, 7, 14),
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 1,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      createdAt: DateTime(2026, 7, 14),
    );

    await pump(tester, record);

    expect(find.text('تفاصيل الأجزاء'), findsOneWidget);
    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    expect(find.text('المراجعة البعيدة'), findsOneWidget);
  });
}
