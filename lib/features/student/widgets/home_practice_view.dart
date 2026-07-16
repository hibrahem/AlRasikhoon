import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/day_beads.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/stat_tile.dart';

/// One logged repetition, pre-formatted for display.
@immutable
class PracticeHistoryEntry {
  final int repetitions;
  final String title;
  final String dateLabel;

  const PracticeHistoryEntry({
    required this.repetitions,
    required this.title,
    required this.dateLabel,
  });
}

/// Everything the home-practice screen renders, pre-derived — the
/// presentation half of the screen; the preview harness fills it with mock
/// data.
@immutable
class HomePracticeData {
  final int? assignmentDone;
  final int? assignmentRequired;
  final bool assignmentComplete;
  final int todayRepetitions;
  final int streakDays;
  final int totalRepetitions;

  /// Last seven days, today first — see [DayBeads].
  final List<bool> weekBeads;

  /// The current session strip inside the counter card; null hides it.
  final String? sessionTitle;
  final String? sessionSubtitle;
  final List<PracticeHistoryEntry> history;

  const HomePracticeData({
    this.assignmentDone,
    this.assignmentRequired,
    this.assignmentComplete = false,
    required this.todayRepetitions,
    required this.streakDays,
    required this.totalRepetitions,
    required this.weekBeads,
    this.sessionTitle,
    this.sessionSubtitle,
    required this.history,
  });
}

/// The redesigned home-practice body: assignment card with a big gold
/// numeral, bento stat row (day-beads instead of a flame), a circular-stepper
/// counter card, and ticket-style history rows.
class HomePracticeView extends StatefulWidget {
  final HomePracticeData data;

  /// Validates and performs the submit; returns true on success, at which
  /// point the view resets its own form.
  final Future<bool> Function(int repetitions, String? notes)? onSubmit;

  const HomePracticeView({super.key, required this.data, this.onSubmit});

  @override
  State<HomePracticeView> createState() => _HomePracticeViewState();
}

class _HomePracticeViewState extends State<HomePracticeView> {
  final _repetitionsController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _repetitionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final current = int.tryParse(_repetitionsController.text) ?? 1;
    final next = current + delta;
    if (next >= 1) _repetitionsController.text = '$next';
  }

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) return;

    final repetitions = int.tryParse(_repetitionsController.text) ?? 0;
    final notes = _notesController.text.isNotEmpty
        ? _notesController.text
        : null;

    setState(() => _isSubmitting = true);
    final success = await onSubmit(repetitions, notes);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      _repetitionsController.text = '1';
      _notesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.assignmentDone != null && data.assignmentRequired != null) ...[
          _AssignmentCard(
            done: data.assignmentDone!,
            required_: data.assignmentRequired!,
            complete: data.assignmentComplete,
          ),
          const SizedBox(height: AppDimens.space16),
        ],
        _buildBentoRow(context),
        const SizedBox(height: AppDimens.space24),
        Text(
          'تسجيل تكرار جديد',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimens.space12),
        _buildCounterCard(context),
        const SizedBox(height: AppDimens.space24),
        Text('سجل التكرارات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppDimens.space12),
        for (final entry in data.history) ...[
          _HistoryTicket(entry: entry),
          const SizedBox(height: AppDimens.space8),
        ],
      ],
    );
  }

  Widget _buildBentoRow(BuildContext context) {
    final tokens = context.tokens;
    final data = widget.data;
    // Tiles take their natural heights: the streak tile's beads footer makes
    // it the tallest, which is a bento feature, not a bug (and the intrinsic
    // equal-height pass rounds fractionally and overflows).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The streak leads and carries this screen's one asymmetric corner;
        // its day-beads strip replaces the flame icon of the old design.
        Expanded(
          child: StatTile(
            icon: Icons.timeline,
            value: '${data.streakDays}',
            label: 'أيام متتالية',
            accent: tokens.gold,
            accentCorner: true,
            footer: DayBeads(days: data.weekBeads, beadSize: 8),
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: StatTile(
            icon: Icons.today,
            value: '${data.todayRepetitions}',
            label: 'اليوم',
            accent: tokens.green,
          ),
        ),
        const SizedBox(width: AppDimens.space12),
        Expanded(
          child: StatTile(
            icon: Icons.repeat,
            value: '${data.totalRepetitions}',
            label: 'إجمالي التكرارات',
            accent: tokens.gold,
          ),
        ),
      ],
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final data = widget.data;

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCardLg),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.sessionTitle != null) ...[
            Container(
              padding: const EdgeInsetsDirectional.all(12),
              decoration: BoxDecoration(
                color: tokens.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: tokens.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.sessionTitle!,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (data.sessionSubtitle != null)
                          Text(
                            data.sessionSubtitle!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.sepia),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.space16),
          ],
          Text('عدد التكرارات', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppDimens.space8),
          Row(
            children: [
              _StepperButton(icon: Icons.remove, onTap: () => _step(-1)),
              Expanded(
                child: TextField(
                  controller: _repetitionsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: tokens.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsetsDirectional.symmetric(
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              _StepperButton(icon: Icons.add, onTap: () => _step(1)),
            ],
          ),
          const SizedBox(height: AppDimens.space16),
          Text(
            'ملاحظات (اختياري)',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppDimens.space8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'أضف ملاحظات...'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.gold,
                      ),
                    )
                  : Icon(Icons.check, size: 20, color: tokens.gold),
              label: const Text('تسجيل التكرار'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 56dp circular filled-green − / + button flanking the counter.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final onGreen = Theme.of(context).colorScheme.onPrimary;
    return Material(
      color: tokens.green,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: onGreen, size: 26),
        ),
      ),
    );
  }
}

/// The teacher's assignment, headlined by a big tabular `done / required`
/// numeral — gold while in progress (achievement underway), green once
/// complete.
class _AssignmentCard extends StatelessWidget {
  final int done;
  final int required_;
  final bool complete;

  const _AssignmentCard({
    required this.done,
    required this.required_,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    // Shown count capped at the target so an over-practising student sees
    // '10 / 10', matching the bar, never an off '12 / 10'.
    final displayedDone = done.clamp(0, required_);
    final accent = complete ? tokens.green : tokens.gold;

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCardLg),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'واجب التكرار في المنزل',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimens.space8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$displayedDone',
                  style: GoogleFonts.cairo(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                TextSpan(
                  text: ' / $required_',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: tokens.sepia,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.space8),
          ProgressBar(
            progress: (done / required_).clamp(0.0, 1.0),
            height: 10,
            progressColor: accent,
          ),
          const SizedBox(height: AppDimens.space8),
          Text(
            complete ? 'اكتمل الواجب' : 'كرر المقطع حتى تبلغ الهدف',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: complete ? tokens.green : tokens.sepia,
            ),
          ),
        ],
      ),
    );
  }
}

/// One logged repetition as a ticket row: a gold medallion carrying the
/// rep-count numeral, the session title, and the Arabic date.
class _HistoryTicket extends StatelessWidget {
  final PracticeHistoryEntry entry;

  const _HistoryTicket({required this.entry});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.gold.withValues(alpha: 0.1),
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.repetitions}',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: tokens.gold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  entry.dateLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
