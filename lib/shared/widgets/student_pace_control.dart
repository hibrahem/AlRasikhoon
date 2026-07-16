import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import 'app_card.dart';

/// The "وتيرة الحفظ" control — how many curriculum lessons a student covers in
/// one meeting (a تلقين, a سرد and an اختبار each always stand alone, whatever
/// the pace). Pace is student config set OUTSIDE any session: the student
/// stores where a meeting starts, and its extent is composed from this pace at
/// read time, so a change takes effect on the very next meeting.
///
/// A small control, not a workflow — either a teacher or a supervisor may set
/// it directly and it may change mid-level (see [CurriculumPace]). This widget
/// owns the common behaviour (the write, the failure snackbar) and stays free
/// of any host's provider graph: on a SUCCESSFUL change it invokes
/// [onPaceChanged] so each host refreshes exactly its own providers — the
/// teacher screen and each supervisor surface invalidate different caches.
class StudentPaceControl extends ConsumerWidget {
  final String studentId;
  final CurriculumPace currentPace;

  /// Fired ONLY after a successful write, so the host can invalidate its own
  /// providers. Receives the widget's own [WidgetRef] so a host injected far
  /// from a build context (e.g. by the router) can still invalidate. Not called
  /// on failure — the widget shows the snackbar itself and the pace is unchanged.
  final void Function(WidgetRef ref) onPaceChanged;

  const StudentPaceControl({
    super.key,
    required this.studentId,
    required this.currentPace,
    required this.onPaceChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('وتيرة الحفظ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1x')),
              ButtonSegment(value: 2, label: Text('2x')),
              ButtonSegment(value: 3, label: Text('3x')),
            ],
            // A student who has never had a pace set is a standard-pace (1x)
            // student — `CurriculumPace.fromJson` already treats absence that
            // way, so the control shows the same default.
            selected: {currentPace.multiplier},
            onSelectionChanged: (selected) =>
                _setPace(context, ref, selected.first),
          ),
          const SizedBox(height: 8),
          Text(
            'عدد الحلقات في اللقاء الواحد',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }

  Future<void> _setPace(
    BuildContext context,
    WidgetRef ref,
    int multiplier,
  ) async {
    try {
      await ref
          .read(studentRepositoryProvider)
          .setStudentPace(studentId, CurriculumPace(multiplier));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر تحديث وتيرة الحفظ'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
      return;
    }

    onPaceChanged(ref);
  }
}
