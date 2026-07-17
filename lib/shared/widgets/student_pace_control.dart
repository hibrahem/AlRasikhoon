import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/meetings_per_week.dart';
import 'app_card.dart';

/// The "خطة الحفظ" card — the two dials a teacher or supervisor sets for a
/// student: the pace (how many curriculum lessons one meeting covers, 1×..10×,
/// a slider — ten detents, not ten buttons) and the weekly cadence (how many
/// meetings a week, a stepper). A تلقين, a سرد and an اختبار each always stand
/// alone, whatever the pace.
///
/// Both are student config set OUTSIDE any session: the student stores where a
/// meeting starts, and its extent is composed from the pace at read time, so a
/// change takes effect on the very next meeting. The cadence schedules nothing
/// — it only feeds the completion forecast (متى الختم؟).
///
/// A small control, not a workflow. This widget owns the common behaviour (the
/// writes, the failure snackbar, the optimistic value that reverts on failure)
/// and stays free of any host's provider graph: on a SUCCESSFUL change it
/// invokes [onPlanChanged] so each host refreshes exactly its own providers —
/// the teacher screen and each supervisor surface invalidate different caches.
class StudentPaceControl extends ConsumerStatefulWidget {
  final String studentId;
  final CurriculumPace currentPace;
  final MeetingsPerWeek currentMeetingsPerWeek;

  /// Fired ONLY after a successful write (of either dial), so the host can
  /// invalidate its own providers. Receives the widget's own [WidgetRef] so a
  /// host injected far from a build context (e.g. by the router) can still
  /// invalidate. Not called on failure — the widget shows the snackbar itself
  /// and the stored plan is unchanged.
  final void Function(WidgetRef ref) onPlanChanged;

  const StudentPaceControl({
    super.key,
    required this.studentId,
    required this.currentPace,
    required this.currentMeetingsPerWeek,
    required this.onPlanChanged,
  });

  @override
  ConsumerState<StudentPaceControl> createState() => _StudentPaceControlState();
}

class _StudentPaceControlState extends ConsumerState<StudentPaceControl> {
  // Optimistic values: the slider moves the moment the finger does, the write
  // lands on release, and a failed write snaps back to the last value known to
  // be stored. Tracked HERE, not read off widget.currentPace, because a host
  // may hand this widget a captured student object (the supervisor's dialog
  // does) that never rebuilds after a successful write.
  late int _pace = widget.currentPace.multiplier;
  late int _meetingsPerWeek = widget.currentMeetingsPerWeek.count;
  late int _storedPace = widget.currentPace.multiplier;
  late int _storedMeetingsPerWeek = widget.currentMeetingsPerWeek.count;

  @override
  void didUpdateWidget(StudentPaceControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPace != widget.currentPace) {
      _pace = widget.currentPace.multiplier;
      _storedPace = widget.currentPace.multiplier;
    }
    if (oldWidget.currentMeetingsPerWeek != widget.currentMeetingsPerWeek) {
      _meetingsPerWeek = widget.currentMeetingsPerWeek.count;
      _storedMeetingsPerWeek = widget.currentMeetingsPerWeek.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('خطة الحفظ', style: textTheme.titleMedium),
          const SizedBox(height: 12),

          // --- Pace: a slider with ten detents and a value badge -----------
          Row(
            children: [
              Expanded(child: Text('وتيرة الحفظ', style: textTheme.bodyMedium)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tokens.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_pace×',
                  style: textTheme.titleMedium?.copyWith(
                    color: tokens.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _pace.toDouble(),
            min: 1,
            max: CurriculumPace.maxMultiplier.toDouble(),
            divisions: CurriculumPace.maxMultiplier - 1,
            label: '$_pace×',
            onChanged: (value) => setState(() => _pace = value.round()),
            onChangeEnd: (value) => _setPace(value.round()),
          ),
          Text(
            'عدد الحلقات في اللقاء الواحد',
            style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),

          const SizedBox(height: 16),

          // --- Cadence: a stepper, 1..7 -------------------------------------
          Row(
            children: [
              Expanded(
                child: Text('اللقاءات في الأسبوع', style: textTheme.bodyMedium),
              ),
              IconButton(
                onPressed: _meetingsPerWeek > 1
                    ? () => _setMeetingsPerWeek(_meetingsPerWeek - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'لقاء أقل',
              ),
              Text(
                '$_meetingsPerWeek',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: _meetingsPerWeek < MeetingsPerWeek.maxPerWeek
                    ? () => _setMeetingsPerWeek(_meetingsPerWeek + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'لقاء أكثر',
              ),
            ],
          ),
          Text(
            'كم لقاءً يحضره الطالب في الأسبوع',
            style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }

  Future<void> _setPace(int multiplier) async {
    if (multiplier == _storedPace) return;
    try {
      await ref
          .read(studentRepositoryProvider)
          .setStudentPace(widget.studentId, CurriculumPace(multiplier));
    } catch (_) {
      if (mounted) {
        setState(() => _pace = _storedPace);
        _showWriteFailure('تعذر تحديث وتيرة الحفظ');
      }
      return;
    }

    _storedPace = multiplier;
    widget.onPlanChanged(ref);
  }

  Future<void> _setMeetingsPerWeek(int count) async {
    setState(() => _meetingsPerWeek = count);
    try {
      await ref
          .read(studentRepositoryProvider)
          .setStudentMeetingsPerWeek(widget.studentId, MeetingsPerWeek(count));
    } catch (_) {
      if (mounted) {
        setState(() => _meetingsPerWeek = _storedMeetingsPerWeek);
        _showWriteFailure('تعذر تحديث عدد اللقاءات');
      }
      return;
    }

    _storedMeetingsPerWeek = count;
    widget.onPlanChanged(ref);
  }

  void _showWriteFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.tokens.maroon),
    );
  }
}
