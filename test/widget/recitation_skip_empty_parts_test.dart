import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_result_screen.dart';

QuranContent _c(String s, int f, int t) =>
    QuranContent(fromSurah: s, fromVerse: f, toSurah: s, toVerse: t);

SessionModel _lesson() => SessionModel(
  id: 'L1_J30_S1',
  levelId: 1,
  juzNumber: 30,
  sessionNumber: 1,
  orderInLevel: 1,
  kind: SessionKind.lesson,
);

/// Seeds an active session directly, bypassing startSession, so the test does
/// not need Firestore. The meeting has new + distant content but NO recent.
PacedSession _meetingNoRecent() => PacedSession(
  sessions: [_lesson()],
  newContent: [_c('النبأ', 1, 11)],
  recentReview: const [],
  distantReview: [_c('الفاتحة', 1, 7)],
);

void main() {
  testWidgets('part-1 result skips empty recent review and points to distant', (
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

    // Seed the active session with the no-recent meeting.
    container
        .read(activeSessionProvider.notifier)
        .seedForTest(
          ActiveSessionState(
            studentId: 'student-1',
            currentPart: 1,
            part1Errors: 1,
            meeting: _meetingNoRecent(),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RecitationResultScreen(
            studentId: 'student-1',
            part: 1,
            errorCount: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The "next" button names the distant review, NOT the recent review.
    expect(find.textContaining('المراجعة البعيدة'), findsWidgets);
    expect(find.textContaining('المراجعة القريبة'), findsNothing);
    // The chip counts present parts (2), not a fixed 3.
    expect(find.text('الجزء 1 من 2'), findsOneWidget);
  });
}
