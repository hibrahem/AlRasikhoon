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

  Future<void> pump(
    WidgetTester tester,
    SessionRecordModel record, {
    SessionModel? session,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            record.id,
          ).overrideWith((ref) async => record),
          curriculumSessionByIdProvider(
            record.curriculumSessionId,
          ).overrideWith((ref) async => session),
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
        fromOrderInLevel: 1,
        toOrderInLevel: 1,
        coversSessionIds: const ['L1_J30_S1'],
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
      fromOrderInLevel: 5,
      toOrderInLevel: 5,
      coversSessionIds: const ['L1_J30_S5'],
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

  // A review-only or short meeting omits recent/distant review. History must
  // render only the parts actually recited — a skipped part is absence, not a
  // passing zero-error card.
  testWidgets(
    'a meeting that skipped review parts shows only what it recited',
    (tester) async {
      final record = SessionRecordModel(
        id: 'r4',
        studentId: 'student1',
        teacherId: 'teacher1',
        curriculumSessionId: 'L1_J30_S2',
        levelId: 1,
        kind: SessionKind.lesson,
        juzNumber: 30,
        hizbNumber: 59,
        sessionNumber: 2,
        fromOrderInLevel: 2,
        toOrderInLevel: 2,
        coversSessionIds: const ['L1_J30_S2'],
        date: DateTime(2026, 7, 14),
        attemptNumber: 1,
        grades: const SessionGrades(
          newMemorizationErrors: 1,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        ),
        presentParts: const [1],
        passed: true,
        createdAt: DateTime(2026, 7, 14),
      );

      await pump(tester, record);

      expect(find.text('تفاصيل الأجزاء'), findsOneWidget);
      expect(find.text('الحفظ الجديد'), findsOneWidget);
      // The skipped review parts must not appear at all.
      expect(find.text('المراجعة القريبة'), findsNothing);
      expect(find.text('المراجعة البعيدة'), findsNothing);
    },
  );

  // A record written before the present-parts marker shipped carries no marker.
  // It must fall back to all three parts — the parts it actually recited are
  // not reconstructable, so the legacy view is preserved rather than guessed.
  testWidgets('a legacy record with no marker still shows all three parts', (
    tester,
  ) async {
    final record = SessionRecordModel.fromJson('r5', {
      'student_id': 'student1',
      'teacher_id': 'teacher1',
      'curriculum_session_id': 'L1_J30_S6',
      'level_id': 1,
      'kind': 'lesson',
      'grades': {
        'new_memorization_errors': 0,
        'recent_review_errors': 0,
        'distant_review_errors': 0,
      },
      'passed': true,
      // No `present_parts` key — a pre-marker record.
    });

    await pump(tester, record);

    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    expect(find.text('المراجعة البعيدة'), findsOneWidget);
  });

  // The record stores the curriculum session's ID (`L1_J30_S5`). That is a key,
  // not a name: a student reading his own history must see the session's Arabic
  // title, never the raw id.
  testWidgets('the header names the session in Arabic, not by its raw id', (
    tester,
  ) async {
    final record = SessionRecordModel(
      id: 'r3',
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S5',
      levelId: 1,
      kind: SessionKind.lesson,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 5,
      fromOrderInLevel: 5,
      toOrderInLevel: 5,
      coversSessionIds: const ['L1_J30_S5'],
      date: DateTime(2026, 7, 14),
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      createdAt: DateTime(2026, 7, 14),
    );

    await pump(
      tester,
      record,
      session: const SessionModel(
        id: 'L1_J30_S5',
        levelId: 1,
        juzNumber: 30,
        sessionNumber: 5,
        orderInLevel: 5,
        kind: SessionKind.lesson,
        unitIndex: 1,
        hizbNumber: 59,
      ),
    );

    expect(find.text('الحلقة 5 - الجزء 30'), findsOneWidget);
    expect(find.text('L1_J30_S5'), findsNothing);
  });
}
