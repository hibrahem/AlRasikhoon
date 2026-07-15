import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_screen.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

/// The live recitation timer was moved OUT of the app bar into the content-card
/// header (al_rasikhoon-8z6). It must still tick and reflect elapsed time, but
/// it must no longer live inside the `AppBar`. This proves both: the timer
/// renders in the body and is absent from the app bar.
void main() {
  const lesson = SessionModel(
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final meeting = PacedSession(
      sessions: const [lesson],
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

    final container = ProviderContainer(
      overrides: [
        studentCurrentMeetingProvider(
          's1',
        ).overrideWith((ref) async => meeting),
        // Keep the pace lookup off the real repository — the timer only needs a
        // pace multiplier, and a null student falls back to the default pace.
        studentProvider('s1').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    // Seed an active session so the live timer has a start instant to tick
    // from — without one it collapses to an empty box and there is nothing to
    // place.
    container
        .read(activeSessionProvider.notifier)
        .seedForTest(
          ActiveSessionState(studentId: 's1', startedAt: DateTime.now()),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RecitationScreen(studentId: 's1', part: 1),
          ),
        ),
      ),
    );
    // Single-pump (not pumpAndSettle) so the SessionTimer's periodic ticker
    // doesn't keep the tree busy; two pumps let the async meeting override
    // resolve to a frame that renders the content card + timer.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the live timer renders in the body, not the app bar', (
    tester,
  ) async {
    await pump(tester);

    // The timer is present…
    expect(find.byType(SessionTimer), findsOneWidget);

    // …but no longer inside the AppBar.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(SessionTimer),
      ),
      findsNothing,
    );

    // …and it lives in the content card's header, next to the part badge.
    expect(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(SessionTimer),
      ),
      findsOneWidget,
    );

    // Dispose the tree so the timer's periodic ticker is cancelled and the
    // test binding doesn't flag a still-pending Timer.
    await tester.pumpWidget(const SizedBox());
  });
}
