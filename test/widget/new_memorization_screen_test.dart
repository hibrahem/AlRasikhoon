import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/new_memorization_screen.dart';

/// Task 9 replaced this screen's four-field breakdown (من سورة / من آية /
/// إلى سورة / إلى آية) with one `المقطع` row that renders
/// `meeting.newContentAr` — a batch's new content is a LIST of blocks, which
/// four scalar fields cannot represent. That change shipped with no test at
/// all. This file pins it: the 1x case must read exactly as the old four
/// fields would have spelled it out, the 2x adjacent case must show the
/// MERGED range (never the unmerged halves), and a meeting that teaches no
/// new content (a سرد or an اختبار carries none) must reach the screen's
/// empty state — guarded by `meeting.hasNewContent` — rather than
/// dereferencing an empty list.
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

  Future<void> pump(WidgetTester tester, PacedSession meeting) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
        ],
        child: const MaterialApp(home: NewMemorizationScreen(studentId: 's1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a standard meeting shows the single passage, byte-identical to the old four-field breakdown',
    (tester) async {
      final standard = PacedSession(
        sessions: [lesson(5, content('النبأ', 31, 37))],
        newContent: [content('النبأ', 31, 37)],
        recentReview: [content('النبأ', 12, 30)],
        distantReview: const [],
      );

      await pump(tester, standard);

      expect(find.text('المقطع'), findsOneWidget);
      expect(find.text('النبأ: 31 - 37'), findsOneWidget);
      expect(find.text('لا يوجد حفظ جديد في هذه الحلقة'), findsNothing);
    },
  );

  testWidgets(
    'a doubled meeting on two verse-adjacent lessons shows the MERGED passage, not the two halves',
    (tester) async {
      // النبأ 31-37 then its immediate continuation 38-40 are verse-adjacent
      // (38 == 37 + 1), so `PacedSession.newContentAr` merges them into one
      // "النبأ: 31 - 40" — built from the two SEPARATE blocks so the merge
      // under test is the getter's, exactly as it runs in production.
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

      expect(find.text('النبأ: 31 - 40'), findsOneWidget);
      expect(find.text('النبأ: 31 - 37'), findsNothing);
    },
  );

  testWidgets(
    'a meeting with no new content (an اختبار carries none) shows the empty state instead of crashing',
    (tester) async {
      final examSession = SessionModel(
        id: 'L1_J30_S68',
        levelId: 1,
        juzNumber: 30,
        sessionNumber: 68,
        orderInLevel: 68,
        kind: SessionKind.exam,
      );

      final assessment = PacedSession(
        sessions: [examSession],
        newContent: const [],
        recentReview: [content('النبأ', 1, 40)],
        distantReview: [content('الفاتحة', 1, 7)],
      );

      expect(assessment.hasNewContent, isFalse);

      await pump(tester, assessment);

      expect(find.text('لا يوجد حفظ جديد في هذه الحلقة'), findsOneWidget);
      expect(find.text('المقطع'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
