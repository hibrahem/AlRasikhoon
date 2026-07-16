import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  final recordModel = SessionRecordModel(
    id: 'r1',
    studentId: 'student1',
    teacherId: 'teacher1',
    curriculumSessionId: 'L1_J30_S5',
    levelId: 1,
    kind: SessionKind.lesson,
    juzNumber: 30,
    sessionNumber: 5,
    fromOrderInLevel: 5,
    toOrderInLevel: 5,
    coversSessionIds: const ['L1_J30_S5'],
    date: DateTime(2026, 7, 14),
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    presentParts: const [1, 2],
    passed: true,
    createdAt: DateTime(2026, 7, 14),
  );

  Future<void> pump(WidgetTester tester, SessionModel? session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            recordModel.id,
          ).overrideWith((ref) async => recordModel),
          curriculumSessionByIdProvider(
            recordModel.curriculumSessionId,
          ).overrideWith((ref) async => session),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionDetailScreen(recordId: recordModel.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SessionModel sessionWith({QuranContent? current, QuranContent? recent}) {
    return SessionModel(
      id: 'L1_J30_S5',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: 5,
      orderInLevel: 5,
      kind: SessionKind.lesson,
      currentLevelContent: current,
      recentReviewContent: recent,
    );
  }

  testWidgets('shows the ayah range for a part that has content', (
    tester,
  ) async {
    await pump(
      tester,
      sessionWith(
        current: const QuranContent(
          fromSurah: 'الإخلاص',
          fromVerse: 1,
          toSurah: 'الإخلاص',
          toVerse: 4,
        ),
      ),
    );
    expect(find.text('الإخلاص: 1 - 4'), findsOneWidget);
  });

  testWidgets('hides the range line for a part with no content', (
    tester,
  ) async {
    // Part 1 has content, part 2 does not — only the one range line appears.
    await pump(
      tester,
      sessionWith(
        current: const QuranContent(
          fromSurah: 'الإخلاص',
          fromVerse: 1,
          toSurah: 'الإخلاص',
          toVerse: 4,
        ),
        recent: null,
      ),
    );
    expect(find.text('الإخلاص: 1 - 4'), findsOneWidget);
    // No second surah/range rendered for the review part.
    expect(find.textContaining('المسد'), findsNothing);
  });

  testWidgets('renders parts without ranges when the session is unresolved', (
    tester,
  ) async {
    await pump(tester, null);
    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    // With no curriculum session resolved, no surah range is shown at all.
    expect(find.textContaining('الإخلاص'), findsNothing);
  });
}
