import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/assessment/assessment_evaluation.dart';

/// The live error board of one assessed unit — a سرد face or an اختبار
/// question: one counter row per curriculum error type, each judged against
/// that unit's allowance.
///
/// This is the assessment counterpart of [ErrorCounter], which serves lessons:
/// a lesson counts errors into a راسخ..محب grade, while an assessment tracks
/// التنبيهات/التلقينات/التشكيل/التجويد separately and the unit either stays
/// within every limit or fails the whole سرد/اختبار.
class AssessmentErrorCounters extends StatelessWidget {
  final RecitationErrorTally tally;
  final AssessmentErrorLimits limits;
  final ValueChanged<RecitationErrorTally> onChanged;

  const AssessmentErrorCounters({
    super.key,
    required this.tally,
    required this.limits,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final withinLimits = limits.allows(tally);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCardLg),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      child: Column(
        children: [
          for (final type in RecitationErrorType.values) ...[
            _ErrorTypeRow(
              type: type,
              count: tally.countOf(type),
              limit: limits.limitOf(type),
              onAdd: () => onChanged(tally.adding(type)),
              onUndo: () => onChanged(tally.removing(type)),
            ),
            if (type != RecitationErrorType.values.last)
              Divider(height: 8, color: tokens.sepia.withValues(alpha: 0.15)),
          ],
          const SizedBox(height: 12),
          // The unit's own verdict, live: within every allowance, or already
          // past one — which fails the whole assessment no matter how clean
          // the other units are.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                withinLimits ? Icons.check_circle : Icons.cancel,
                color: withinLimits ? tokens.green : tokens.maroon,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                withinLimits ? 'ضمن الحد المسموح' : 'تجاوز الحد المسموح',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: withinLimits ? tokens.green : tokens.maroon,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorTypeRow extends StatelessWidget {
  final RecitationErrorType type;
  final int count;
  final int limit;
  final VoidCallback onAdd;
  final VoidCallback onUndo;

  const _ErrorTypeRow({
    required this.type,
    required this.count,
    required this.limit,
    required this.onAdd,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final exceeded = count > limit;
    final countColor = exceeded ? tokens.maroon : tokens.green;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.nameAr, style: Theme.of(context).textTheme.titleSmall),
              Text(
                'المسموح: $limit',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: count > 0 ? onUndo : null,
          color: tokens.sepia,
          tooltip: 'تراجع',
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: countColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle),
          onPressed: onAdd,
          color: tokens.maroon,
          tooltip: 'خطأ ${type.nameAr}',
        ),
      ],
    );
  }
}
