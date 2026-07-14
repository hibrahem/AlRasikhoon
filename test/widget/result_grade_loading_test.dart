import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/screens/exam_result_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/sard_result_screen.dart';

/// Loading-state test for hibrahem/AlRasikhoon#36.
///
/// Result screens must NOT render a grade computed from a default level=1 while
/// the student async value is still loading — that flashes a harsher grade to a
/// higher-level student. While loading, a placeholder (spinner) shows in place
/// of the GradeDisplay, and no grade name appears.
///
/// Each known grade name (راسخ / متقن / حافظ / مجتهد / محب) must be absent in the
/// loading state — they only render once the real level resolves.
const _gradeNames = ['راسخ', 'متقن', 'حافظ', 'مجتهد', 'محب'];

void _expectNoGradeWhileLoading(WidgetTester tester) {
  // Spinner placeholder shows in place of the grade.
  expect(find.byType(CircularProgressIndicator), findsWidgets);
  // No grade name leaks while the level is still loading.
  for (final name in _gradeNames) {
    expect(
      find.text(name),
      findsNothing,
      reason: 'grade "$name" must not render before the level resolves (#36)',
    );
  }
}

void main() {
  group('Result screens withhold grade while student loads (#36)', () {
    testWidgets(
      'SardResultScreen shows a placeholder, not a grade, while loading',
      (tester) async {
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
              home: SardResultScreen(studentId: 'student1', errorCount: 3),
            ),
          ),
        );
        // Do NOT pumpAndSettle — that would wait for the future forever.
        await tester.pump();

        _expectNoGradeWhileLoading(tester);
      },
    );

    testWidgets(
      'ExamResultScreen shows a placeholder, not a grade, while loading',
      (tester) async {
        final pending = Completer<StudentWithUser?>();
        addTearDown(() => pending.complete(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              examStudentProvider.overrideWith((ref, id) => pending.future),
            ],
            child: const MaterialApp(
              home: ExamResultScreen(studentId: 'student1', errorCount: 3),
            ),
          ),
        );
        await tester.pump();

        _expectNoGradeWhileLoading(tester);
      },
    );
  });
}
