import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_history_screen.dart';

TeacherHistoryEntry _entry({
  required String id,
  required String studentName,
  required bool passed,
  required DateTime date,
  SessionKind kind = SessionKind.lesson,
}) {
  return TeacherHistoryEntry(
    studentName: studentName,
    instituteId: 'inst1',
    record: SessionRecordModel(
      id: id,
      studentId: 'student-$id',
      teacherId: 'teacher1',
      curriculumSessionId: 'cs1',
      levelId: 2,
      juzNumber: 27,
      sessionNumber: 7,
      orderInLevel: 7,
      kind: kind,
      date: date,
      attemptNumber: 1,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 1,
        distantReviewErrors: 0,
      ),
      passed: passed,
      createdAt: date,
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<TeacherHistoryEntry> entries) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [teacherHistoryProvider.overrideWith((ref) async => entries)],
      child: const MaterialApp(home: TeacherHistoryScreen()),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('each row names the student, the session, and the outcome', (
    tester,
  ) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 15),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('الحلقة 7'), findsOneWidget);
    expect(find.text('المستوى 2'), findsOneWidget);
    expect(find.text('نجح'), findsOneWidget);
    expect(find.text('رسب'), findsNothing);
  });

  testWidgets('a تلقين shows no outcome, while a graded lesson still does', (
    tester,
  ) async {
    // createTalqeenRecord writes `passed: true` unconditionally — that flag
    // says the session happened, it is not a grade. Rendering it would report
    // a pass the student never earned: a تلقين is graded on nothing.
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 16),
        kind: SessionKind.talqeen,
      ),
      _entry(
        id: 'r2',
        studentName: 'خالد',
        passed: false,
        date: DateTime(2024, 3, 15),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('تلقين'), findsNWidgets(2)); // the subtitle and the badge
    expect(find.text('نجح'), findsNothing);
    expect(
      find.text('رسب'),
      findsOneWidget,
    ); // the real lesson keeps its result
  });

  testWidgets('a failed record shows رسب', (tester) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'خالد',
        passed: false,
        date: DateTime(2024, 3, 15),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('رسب'), findsOneWidget);
    expect(find.text('نجح'), findsNothing);
  });

  testWidgets('rows are listed newest first', (tester) async {
    await _pump(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 15),
      ),
      _entry(
        id: 'r2',
        studentName: 'خالد',
        passed: true,
        date: DateTime(2024, 3, 1),
      ),
    ]);
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('أحمد')).dy;
    final oldest = tester.getTopLeft(find.text('خالد')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('empty history shows the empty state', (tester) async {
    await _pump(tester, []);
    await tester.pumpAndSettle();

    expect(find.text('لا يوجد سجل'), findsOneWidget);
  });
}
