import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/curriculum/completion_forecast.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/meetings_per_week.dart';
import '../curriculum/forecast_copy.dart';
import '../providers/completion_forecast_provider.dart';
import 'app_card.dart';

/// The "خطة الحفظ" card — the two dials a teacher or supervisor sets for a
/// student, WITH the consequence rendered live underneath them: the pace (how
/// many curriculum lessons one meeting covers, a slider capped at
/// [CurriculumPace.maxUsefulMultiplier] — see there for why higher detents
/// would promise acceleration the curriculum cannot deliver) and the weekly
/// cadence (a stepper), followed by the completion forecast (متى الختم؟)
/// recomputed from the dials as they move. One card, dial-to-consequence:
/// dragging the slider shows the ختم date shift before the finger lifts.
///
/// Both dials are student config set OUTSIDE any session: the student stores
/// where a meeting starts, and its extent is composed from the pace at read
/// time, so a change takes effect on the very next meeting. The cadence
/// schedules nothing — it only feeds the forecast.
///
/// This widget owns the common behaviour (the writes, the failure snackbar,
/// the optimistic value that reverts on failure) and stays free of any host's
/// provider graph: on a SUCCESSFUL change it invokes [onPlanChanged] so each
/// host refreshes exactly its own providers.
///
/// Read-only surfaces (student dashboard, admin) show `CompletionForecastCard`
/// instead — same forecast, a what-if simulator in place of the dials.
class StudentPaceControl extends ConsumerStatefulWidget {
  final StudentModel student;

  /// Fired ONLY after a successful write (of either dial), so the host can
  /// invalidate its own providers. Receives the widget's own [WidgetRef] so a
  /// host injected far from a build context (e.g. by the router) can still
  /// invalidate. Not called on failure — the widget shows the snackbar itself
  /// and the stored plan is unchanged.
  final void Function(WidgetRef ref) onPlanChanged;

  const StudentPaceControl({
    super.key,
    required this.student,
    required this.onPlanChanged,
  });

  @override
  ConsumerState<StudentPaceControl> createState() => _StudentPaceControlState();
}

class _StudentPaceControlState extends ConsumerState<StudentPaceControl> {
  // Optimistic values: the slider moves the moment the finger does, the write
  // lands on release, and a failed write snaps back to the last value known to
  // be stored. Tracked HERE, not read off widget.student, because a host may
  // hand this widget a captured student object (the supervisor's dialog does)
  // that never rebuilds after a successful write. The forecast below the dials
  // is computed from THESE values, which is what makes it live.
  late int _pace = widget.student.pace.multiplier;
  late int _meetingsPerWeek = widget.student.meetingsPerWeek.count;
  late int _storedPace = widget.student.pace.multiplier;
  late int _storedMeetingsPerWeek = widget.student.meetingsPerWeek.count;

  @override
  void didUpdateWidget(StudentPaceControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.pace != widget.student.pace) {
      _pace = widget.student.pace.multiplier;
      _storedPace = widget.student.pace.multiplier;
    }
    if (oldWidget.student.meetingsPerWeek != widget.student.meetingsPerWeek) {
      _meetingsPerWeek = widget.student.meetingsPerWeek.count;
      _storedMeetingsPerWeek = widget.student.meetingsPerWeek.count;
    }
  }

  /// The slider's ceiling. A legacy value stored above the useful cap must
  /// still render (a Slider throws on value > max), so the range widens to
  /// hold it — but the UI never OFFERS more than the useful cap.
  int get _sliderMax => _pace > CurriculumPace.maxUsefulMultiplier
      ? _pace
      : CurriculumPace.maxUsefulMultiplier;

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

          // --- Pace: a slider with a value badge ---------------------------
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
            max: _sliderMax.toDouble(),
            divisions: _sliderMax - 1,
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

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          _forecast(context),
        ],
      ),
    );
  }

  /// متى الختم؟ — computed from the dials' CURRENT values, so it answers the
  /// question at the exact moment the supervisor is weighing it.
  Widget _forecast(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final student = widget.student;

    if (student.curriculumCompleted) {
      return Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: tokens.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ما شاء الله — تم ختم القرآن كاملًا 🎉',
              style: textTheme.titleMedium?.copyWith(color: tokens.green),
            ),
          ),
        ],
      );
    }

    final remainingAsync = ref.watch(
      remainingCurriculumProvider((
        level: student.currentLevel,
        order: student.currentOrderInLevel,
        completed: student.curriculumCompleted,
      )),
    );

    return remainingAsync.when(
      loading: () => const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => Text(
        'تعذر حساب توقع الختم',
        style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
      ),
      data: (remaining) {
        // An empty remainder here is a data gap, not a graduation — the
        // completed branch above already handled the real ختم.
        if (remaining.isFinished) {
          return Text(
            'لا تتوفر بيانات المنهج لحساب توقع الختم',
            style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
          );
        }

        final forecast = CompletionForecast.of(
          remaining: remaining,
          pace: CurriculumPace(_pace),
          meetingsPerWeek: MeetingsPerWeek(_meetingsPerWeek),
        );
        final date = DateFormat(
          'MMMM yyyy',
          'ar',
        ).format(forecast.completionDate(DateTime.now()));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_circle_rounded, size: 20, color: tokens.gold),
                const SizedBox(width: 6),
                Text('متى الختم؟', style: textTheme.titleSmall),
                const Spacer(),
                Text(
                  approxDurationAr(forecast.weeks),
                  style: textTheme.titleMedium?.copyWith(
                    color: tokens.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${meetingsAr(forecast.remainingMeetings)} · '
              'الختم المتوقع $date',
              style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
            ),
            const SizedBox(height: 4),
            Text(
              paceHintAr(remaining.standaloneCount),
              style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setPace(int multiplier) async {
    if (multiplier == _storedPace) return;
    try {
      await ref
          .read(studentRepositoryProvider)
          .setStudentPace(widget.student.id, CurriculumPace(multiplier));
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
          .setStudentMeetingsPerWeek(widget.student.id, MeetingsPerWeek(count));
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
