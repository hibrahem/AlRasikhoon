import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/student_model.dart';
import '../../domain/curriculum/completion_forecast.dart';
import '../../domain/curriculum/curriculum_pace.dart';
import '../../domain/curriculum/meetings_per_week.dart';
import '../curriculum/forecast_copy.dart';
import '../providers/completion_forecast_provider.dart';
import 'app_card.dart';

/// The "متى الختم؟" card — how long until this student finishes the whole
/// Quran, and a what-if simulator to dream on.
///
/// The headline is the student's ACTUAL plan: their stored pace and weekly
/// cadence against everything still ahead of them. The expandable simulator
/// below it re-evaluates the same remaining curriculum at any pace × cadence —
/// pure local state, it never writes; the pace dial that actually changes the
/// student lives in [StudentPaceControl]. One card, every role: the student
/// (and their guardian) sees it on the dashboard, the teacher on the profile,
/// the supervisor and the admin on the shared progress screen.
class CompletionForecastCard extends ConsumerStatefulWidget {
  final StudentModel student;

  /// Forwarded to the [AppCard]: hosts whose column already pads (the student
  /// dashboard) pass [EdgeInsets.zero]; the rest keep the card default.
  final EdgeInsetsGeometry? margin;

  const CompletionForecastCard({super.key, required this.student, this.margin});

  @override
  ConsumerState<CompletionForecastCard> createState() =>
      _CompletionForecastCardState();
}

class _CompletionForecastCardState
    extends ConsumerState<CompletionForecastCard> {
  // The simulator's dials, seeded from the student's real plan so opening it
  // starts at "today's answer" and every move reads as a delta from it.
  late int _simPace = widget.student.pace.multiplier;
  late int _simMeetingsPerWeek = widget.student.meetingsPerWeek.count;
  bool _simulating = false;

  @override
  void didUpdateWidget(CompletionForecastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student.pace != widget.student.pace) {
      _simPace = widget.student.pace.multiplier;
    }
    if (oldWidget.student.meetingsPerWeek != widget.student.meetingsPerWeek) {
      _simMeetingsPerWeek = widget.student.meetingsPerWeek.count;
    }
  }

  /// The simulator slider's ceiling: the useful cap, widened only to hold a
  /// legacy stored pace above it (a Slider throws on value > max).
  int get _simSliderMax => _simPace > CurriculumPace.maxUsefulMultiplier
      ? _simPace
      : CurriculumPace.maxUsefulMultiplier;

  ForecastPosition get _position => (
    level: widget.student.currentLevel,
    order: widget.student.currentOrderInLevel,
    completed: widget.student.curriculumCompleted,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final remainingAsync = ref.watch(remainingCurriculumProvider(_position));

    return AppCard(
      margin: widget.margin,
      child: remainingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('متى الختم؟', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'تعذر حساب توقع الختم',
              style: textTheme.bodyMedium?.copyWith(color: tokens.maroon),
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(remainingCurriculumProvider(_position)),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
        // "Nothing remains" means التخرج only when the student's own record
        // says so — an empty levels catalog also yields an empty remainder,
        // and congratulating a brand-new student on a data gap would be
        // absurd. Same honest-zero posture as CurriculumProgress.
        data: (remaining) => widget.student.curriculumCompleted
            ? _CompletedBody(textTheme: textTheme, tokens: tokens)
            : remaining.isFinished
            ? Text(
                'لا تتوفر بيانات المنهج لحساب توقع الختم',
                style: textTheme.bodyMedium?.copyWith(color: tokens.sepia),
              )
            : _forecastBody(context, remaining),
      ),
    );
  }

  Widget _forecastBody(BuildContext context, RemainingCurriculum remaining) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final student = widget.student;

    final planned = CompletionForecast.of(
      remaining: remaining,
      pace: student.pace,
      meetingsPerWeek: student.meetingsPerWeek,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flag_circle_rounded, color: tokens.gold),
            const SizedBox(width: 8),
            Text('متى الختم؟', style: textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          approxDurationAr(planned.weeks),
          style: textTheme.headlineSmall?.copyWith(
            color: tokens.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'المتبقي لختم القرآن كاملًا — ${meetingsAr(planned.remainingMeetings)} '
          'بوتيرة ${student.pace.multiplier}× '
          'و${student.meetingsPerWeek.count} في الأسبوع',
          style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
        const SizedBox(height: 4),
        Text('الختم المتوقع: ${_dateAr(planned)}', style: textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          paceHintAr(remaining.standaloneCount),
          style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
        const SizedBox(height: 8),

        // --- The what-if simulator ------------------------------------------
        InkWell(
          onTap: () => setState(() => _simulating = !_simulating),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: tokens.green),
                const SizedBox(width: 6),
                // Flexed so a large system font wraps the label between
                // words instead of overflowing against the chevron.
                Expanded(
                  child: Text(
                    'ماذا لو تغيّرت الخطة؟',
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _simulating ? Icons.expand_less : Icons.expand_more,
                  color: tokens.green,
                ),
              ],
            ),
          ),
        ),
        if (_simulating) _simulator(context, remaining),
      ],
    );
  }

  Widget _simulator(BuildContext context, RemainingCurriculum remaining) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final simulated = CompletionForecast.of(
      remaining: remaining,
      pace: CurriculumPace(_simPace),
      meetingsPerWeek: MeetingsPerWeek(_simMeetingsPerWeek),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('وتيرة الحفظ', style: textTheme.bodyMedium)),
            Text(
              '$_simPace×',
              style: textTheme.titleSmall?.copyWith(
                color: tokens.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // Capped at the useful range — see CurriculumPace.maxUsefulMultiplier
        // for the curriculum math; widened only if a legacy stored pace sits
        // above the cap (a Slider throws on value > max).
        Slider(
          value: _simPace.toDouble(),
          min: 1,
          max: _simSliderMax.toDouble(),
          divisions: _simSliderMax - 1,
          label: '$_simPace×',
          onChanged: (value) => setState(() => _simPace = value.round()),
        ),
        Row(
          children: [
            Expanded(
              child: Text('اللقاءات في الأسبوع', style: textTheme.bodyMedium),
            ),
            IconButton(
              onPressed: _simMeetingsPerWeek > 1
                  ? () => setState(() => _simMeetingsPerWeek--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'لقاء أقل',
            ),
            Text(
              '$_simMeetingsPerWeek',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: _simMeetingsPerWeek < MeetingsPerWeek.maxPerWeek
                  ? () => setState(() => _simMeetingsPerWeek++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'لقاء أكثر',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approxDurationAr(simulated.weeks),
                style: textTheme.titleMedium?.copyWith(
                  color: tokens.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${weeksAr(simulated.weeks)} · '
                '${meetingsAr(simulated.remainingMeetings)} · '
                'الختم المتوقع ${_dateAr(simulated)}',
                style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'محاكاة فقط — لا تغيّر خطة الطالب المسجلة.',
          style: textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
      ],
    );
  }

  String _dateAr(CompletionForecast forecast) => DateFormat(
    'MMMM yyyy',
    'ar',
  ).format(forecast.completionDate(DateTime.now()));
}

class _CompletedBody extends StatelessWidget {
  final TextTheme textTheme;
  final AppTokens tokens;

  const _CompletedBody({required this.textTheme, required this.tokens});

  @override
  Widget build(BuildContext context) {
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
}
