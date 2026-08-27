import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the privacy rule for `ErrorReporter.recordError(reason: ...)`
/// call sites ADDED to close the swallowing-catch blind spot (production
/// observability task 10 — see
/// `.superpowers/sdd/2026-08-27-production-observability/uncovered-catch-sites.md`):
/// `reason` at these sites MUST be a fixed, hand-written string naming the
/// class and method — never a string interpolation of a model, a user's
/// name/username, or the exception's own text — for example
/// `'reason: $e'`, or interpolating a field directly, e.g. `'user:
/// ${user.name}'`. This guard bans interpolation outright rather than
/// trusting any given model's `toString()` to stay non-identifying:
/// `UserModel.toString()` is hardened to carry only its id and role (see
/// its own comment), but a call site could still interpolate a raw field
/// straight out of the model, bypassing `toString()` entirely.
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

/// Matches a closed `reason: '...'` / `reason: "..."` string literal once
/// whitespace has been normalised (see [findInterpolatedReasonLiterals]).
/// Captures the quote char in group 1 and the literal's body in group 2.
final _reasonLiteral = RegExp(r'''reason:\s*(['"])((?:(?!\1).)*)\1''');

/// Scans [source] for `reason: '...'` call-argument literals that contain
/// Dart string interpolation (an unescaped `$`), and returns each offending
/// `reason: '...'` snippet found.
///
/// `dart format` wraps a long `recordError(..., reason: '...')` call so the
/// literal lands on its own line, e.g.:
///
/// ```dart
/// reason:
///     'ActiveSessionNotifier.completeSession batch commit failed',
/// ```
///
/// A line-by-line scan never sees `reason:` and the opening quote on the
/// same line in that shape, so it would silently miss a violation written
/// the same way — exactly the sites (the batch-commit save handlers) where
/// a leak matters most. Collapsing all whitespace runs (including the
/// newline) to a single space before matching makes the check indifferent
/// to how the call happens to be wrapped.
List<String> findInterpolatedReasonLiterals(String source) {
  final normalized = source.replaceAll(RegExp(r'\s+'), ' ');
  return [
    for (final match in _reasonLiteral.allMatches(normalized))
      if (match.group(2)!.contains(r'$')) match.group(0)!,
  ];
}

void main() {
  test('flags an interpolated reason literal even when dart format wraps it '
      'onto its own line', () {
    // Mirrors the exact shape dart format produces at the batch-commit
    // sites in teacher_provider.dart, but with the interpolation the
    // reviewer's finding warned this guard must not miss.
    const wrappedInterpolated = '''
      ref
          .read(errorReporterProvider)
          .recordError(
            e,
            stackTrace,
            reason:
                'ActiveSessionNotifier.completeSession failed for \$user',
          );
      ''';

    final offenders = findInterpolatedReasonLiterals(wrappedInterpolated);

    expect(offenders, isNotEmpty);
    expect(offenders.single, contains(r'$user'));
  });

  test('does not flag a static reason literal wrapped onto its own line', () {
    // The real, currently-correct shape at
    // teacher_provider.dart:470-471 — a static literal that dart format
    // still wrapped across two lines. Must NOT be flagged.
    const wrappedStatic = '''
      ref
          .read(errorReporterProvider)
          .recordError(
            e,
            s,
            reason:
                'ActiveSessionNotifier.completeSession batch commit failed',
          );
      ''';

    expect(findInterpolatedReasonLiterals(wrappedStatic), isEmpty);
  });

  test('every recordError(reason: ...) call site added by task 10 passes a '
      'closed, non-interpolated string literal, regardless of how dart '
      'format wrapped the call', () {
    final offenders = <String>[];

    for (final path in _touchedFiles) {
      final file = File(path);
      if (!file.existsSync()) {
        offenders.add('$path: MISSING — update this guard test\'s file list');
        continue;
      }
      for (final literal in findInterpolatedReasonLiterals(
        file.readAsStringSync(),
      )) {
        offenders.add('$path: $literal');
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
