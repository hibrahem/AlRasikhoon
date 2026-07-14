import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/screens/talqeen_session_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';

void main() {
  const session = SessionModel(
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

  // A تلقين always stands alone (`PacedSessionComposer` never batches one),
  // so its meeting is a single-session `PacedSession` built from the same
  // row — the screen now reads the MEETING, not the session directly.
  final meeting = PacedSession(
    sessions: [session],
    newContent: [
      if (session.currentLevelContent != null) session.currentLevelContent!,
    ],
    recentReview: [
      if (session.recentReviewContent != null) session.recentReviewContent!,
    ],
    distantReview: [
      if (session.distantReviewContent != null) session.distantReviewContent!,
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: TalqeenSessionScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the passage the teacher reads to the student', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('تلقين'), findsWidgets);
    expect(find.text('النبأ: 1 - 11'), findsOneWidget);
  });

  testWidgets('offers the two counts and no error entry', (tester) async {
    await pump(tester);

    expect(find.text('عدد مرات القراءة مع الطالب'), findsOneWidget);
    expect(find.text('عدد مرات التكرار في المنزل'), findsOneWidget);
    // A تلقين is never graded: nothing on this screen counts errors.
    expect(find.textContaining('أخطاء'), findsNothing);
    expect(find.textContaining('نتيجة'), findsNothing);
  });
}
