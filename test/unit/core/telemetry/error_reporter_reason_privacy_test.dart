import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the privacy rule for `ErrorReporter.recordError(reason: ...)`
/// call sites ADDED to close the swallowing-catch blind spot (production
/// observability task 10 — see
/// `.superpowers/sdd/2026-08-27-production-observability/uncovered-catch-sites.md`):
/// `reason` at these sites MUST be a fixed, hand-written string naming the
/// class and method — never a string interpolation of a model, a user's
/// name/username, or the exception's own text. `UserModel.toString()` in
/// this codebase embeds a username AND a real name, so an interpolated
/// `reason` (`'$user'`, `'${student.name}'`, `'reason: $e'`, ...) would leak
/// personal data into telemetry.
///
/// Scoped to this task's touched files rather than all of `lib/`: two
/// earlier, separately-reviewed call sites
/// (`shared/providers/telemetry_provider_observer.dart`'s `'provider $name
/// failed'` and `main.dart`'s `'flutter error in ${details.library}'`)
/// interpolate a closed-vocabulary Riverpod provider name / Flutter library
/// name, not user data — an intentional, already-accepted exception this
/// guard is not meant to relitigate.
const _touchedFiles = [
  'lib/data/repositories/auth_repository.dart',
  'lib/features/admin/screens/add_supervisor_screen.dart',
  'lib/features/admin/screens/add_teacher_screen.dart',
  'lib/features/admin/screens/create_institute_screen.dart',
  'lib/features/admin/screens/edit_institute_screen.dart',
  'lib/features/admin/screens/institute_detail_screen.dart',
  'lib/features/admin/screens/supervisor_detail_screen.dart',
  'lib/features/supervisor/screens/exam_result_screen.dart',
  'lib/features/supervisor/widgets/assign_teacher_dialog.dart',
  'lib/features/supervisor/widgets/reposition_starting_point_section.dart',
  'lib/features/teacher/providers/teacher_provider.dart',
  'lib/features/teacher/screens/sard_result_screen.dart',
  'lib/shared/widgets/edit_profile_dialog.dart',
  'lib/shared/widgets/student_status_dialog.dart',
];

void main() {
  test('every recordError(reason: ...) call site added by task 10 passes a '
      'closed, non-interpolated string literal', () {
    final offenders = <String>[];
    // Matches `reason: '...'` or `reason: "..."` starting a string
    // literal that contains an unescaped `$` — i.e. Dart interpolation.
    final reasonWithInterpolation = RegExp(
      r'''reason:\s*(['"])(?:(?!\1).)*\$''',
    );

    for (final path in _touchedFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        offenders.add('$path: MISSING — update this guard test\'s file list');
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (reasonWithInterpolation.hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'reason must be a fixed, hand-written string naming the class '
          'and method. It must never interpolate a model, a user\'s name '
          'or username, or the exception\'s own text (the reporter scrubs '
          'the exception separately). Offenders:\n${offenders.join('\n')}',
    );
  });
}
