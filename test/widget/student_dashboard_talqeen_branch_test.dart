import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/shared/providers/current_student_provider.dart';
import 'package:al_rasikhoon/shared/providers/stats_provider.dart';
import 'package:al_rasikhoon/features/student/screens/student_dashboard_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

/// Pins the load-bearing branch of the student dashboard's current-session
/// card: a student standing on a تلقين MUST see the تلقين card, never the
/// graded-lesson card that tells him to memorize a passage the teacher has
/// not yet read to him. The teacher's mirror of this screen
/// (`student_profile_screen.dart`) already checks `isTalqeen` before
/// isExam/isSard and the lesson fallthrough — this test pins the same
/// ordering on the student's screen.
void main() {
  const talqeenSession = SessionModel(
    id: 'L1_J30_S1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 1,
    kind: SessionKind.talqeen,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 11,
    ),
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentLevel: 1,
    currentJuz: 30,
    currentSession: 1,
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.talqeen,
    currentOrderInLevel: 1,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(user),
          currentStudentProvider.overrideWith((ref) async => student),
          // A تلقين always stands alone (`PacedSessionComposer` never
          // batches one), so its meeting is a single-session `PacedSession`
          // built from the same row — the screen now reads the MEETING, not
          // the session directly.
          studentDashboardMeetingProvider.overrideWith(
            (ref) async => PacedSession(
              sessions: [talqeenSession],
              newContent: [
                if (talqeenSession.currentLevelContent != null)
                  talqeenSession.currentLevelContent!,
              ],
              recentReview: [
                if (talqeenSession.recentReviewContent != null)
                  talqeenSession.recentReviewContent!,
              ],
              distantReview: [
                if (talqeenSession.distantReviewContent != null)
                  talqeenSession.distantReviewContent!,
              ],
            ),
          ),
          studentStatsProvider.overrideWith(
            (ref) async => const StudentStats(
              currentLevel: 1,
              currentJuz: 30,
              currentSession: 1,
              currentOrderInLevel: 1,
            ),
          ),
          homePracticeStatsProvider.overrideWith(
            (ref) async => const HomePracticeStats(),
          ),
          homeAssignmentProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentDashboardScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a student standing on a تلقين sees the تلقين card, not the '
      'new-memorization lesson card', (tester) async {
    await pump(tester);

    // The تلقين card names the session as what it is, and says the teacher
    // will read the passage WITH the student — never as new memorization
    // for the student to recite alone.
    expect(find.textContaining('تلقين'), findsWidgets);
    expect(find.text('الحفظ الجديد'), findsNothing);

    // No grade, no error counts: a تلقين is never graded.
    expect(find.text('نجح'), findsNothing);
    expect(find.text('رسب'), findsNothing);
  });
}
