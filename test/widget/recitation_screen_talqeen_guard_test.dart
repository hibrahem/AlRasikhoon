import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';

/// RecitationScreen is the GRADED lesson-recitation flow. It has no in-app
/// entry point for a تلقين (session_overview_screen.dart branches on
/// isTalqeen before ever rendering the "بدء الحلقة" button that leads here),
/// but on Flutter web a teacher who started a تلقين could hand-edit the URL
/// straight to this screen. A تلقين must never be graded, failed, or
/// attempt-limited, so this screen must refuse to run for one — mirroring
/// the guard in talqeen_session_screen.dart.
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

  const lessonSession = SessionModel(
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

  Future<void> pump(WidgetTester tester, SessionModel session) async {
    // Give the surface enough height; the recitation body uses Spacer +
    // fixed sections that overflow the default 600px test viewport
    // (unrelated pre-existing issue, see memorization_mode_colors_test.dart).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCurrentSessionProvider(
            's1',
          ).overrideWith((ref) async => session),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecitationScreen(studentId: 's1', part: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'refuses to run the grading flow for a student standing on a تلقين',
    (tester) async {
      await pump(tester, talqeenSession);

      expect(find.text('لا توجد بيانات للتسميع'), findsOneWidget);
      // No error counter, no content card, no recitation controls.
      expect(find.textContaining('النبأ'), findsNothing);
    },
  );

  testWidgets('runs normally for a student standing on a lesson', (
    tester,
  ) async {
    await pump(tester, lessonSession);

    expect(find.text('لا توجد بيانات للتسميع'), findsNothing);
    expect(find.textContaining('النبأ'), findsOneWidget);
  });
}
