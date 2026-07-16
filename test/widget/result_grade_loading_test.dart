import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_result_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/sard_result_screen.dart';

/// Successor to the hibrahem/AlRasikhoon#36 loading-state test.
///
/// #36 guarded against a level-based grade being computed from a default
/// level=1 while the student was still loading. Assessments are no longer
/// graded on the level-based راسخ..محب scale at all: the curriculum's سرد and
/// اختبار sheets judge the four error types against fixed per-face /
/// per-question allowances that are identical across all ten levels, so the
/// binary verdict (موفق / غير موفق) is final the moment the screen opens.
///
/// What this now pins:
/// 1. A lesson-scale grade name NEVER renders on an assessment result screen —
///    loading or loaded.
/// 2. The verdict does NOT wait for the student to resolve: it is shown even
///    while the student future is still pending.
const _lessonGradeNames = ['راسخ', 'متقن', 'حافظ', 'مجتهد', 'محب'];

void _expectVerdictWithoutLessonGrades(WidgetTester tester, String verdict) {
  expect(find.text(verdict), findsOneWidget);
  for (final name in _lessonGradeNames) {
    expect(
      find.text(name),
      findsNothing,
      reason:
          'lesson grade "$name" must never render on an assessment result — '
          'assessments are موفق/غير موفق only',
    );
  }
}

void main() {
  group('Assessment result screens show the sheet verdict, never a lesson '
      'grade', () {
    testWidgets('SardResultScreen shows موفق immediately, even while the '
        'student is still loading', (tester) async {
      // A never-completing future keeps the provider in the loading state.
      final pending = Completer<StudentWithUser?>();
      addTearDown(() => pending.complete(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // SardResultScreen resolves its student through the teacher-scoped
            // studentProvider (سرد is teacher-conducted, al_rasikhoon-801).
            studentProvider.overrideWith((ref, id) => pending.future),
          ],
          child: const MaterialApp(
            home: SardResultScreen(
              studentId: 'student1',
              // Every face within its allowance — موفق regardless of level.
              faces: [RecitationErrorTally(tanbeehat: 3)],
            ),
          ),
        ),
      );
      // Do NOT pumpAndSettle — that would wait for the future forever.
      await tester.pump();

      _expectVerdictWithoutLessonGrades(tester, 'موفق');
    });

    testWidgets('ExamResultScreen shows غير موفق immediately, even while the '
        'student is still loading', (tester) async {
      final pending = Completer<StudentWithUser?>();
      addTearDown(() => pending.complete(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examStudentProvider.overrideWith((ref, id) => pending.future),
          ],
          child: const MaterialApp(
            home: ExamResultScreen(
              studentId: 'student1',
              // One question past its تجويد allowance (5) — غير موفق, and no
              // level can change that.
              questions: [
                RecitationErrorTally(tajweed: 6),
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
                RecitationErrorTally.empty,
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      _expectVerdictWithoutLessonGrades(tester, 'غير موفق');
    });
  });
}
