import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';

/// Pins the gap this migration closed: `StudentProgressScreen` — the
/// role-agnostic read-only view an admin or supervisor opens — used to read a
/// single `SessionModel`, so a 2x student's progress view showed only the
/// FIRST of the two lessons he is actually working on, silently understating
/// his assignment. The screen now reads a `PacedSession` (the meeting), the
/// same way `StudentProfileScreen` already does
/// (`paced_meeting_rendering_test.dart` pins the teacher-side twin of this).
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
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          adminStudentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
          adminStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => <StudentHistoryEntry>[]),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentProgressScreen(
              studentId: 's1',
              studentProvider: adminStudentProvider,
              currentMeetingProvider: adminStudentCurrentMeetingProvider,
              sessionHistoryProvider: adminStudentSessionHistoryProvider,
              sessionDetailRoute: '/admin/students/history/:recordId',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'an admin viewing a 2x student\'s progress sees BOTH passages the '
    'meeting covers, not just the first',
    (tester) async {
      // The two lessons' new content is deliberately NOT contiguous (a gap
      // between verse 37 and verse 45): `PacedSession`'s display merge
      // legitimately collapses contiguous blocks into one range (see the
      // adjacent-lessons case below), which would make this test pass even
      // if the screen showed only one genuinely separate passage. A gap
      // keeps the two blocks distinct, so finding both proves the screen
      // renders the whole meeting, not `meeting.first` alone.
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
    },
  );

  testWidgets(
    'an admin viewing a 2x student\'s progress on two verse-adjacent lessons '
    'sees ONE merged range, not two halves',
    (tester) async {
      // The realistic case, unlike the fixture above: النبأ 31-37 and its
      // immediate continuation 38-40 are verse-adjacent (same surah,
      // 38 == 37 + 1), so `PacedSession.newContentAr` merges them into a
      // single "النبأ: 31 - 40". Built from the two SEPARATE blocks — never a
      // pre-merged one — so the merge under test is the getter's, exactly as
      // it runs in production.
      final adjacent = PacedSession(
        sessions: [
          lesson(5, content('النبأ', 31, 37)),
          lesson(6, content('النبأ', 38, 40)),
        ],
        newContent: [content('النبأ', 31, 37), content('النبأ', 38, 40)],
        recentReview: [content('النبأ', 12, 30)],
        distantReview: const [],
      );

      await pump(tester, adjacent);

      expect(find.textContaining('النبأ: 31 - 40'), findsOneWidget);
      expect(find.textContaining('النبأ: 31 - 37'), findsNothing);
    },
  );

  testWidgets(
    'an admin viewing a 1x student\'s progress sees exactly the one passage, '
    'unchanged from before',
    (tester) async {
      final standard = PacedSession(
        sessions: [lesson(5, content('النبأ', 31, 37))],
        newContent: [content('النبأ', 31, 37)],
        recentReview: [content('النبأ', 12, 30)],
        distantReview: const [],
      );

      await pump(tester, standard);

      expect(find.textContaining('النبأ: 31 - 37'), findsOneWidget);
      expect(find.textContaining('النبأ: 38 - 40'), findsNothing);
      expect(find.textContaining('النبأ: 45 - 50'), findsNothing);
    },
  );
}
