import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/level_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/features/admin/screens/level_detail_screen.dart';

/// Widget tests for the admin per-level details (sessions) view —
/// hibrahem/AlRasikhoon#23. Read-only; reuses the existing LevelModel /
/// SessionModel domain via levelProvider + levelSessionsProvider.

LevelModel _level(int n) => LevelModel(
  id: 'level_$n',
  levelNumber: n,
  nameAr: 'المستوى $n',
  nameEn: 'Level $n',
  juzNumbers: [30],
  sessionCount: 68,
  order: n,
);

/// A lesson, as the curriculum states it. Its kind is DATA — a session numbered
/// 35 is an ordinary lesson unless the curriculum says otherwise.
SessionModel _lesson({
  required String id,
  required int sessionNumber,
  required int hizbNumber,
  QuranContent? current,
}) {
  return SessionModel(
    id: id,
    sessionNumber: sessionNumber,
    levelId: 1,
    juzNumber: 30,
    orderInLevel: sessionNumber,
    hizbNumber: hizbNumber,
    kind: SessionKind.lesson,
    currentLevelContent:
        current ??
        const QuranContent(
          fromSurah: 'الفاتحة',
          fromVerse: 1,
          toSurah: 'الفاتحة',
          toVerse: 7,
        ),
  );
}

/// A سرد, carrying the source's own verbatim Arabic label.
SessionModel _sard({
  required String id,
  required int sessionNumber,
  required AssessmentTier tier,
  required String labelAr,
  int? hizbNumber,
  List<int> juzNumbers = const [30],
}) {
  return SessionModel(
    id: id,
    sessionNumber: sessionNumber,
    levelId: 1,
    juzNumber: 30,
    orderInLevel: sessionNumber,
    hizbNumber: hizbNumber,
    kind: SessionKind.sard,
    assessedBy: AssessedBy.teacher,
    scope: SessionScope(
      tier: tier,
      labelAr: labelAr,
      hizbNumber: hizbNumber,
      juzNumbers: juzNumbers,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required int levelNumber,
  required List<SessionModel> sessions,
  LevelModel? level,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        levelProvider(levelNumber).overrideWith((ref) async => level),
        levelSessionsProvider(
          levelNumber,
        ).overrideWith((ref) async => sessions),
      ],
      child: MaterialApp(home: LevelDetailScreen(levelNumber: levelNumber)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LevelDetailScreen (#23)', () {
    testWidgets('renders the level\'s sessions with their details', (
      tester,
    ) async {
      await _pump(
        tester,
        levelNumber: 1,
        level: _level(1),
        sessions: [
          _lesson(id: 'L1_J30_S1', sessionNumber: 1, hizbNumber: 59),
          _sard(
            id: 'L1_J30_S67',
            sessionNumber: 67,
            tier: AssessmentTier.juz,
            labelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
          ),
        ],
      );

      // A lesson's title, and the سرد's title — which is the source's own
      // verbatim wording, not a hand-built 'سرد الحزب N' (this سرد covers a
      // whole juz and has no hizb at all).
      expect(find.text('الحلقة 1 - الجزء 30'), findsOneWidget);
      expect(
        find.text('سرد الجزء رقم 30 كاملًا على المحفظ المتابع'),
        findsOneWidget,
      );
      // The kind chip for the سرد — read from `kind`, never from the number.
      expect(find.text('سرد'), findsOneWidget);
      // Content range from the curriculum model surfaces.
      expect(find.textContaining('الفاتحة'), findsWidgets);
    });

    testWidgets(
      'a session numbered 35 is listed as the LESSON the data says it is',
      (tester) async {
        await _pump(
          tester,
          levelNumber: 1,
          level: _level(1),
          sessions: [
            _lesson(id: 'L1_J30_S35', sessionNumber: 35, hizbNumber: 59),
          ],
        );

        expect(find.text('الحلقة 35 - الجزء 30'), findsOneWidget);
        expect(find.text('حلقة'), findsOneWidget);
        expect(find.text('سرد'), findsNothing);
        expect(find.text('اختبار'), findsNothing);
      },
    );

    testWidgets('a cumulative سرد is named for the juz it covers', (
      tester,
    ) async {
      await _pump(
        tester,
        levelNumber: 1,
        level: _level(1),
        sessions: [
          _sard(
            id: 'L1_J28_S66',
            sessionNumber: 66,
            tier: AssessmentTier.cumulative,
            labelAr:
                'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
            juzNumbers: const [28, 29, 30],
          ),
        ],
      );

      expect(
        find.text(
          'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a graceful empty state for a level with no sessions', (
      tester,
    ) async {
      await _pump(tester, levelNumber: 7, level: _level(7), sessions: const []);

      expect(find.text('لا توجد حلقات لهذا المستوى'), findsOneWidget);
      expect(find.textContaining('المستوى 7'), findsWidgets);
    });

    for (final n in [1, 5, 10]) {
      testWidgets('level $n opens its own sessions view (levelNumber wiring)', (
        tester,
      ) async {
        await _pump(
          tester,
          levelNumber: n,
          level: _level(n),
          sessions: [_lesson(id: 'l${n}s1', sessionNumber: 1, hizbNumber: 59)],
        );
        // The AppBar shows the level's own name (per-level wiring).
        expect(find.text('المستوى $n'), findsWidgets);
        // The session for this level renders.
        expect(find.text('الحلقة 1 - الجزء 30'), findsOneWidget);
      });
    }
  });
}
