import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

/// The session-detail overall block must be a BINARY pass/fail (issue #24):
/// the session fails only if ANY single part grades محب. It must NOT combine
/// the parts into one grade tier, and must NOT show a summed error "score" —
/// each part's own grade and error count is shown, alone, in the part cards.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<void> pump(WidgetTester tester, SessionRecordModel record) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            record.id,
          ).overrideWith((ref) async => record),
          curriculumSessionByIdProvider(
            record.curriculumSessionId,
          ).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionDetailScreen(recordId: record.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SessionRecordModel lesson({
    required int newErrors,
    required int recentErrors,
    required int distantErrors,
  }) {
    return SessionRecordModel(
      id: 'r1',
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S5',
      levelId: 1,
      kind: SessionKind.lesson,
      juzNumber: 30,
      hizbNumber: 59,
      sessionNumber: 5,
      fromOrderInLevel: 5,
      toOrderInLevel: 5,
      coversSessionIds: const ['L1_J30_S5'],
      date: DateTime(2026, 7, 14),
      attemptNumber: 1,
      grades: SessionGrades(
        newMemorizationErrors: newErrors,
        recentReviewErrors: recentErrors,
        distantReviewErrors: distantErrors,
      ),
      passed: true,
      createdAt: DateTime(2026, 7, 14),
    );
  }

  testWidgets(
    'every part passing shows ناجح and never the summed total as one score',
    (tester) async {
      // Level 1: each part has 1 error → متقن (pass). The three parts sum to
      // 3 errors, which the OLD combined display collapsed into a single
      // grade + a "3 أخطاء" score. The overall must now be a binary ناجح, and
      // the summed "3 أخطاء" must never appear — only each part's own count.
      await pump(
        tester,
        lesson(newErrors: 1, recentErrors: 1, distantErrors: 1),
      );

      expect(find.text('ناجح'), findsOneWidget);
      expect(find.text('راسب'), findsNothing);

      // Each part shows its own error count, but the parts are never summed
      // into one overall score.
      expect(find.text('1 أخطاء'), findsNWidgets(3));
      expect(find.text('3 أخطاء'), findsNothing);
    },
  );

  testWidgets('the session fails (راسب) when any single part grades محب', (
    tester,
  ) async {
    // Level 1: part 1 has 4 errors → محب (fail). The other two parts pass, but
    // a single محب fails the whole session — no averaging can mask it.
    await pump(
      tester,
      lesson(newErrors: 4, recentErrors: 0, distantErrors: 0),
    );

    expect(find.text('راسب'), findsOneWidget);
    expect(find.text('ناجح'), findsNothing);
  });
}
