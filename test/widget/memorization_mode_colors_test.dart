import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/theme/app_tokens.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/recitation_parts.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_screen.dart';
import 'package:al_rasikhoon/shared/widgets/hero_header.dart';

/// Distinct-ink-per-memorization-part tests for hibrahem/AlRasikhoon#25
/// (revisited: the part inks are now theme tokens — the green/ochre/lapis
/// illumination triad — instead of raw AppColors constants).
///
/// Each of the three parts — الجديد (1), القريب (2), البعيد (3) — must carry
/// its own distinct, named ink, applied consistently. These tests assert:
///   1. the token map (AppTokens.forPart) returns the right ink,
///   2. the three inks are distinct — in BOTH brightnesses,
///   3. the RecitationScreen hero wears a distinct color per part,
///   4. the Arabic part label AND the per-part icon are still shown
///      (color is never the only signal).

QuranContent _content() => const QuranContent(
  fromSurah: 'البقرة',
  fromVerse: 1,
  toSurah: 'البقرة',
  toVerse: 5,
);

SessionModel _session() => SessionModel(
  id: 'L1_J30_S1',
  sessionNumber: 1,
  levelId: 1,
  juzNumber: 30,
  orderInLevel: 1,
  hizbNumber: 59,
  kind: SessionKind.lesson,
  currentLevelContent: _content(),
  recentReviewContent: _content(),
  distantReviewContent: _content(),
);

Future<void> _pumpRecitation(WidgetTester tester, int part) async {
  // Give the surface enough height; the recitation body uses Spacer + fixed
  // sections that overflow the default 600px test viewport (unrelated to #25).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // The session stands alone (not batched), so its meeting is a
  // single-session `PacedSession` built from the same row — the screen now
  // reads the MEETING, not the session directly.
  final session = _session();
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentCurrentMeetingProvider(
          'student1',
        ).overrideWith((ref) async => meeting),
      ],
      child: MaterialApp(
        home: RecitationScreen(studentId: 'student1', part: part),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('memorization part inks (#25)', () {
    test('forPart maps each part to its named ink', () {
      for (final tokens in [AppTokens.light, AppTokens.dark]) {
        expect(tokens.forPart(1), tokens.partNew);
        expect(tokens.forPart(2), tokens.partNear);
        expect(tokens.forPart(3), tokens.partFar);
      }
    });

    test('unknown parts fall back to green', () {
      expect(AppTokens.light.forPart(0), AppTokens.light.green);
      expect(AppTokens.light.forPart(99), AppTokens.light.green);
    });

    test('the three inks are distinct in both brightnesses', () {
      for (final tokens in [AppTokens.light, AppTokens.dark]) {
        final inks = <Color>{tokens.partNew, tokens.partNear, tokens.partFar};
        expect(inks.length, 3);
      }
    });
  });

  group('RecitationScreen wears the part ink (#25)', () {
    final labels = <int, String>{
      1: 'الحفظ الجديد',
      2: 'المراجعة القريبة',
      3: 'المراجعة البعيدة',
    };

    testWidgets('each part hero has its own distinct color', (tester) async {
      final heroColors = <int, Color>{};
      for (final part in labels.keys) {
        await _pumpRecitation(tester, part);
        final hero = tester.widget<HeroHeader>(find.byType(HeroHeader));
        expect(
          hero.topColor,
          isNotNull,
          reason: 'part $part hero must override the brand gradient',
        );
        heroColors[part] = hero.topColor!;
      }
      expect(
        heroColors.values.toSet().length,
        3,
        reason: 'the three part heroes must be visually distinct',
      );
    });

    for (final entry in labels.entries) {
      final part = entry.key;
      final expectedLabel = entry.value;

      testWidgets('part $part keeps the Arabic label and the per-part icon '
          '(color is never the only signal)', (tester) async {
        await _pumpRecitation(tester, part);

        expect(find.text(expectedLabel), findsWidgets);
        expect(find.byIcon(recitationPartIcon(part)), findsWidgets);
      });
    }
  });
}
