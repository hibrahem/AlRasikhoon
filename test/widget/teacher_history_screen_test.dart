import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_history_screen.dart';
import 'package:al_rasikhoon/routing/app_router.dart';

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

/// Where a tapped row landed. An imperative `push` leaves GoRouter's reported
/// location on the base route, so the destination is captured from the route
/// builders themselves — which is also what the screens really read.
class _Landing {
  String? detailRecordId;
  String? overviewStudentId;
}

/// Pumps the history screen inside a router standing in for the teacher shell,
/// so a row's tap can be followed to the route it actually opens.
Future<_Landing> _pumpRouted(
  WidgetTester tester,
  List<TeacherHistoryEntry> entries,
) async {
  final landing = _Landing();
  final router = GoRouter(
    initialLocation: AppRoutes.teacherHistory,
    routes: [
      GoRoute(
        path: AppRoutes.teacherHistory,
        builder: (context, state) => const TeacherHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherSessionDetail,
        builder: (context, state) {
          landing.detailRecordId = state.pathParameters['recordId'];
          return const Scaffold(body: Text('detail'));
        },
      ),
      GoRoute(
        path: AppRoutes.sessionOverview,
        builder: (context, state) {
          landing.overviewStudentId = state.pathParameters['studentId'];
          return const Scaffold(body: Text('overview'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [teacherHistoryProvider.overrideWith((ref) async => entries)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return landing;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  testWidgets('tapping a past record opens THAT record, not the live session', (
    tester,
  ) async {
    // The row is a record of a session already heard. Routing by studentId
    // lands on the student's *current* session overview — today's حلقة, not
    // the one in the row. The record's own id is what identifies it.
    final landing = await _pumpRouted(tester, [
      _entry(
        id: 'r1',
        studentName: 'أحمد',
        passed: true,
        date: DateTime(2024, 3, 15),
      ),
    ]);

    await tester.tap(find.text('أحمد'));
    await tester.pumpAndSettle();

    expect(landing.detailRecordId, 'r1');
    expect(landing.overviewStudentId, isNull);
    expect(find.text('detail'), findsOneWidget);
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
