import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_summary_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

void main() {
  testWidgets('summary omits the part card for an empty distant review', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        studentProvider.overrideWith(
          (ref, id) async => StudentWithUser(
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
              currentOrderInLevel: 1,
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
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(activeSessionProvider.notifier)
        .seedForTest(
          ActiveSessionState(
            studentId: 'student-1',
            part1Errors: 1,
            part2Errors: 0,
            part3Errors: 0,
            meeting: PacedSession(
              sessions: [
                SessionModel(
                  id: 'L1_J30_S1',
                  levelId: 1,
                  juzNumber: 30,
                  sessionNumber: 1,
                  orderInLevel: 1,
                  kind: SessionKind.lesson,
                ),
              ],
              newContent: [_c('النبأ', 1, 11)],
              recentReview: [_c('النبأ', 1, 5)],
              distantReview: const [],
            ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SessionSummaryScreen(studentId: 'student-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    expect(find.text('المراجعة البعيدة'), findsNothing);
  });

  testWidgets(
    'summary shows only pass/fail overall and per-part recited content',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          studentProvider.overrideWith(
            (ref, id) async => StudentWithUser(
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
                currentOrderInLevel: 1,
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
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // A passing session (few errors at level 1) reciting the three streams.
      container
          .read(activeSessionProvider.notifier)
          .seedForTest(
            ActiveSessionState(
              studentId: 'student-1',
              part1Errors: 0,
              part2Errors: 1,
              part3Errors: 0,
              meeting: PacedSession(
                sessions: [
                  SessionModel(
                    id: 'L1_J30_S1',
                    levelId: 1,
                    juzNumber: 30,
                    sessionNumber: 1,
                    orderInLevel: 1,
                    kind: SessionKind.lesson,
                  ),
                ],
                newContent: [_c('النبأ', 1, 11)],
                recentReview: [_c('النبأ', 1, 5)],
                distantReview: [_c('عبس', 1, 10)],
              ),
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SessionSummaryScreen(studentId: 'student-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overall result is pass/fail ONLY — the category name (متقن here, given
      // one error at level 1) must NOT appear as an overall grade.
      expect(find.text('ناجح'), findsOneWidget);
      expect(find.text('راسب'), findsNothing);

      // Each present part shows the passage the student recited for it.
      expect(find.textContaining('النبأ: 1 - 11'), findsOneWidget);
      expect(find.textContaining('النبأ: 1 - 5'), findsOneWidget);
      expect(find.textContaining('عبس: 1 - 10'), findsOneWidget);
    },
  );
}
