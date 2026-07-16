import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

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
          curriculumSessionByIdProvider(
            record.curriculumSessionId,
          ).overrideWith((ref) async => null),
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

  SessionRecordModel record({
    int attemptNumber = 1,
    int paceAtTime = 1,
    Duration? duration,
    int repetitionsWithTeacher = 0,
    int homeRepetitionsRequired = 0,
    SessionKind kind = SessionKind.lesson,
  }) {
    return SessionRecordModel(
      id: 'r1',
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S5',
      levelId: 1,
      kind: kind,
      juzNumber: 30,
      sessionNumber: 5,
      fromOrderInLevel: 5,
      toOrderInLevel: 5,
      coversSessionIds: const ['L1_J30_S5'],
      paceAtTime: paceAtTime,
      date: DateTime(2026, 7, 14),
      attemptNumber: attemptNumber,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      repetitionsWithTeacher: repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired,
      createdAt: DateTime(2026, 7, 14),
      duration: duration,
    );
  }

  testWidgets('attempt chip is relabeled رقم المحاولة', (tester) async {
    await pump(tester, record(attemptNumber: 2));
    expect(find.text('رقم المحاولة'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('pace chip is hidden at 1x', (tester) async {
    await pump(tester, record(paceAtTime: 1));
    expect(find.text('المقدار'), findsNothing);
  });

  testWidgets('pace chip reads ضعف الكمّ at 2x', (tester) async {
    await pump(tester, record(paceAtTime: 2));
    expect(find.text('المقدار'), findsOneWidget);
    expect(find.text('ضعف الكمّ'), findsOneWidget);
  });

  testWidgets('pace chip reads ثلاثة أضعاف at 3x', (tester) async {
    await pump(tester, record(paceAtTime: 3));
    expect(find.text('ثلاثة أضعاف'), findsOneWidget);
  });

  testWidgets('duration chip is hidden when the record has no duration', (
    tester,
  ) async {
    await pump(tester, record(duration: null));
    expect(find.text('المدة'), findsNothing);
  });

  testWidgets('duration chip shows the formatted length', (tester) async {
    await pump(
      tester,
      record(duration: const Duration(minutes: 7, seconds: 12)),
    );
    expect(find.text('المدة'), findsOneWidget);
    expect(find.text('7 د 12 ث'), findsOneWidget);
  });

  testWidgets('both repetition counts are shown with clear labels', (
    tester,
  ) async {
    await pump(
      tester,
      record(repetitionsWithTeacher: 3, homeRepetitionsRequired: 5),
    );
    expect(find.text('التكرار مع المعلم'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('التكرار المطلوب في البيت'), findsOneWidget);
    expect(find.text('5 مرات'), findsOneWidget);
  });

  testWidgets('repetition chips hidden when zero', (tester) async {
    await pump(tester, record());
    expect(find.text('التكرار مع المعلم'), findsNothing);
    expect(find.text('التكرار المطلوب في البيت'), findsNothing);
  });

  testWidgets('attempt chip is omitted for a تلقين', (tester) async {
    await pump(tester, record(kind: SessionKind.talqeen));
    expect(find.text('رقم المحاولة'), findsNothing);
  });
}
