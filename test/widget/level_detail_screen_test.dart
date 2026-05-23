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
      totalSessions: 0,
      hizbCount: 6,
      order: n,
    );

SessionModel _session({
  required String id,
  required int sessionNumber,
  required int hizbNumber,
  SessionType type = SessionType.regular,
  QuranContent? current,
}) {
  return SessionModel(
    id: id,
    sessionNumber: sessionNumber,
    levelId: 1,
    juzNumber: 30,
    hizbNumber: hizbNumber,
    sessionType: type,
    currentLevelContent: current ??
        const QuranContent(
          fromSurah: 'الفاتحة',
          fromVerse: 1,
          toSurah: 'الفاتحة',
          toVerse: 7,
        ),
    recentReviewContent: QuranContent.fromJson(null),
    distantReviewContent: QuranContent.fromJson(null),
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
        levelSessionsProvider(levelNumber)
            .overrideWith((ref) async => sessions),
      ],
      child: MaterialApp(
        home: LevelDetailScreen(levelNumber: levelNumber),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LevelDetailScreen (#23)', () {
    testWidgets('renders the level\'s sessions with their details',
        (tester) async {
      await _pump(
        tester,
        levelNumber: 1,
        level: _level(1),
        sessions: [
          _session(id: 's1', sessionNumber: 1, hizbNumber: 59),
          _session(
            id: 's2',
            sessionNumber: 35,
            hizbNumber: 59,
            type: SessionType.sard,
          ),
        ],
      );

      // Regular session title + a sard session title both render.
      expect(find.text('الحلقة 1 - الحزب 59'), findsOneWidget);
      expect(find.text('سرد الحزب 59'), findsOneWidget);
      // Session-type chip for the sard session.
      expect(find.text('سرد'), findsOneWidget);
      // Content range from the curriculum model surfaces.
      expect(find.textContaining('الفاتحة'), findsWidgets);
    });

    testWidgets('shows a graceful empty state for a level with no sessions',
        (tester) async {
      await _pump(
        tester,
        levelNumber: 7,
        level: _level(7),
        sessions: const [],
      );

      expect(find.text('لا توجد حلقات لهذا المستوى'), findsOneWidget);
      expect(find.textContaining('المستوى 7'), findsWidgets);
    });

    for (final n in [1, 5, 10]) {
      testWidgets('level $n opens its own sessions view (levelNumber wiring)',
          (tester) async {
        await _pump(
          tester,
          levelNumber: n,
          level: _level(n),
          sessions: [
            _session(id: 'l${n}s1', sessionNumber: 1, hizbNumber: 59),
          ],
        );
        // The AppBar shows the level's own name (per-level wiring).
        expect(find.text('المستوى $n'), findsWidgets);
        // The session for this level renders.
        expect(find.text('الحلقة 1 - الحزب 59'), findsOneWidget);
      });
    }
  });
}
