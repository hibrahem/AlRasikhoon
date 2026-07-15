import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/next_content_talqeen_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

SessionModel _lesson(int order) => SessionModel(
  id: 'L1_S$order',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: order,
  orderInLevel: order,
  kind: SessionKind.lesson,
);

PacedSession _meeting(int order, QuranContent newC) => PacedSession(
  sessions: [_lesson(order)],
  newContent: [newC],
  recentReview: const [],
  distantReview: const [],
);

StudentWithUser _studentWithUser() => StudentWithUser(
  student: StudentModel(
    id: 'student-1',
    userId: 'user-1',
    instituteId: 'i1',
    teacherId: 't1',
    currentLevel: 1,
    currentJuz: 30,
    currentHizb: 59,
    currentSession: 1,
    currentAttempt: 1,
    currentOrderInLevel: 2,
    createdAt: DateTime(2026, 1, 1),
  ),
  user: UserModel(
    id: 'user-1',
    username: 'pupil',
    email: 'pupil@x.local',
    name: 'طالب',
    role: UserRole.student,
    authProvider: UserAuthProvider.emailPassword,
    createdAt: DateTime(2026, 1, 1),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required int part1Errors,
  required PacedSession current,
  required PacedSession? next,
}) async {
  final container = ProviderContainer(
    overrides: [
      studentProvider.overrideWith((ref, id) async => _studentWithUser()),
      activeSessionNextMeetingProvider.overrideWith((ref) async => next),
    ],
  );
  addTearDown(container.dispose);

  container
      .read(activeSessionProvider.notifier)
      .seedForTest(
        ActiveSessionState(
          studentId: 'student-1',
          part1Errors: part1Errors,
          meeting: current,
        ),
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: NextContentTalqeenScreen(studentId: 'student-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('passed session previews the NEXT passage', (tester) async {
    await _pump(
      tester,
      part1Errors: 0, // passes
      current: _meeting(2, _c('النبأ', 1, 11)),
      next: _meeting(3, _c('النبأ', 12, 20)),
    );
    expect(find.textContaining('12'), findsWidgets); // next passage
    expect(find.text('إنهاء الحلقة'), findsOneWidget);
  });

  testWidgets('failed session previews the SAME current passage', (
    tester,
  ) async {
    await _pump(
      tester,
      part1Errors: 99, // fails at level 1
      current: _meeting(2, _c('النبأ', 1, 11)),
      next: _meeting(3, _c('النبأ', 12, 20)),
    );
    // Must show the CURRENT meeting's passage (النبأ: 1 - 11) and must NOT
    // show the next meeting's passage (النبأ: 12 - 20) — proves the fail
    // branch picks the current meeting, not the next one.
    expect(find.textContaining('النبأ: 1 - 11'), findsWidgets);
    expect(find.textContaining('12'), findsNothing);
    expect(find.text('إنهاء الحلقة'), findsOneWidget);
  });

  testWidgets('passed session with no next meeting shows the note', (
    tester,
  ) async {
    await _pump(
      tester,
      part1Errors: 0, // passes
      current: _meeting(2, _c('النبأ', 1, 11)),
      next: null, // end of level / no next meeting
    );
    // The no-new-content note replaces the passage — no stale next passage.
    expect(
      find.text('لا يوجد مقطع جديد للتلقين قبل إغلاق الحلقة.'),
      findsOneWidget,
    );
    expect(find.textContaining('12'), findsNothing);
    // The session can still be closed from the note state.
    expect(find.text('إنهاء الحلقة'), findsOneWidget);
  });
}
