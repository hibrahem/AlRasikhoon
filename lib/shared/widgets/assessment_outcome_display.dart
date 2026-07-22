import 'package:flutter/material.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';
import '../../domain/assessment/assessment_evaluation.dart';

/// The sheet's final verdict, as the result screens render it: موفق or
/// غير موفق, with the sheet's own consequence line under it (وينقل للاختبار /
/// ويستكمل حفظه / ويمنح المحاولة الثانية).
///
/// Assessments are never shown stars or a راسخ..محب grade — that scale
/// belongs to lessons.
class AssessmentOutcomeDisplay extends StatelessWidget {
  final AssessmentOutcome outcome;

  /// The sheet's consequence wording when موفق — a سرد moves the student to
  /// the اختبار, an اختبار lets them continue memorizing.
  final String passedDetailAr;

  const AssessmentOutcomeDisplay({
    super.key,
    required this.outcome,
    required this.passedDetailAr,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final brightness = Theme.of(context).brightness;
    final passed = outcome.passed;
    final color = passed ? tokens.green : tokens.maroon;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            outcome.nameAr,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            passed ? passedDetailAr : 'ويُمنح محاولة أخرى',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }
}

/// جدول توضيح أخطاء الطالب بالتفصيل — one row per assessed unit (face or
/// question), one cell per error type, exceeded cells marked in maroon.
class AssessmentBreakdownTable extends StatelessWidget {
  final List<RecitationErrorTally> units;
  final AssessmentErrorLimits limits;

  /// The sheet's name for unit [index] — 'الوجه 3' or 'السؤال الثالث'.
  final String Function(int index) unitLabelAr;

  const AssessmentBreakdownTable({
    super.key,
    required this.units,
    required this.limits,
    required this.unitLabelAr,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final headerStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: tokens.sepia);

    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.sepia.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: Text('', style: headerStyle)),
              for (final type in RecitationErrorType.values)
                Expanded(
                  // A column can be narrower than its one-word heading on a
                  // narrow phone or at a large system font size, and Arabic
                  // broken mid-word (التنبيها / ت) reads as cut off — shrink
                  // the word to the column instead of wrapping it.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(type.nameAr, style: headerStyle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < units.length; i++) ...[
            Divider(height: 1, color: tokens.sepia.withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (!limits.allows(units[i])) ...[
                          Icon(Icons.cancel, size: 14, color: tokens.maroon),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            unitLabelAr(i),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final type in RecitationErrorType.values)
                    Expanded(
                      child: Text(
                        '${units[i].countOf(type)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: units[i].countOf(type) > limits.limitOf(type)
                              ? tokens.maroon
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
