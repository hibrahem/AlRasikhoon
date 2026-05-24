import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/constants/app_colors.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/recitation_screen.dart';

/// Distinct-color-per-memorization-mode tests for hibrahem/AlRasikhoon#25.
///
/// Each of the three modes — الجديد (new, part 1), القريب (near, part 2),
/// البعيد (far, part 3) — must use its own distinct, named theme token, applied
/// consistently. These tests assert:
///   1. the token map (AppColors.forMemorizationPart) returns the right token,
///   2. the three tokens are actually distinct,
///   3. the RecitationScreen app bar adopts the mode's token color per part,
///   4. the Arabic mode label is still shown (color is never the only signal).

QuranContent _content() => const QuranContent(
      fromSurah: 'البقرة',
      fromVerse: 1,
      toSurah: 'البقرة',
      toVerse: 5,
    );

SessionModel _session() => SessionModel(
      id: 's1',
      sessionNumber: 1,
      levelId: 1,
      juzNumber: 1,
      hizbNumber: 1,
      sessionType: SessionType.regular,
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentCurrentSessionProvider('student1')
            .overrideWith((ref) async => _session()),
      ],
      child: MaterialApp(
        home: RecitationScreen(studentId: 'student1', part: part),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('memorization mode tokens (#25)', () {
    test('forMemorizationPart maps each part to its named token', () {
      expect(AppColors.forMemorizationPart(1), AppColors.kNewColor);
      expect(AppColors.forMemorizationPart(2), AppColors.kNearColor);
      expect(AppColors.forMemorizationPart(3), AppColors.kFarColor);
    });

    test('unknown parts fall back to primary', () {
      expect(AppColors.forMemorizationPart(0), AppColors.primary);
      expect(AppColors.forMemorizationPart(99), AppColors.primary);
    });

    test('the three mode tokens are distinct', () {
      final tokens = <Color>{
        AppColors.kNewColor,
        AppColors.kNearColor,
        AppColors.kFarColor,
      };
      expect(tokens.length, 3);
    });
  });

  group('RecitationScreen applies the mode accent (#25)', () {
    final cases = <int, (Color, String)>{
      1: (AppColors.kNewColor, 'الحفظ الجديد'),
      2: (AppColors.kNearColor, 'المراجعة القريبة'),
      3: (AppColors.kFarColor, 'المراجعة البعيدة'),
    };

    for (final entry in cases.entries) {
      final part = entry.key;
      final expectedColor = entry.value.$1;
      final expectedLabel = entry.value.$2;

      testWidgets('part $part app bar uses its token + keeps the Arabic label',
          (tester) async {
        await _pumpRecitation(tester, part);

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, expectedColor);

        // Color is never the only signal — the Arabic mode label is present.
        expect(find.text(expectedLabel), findsWidgets);
      });
    }
  });
}
