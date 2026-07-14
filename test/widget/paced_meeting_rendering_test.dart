import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/session_overview_screen.dart';

/// A 2x student meets TWO lessons in one sitting. Every screen that teaches him
/// must show both passages — showing only the first would have him memorize half
/// of what he was assigned, silently.
void main() {
  QuranContent content(String surah, int from, int to) => QuranContent(
    fromSurah: surah,
    fromVerse: from,
    toSurah: surah,
    toVerse: to,
  );

  SessionModel lesson(int order, QuranContent newContent) => SessionModel(
    id: 'L1_J30_S$order',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: order,
    orderInLevel: order,
    kind: SessionKind.lesson,
    currentLevelContent: newContent,
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S5',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 5,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, PacedSession meeting) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
        ],
        child: const MaterialApp(home: SessionOverviewScreen(studentId: 's1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a doubled meeting shows both passages it teaches', (
    tester,
  ) async {
    // The two lessons' new content is deliberately NOT contiguous (a gap
    // between verse 37 and verse 45): `PacedSession`'s display merge legitimately
    // collapses contiguous blocks into one range (pinned in
    // paced_session_display_test.dart — 31-37 then 38-40 would merge into a
    // single "31 - 40"), which would make this test pass even if the screen
    // showed only one genuinely separate passage. A gap keeps the two blocks
    // distinct, so finding both proves the screen renders the whole meeting.
    final doubled = PacedSession(
      sessions: [
        lesson(5, content('النبأ', 31, 37)),
        lesson(6, content('النبأ', 45, 50)),
      ],
      newContent: [content('النبأ', 31, 37), content('النبأ', 45, 50)],
      recentReview: [content('النبأ', 12, 20), content('النبأ', 21, 30)],
      distantReview: const [],
    );

    await pump(tester, doubled);

    expect(find.textContaining('النبأ: 31 - 37'), findsOneWidget);
    expect(find.textContaining('النبأ: 45 - 50'), findsOneWidget);
  });

  testWidgets('a standard meeting shows exactly the one passage, as before', (
    tester,
  ) async {
    final standard = PacedSession(
      sessions: [lesson(5, content('النبأ', 31, 37))],
      newContent: [content('النبأ', 31, 37)],
      recentReview: [content('النبأ', 12, 30)],
      distantReview: const [],
    );

    await pump(tester, standard);

    expect(find.textContaining('النبأ: 31 - 37'), findsOneWidget);
    expect(find.textContaining('النبأ: 38 - 40'), findsNothing);
  });
}
