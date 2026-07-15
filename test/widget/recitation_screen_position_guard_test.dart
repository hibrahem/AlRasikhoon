import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';

/// RecitationScreen derives the "الجزء X من N" badge and the final-part
/// button label from the meeting's presentParts. In-app navigation only ever
/// targets present parts, but a hand-edited URL (Flutter web) can land on a
/// part that is absent — e.g. part 2/3 on a review-only lesson that carries no
/// recent/distant review. This mirrors the guard once held by the (now
/// removed) recitation_result_screen.dart: fall back to the raw part number
/// instead of rendering "الجزء 0 من N", and never label such a part as the
/// last one ("إنهاء التسميع").
void main() {
  // A review-only lesson: new content only, so presentParts == [1].
  const reviewOnlyLesson = SessionModel(
    id: 'L1_J30_S2',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 2,
    orderInLevel: 2,
    kind: SessionKind.lesson,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 12,
      toSurah: 'النبأ',
      toVerse: 20,
    ),
  );

  Future<void> pump(WidgetTester tester, int part) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final meeting = PacedSession(
      sessions: const [reviewOnlyLesson],
      newContent: const [
        QuranContent(
          fromSurah: 'النبأ',
          fromVerse: 12,
          toSurah: 'النبأ',
          toVerse: 20,
        ),
      ],
      recentReview: const [],
      distantReview: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecitationScreen(studentId: 's1', part: part),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a part not in presentParts never renders "الجزء 0 من N" nor "إنهاء التسميع"',
    (tester) async {
      // presentParts == [1]; part 2 is absent (URL-only landing).
      await pump(tester, 2);

      // Falls back to the raw part number, not the 0 from indexOf(-1)+1.
      expect(find.text('الجزء 0 من 1'), findsNothing);
      expect(find.text('الجزء 2 من 1'), findsOneWidget);

      // Not the last present part, so the action is "next", not "finish".
      expect(find.text('إنهاء التسميع'), findsNothing);
      expect(find.text('التالي'), findsOneWidget);
    },
  );

  testWidgets('the single present part is labelled part 1 and finishes', (
    tester,
  ) async {
    await pump(tester, 1);

    expect(find.text('الجزء 1 من 1'), findsOneWidget);
    expect(find.text('إنهاء التسميع'), findsOneWidget);
  });
}
