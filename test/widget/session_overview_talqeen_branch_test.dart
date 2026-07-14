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

/// Pins the load-bearing branch of the session overview: a student standing
/// on a تلقين MUST reach the تلقين entry point, never the graded-lesson one.
/// The whole point of Task 7 is that `session.isTalqeen` is checked before
/// isExam/isSard and before the regular-lesson fallthrough — if that check
/// were ever removed or reordered, a تلقين would silently be started as a
/// graded recitation instead.
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
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.talqeen,
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
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          // A تلقين always stands alone (`PacedSessionComposer` never
          // batches one), so its meeting is a single-session `PacedSession`
          // built from the same row — the screen now reads the MEETING, not
          // the session directly.
          studentCurrentMeetingProvider('s1').overrideWith(
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
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionOverviewScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a student standing on a تلقين sees the تلقين entry point, not the graded-lesson one',
    (tester) async {
      await pump(tester);

      // The تلقين entry point is present.
      expect(find.text('بدء التلقين'), findsOneWidget);

      // The regular graded-lesson entry point and its part tiles are absent —
      // a تلقين must never be started as a graded recitation.
      expect(find.text('بدء الحلقة'), findsNothing);
      expect(find.text('الحفظ الجديد'), findsNothing);
      expect(find.text('المراجعة القريبة'), findsNothing);
      expect(find.text('المراجعة البعيدة'), findsNothing);
    },
  );
}
