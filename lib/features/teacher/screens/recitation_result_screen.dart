import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/grade_display.dart';
import '../providers/teacher_provider.dart';

class RecitationResultScreen extends ConsumerWidget {
  final String studentId;
  final int part;
  final int errorCount;

  const RecitationResultScreen({
    super.key,
    required this.studentId,
    required this.part,
    required this.errorCount,
  });

  String get _partTitle {
    switch (part) {
      case 1:
        return 'الحفظ الجديد';
      case 2:
        return 'المراجعة القريبة';
      case 3:
        return 'المراجعة البعيدة';
      default:
        return 'التسميع';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    // Per-part grade is level-based (hibrahem/AlRasikhoon#22). The grade is
    // only computed once the student value resolves — never from a default
    // level=1 while loading, which would flash a harsher grade (#36).
    final studentAsync = ref.watch(studentProvider(studentId));
    final int? level = studentAsync.value?.student.currentLevel;
    final gradeInfo = level != null
        ? GradeCalculator.calculateForLevel(level, errorCount)
        : null;
    // Distinct accent per memorization mode (hibrahem/AlRasikhoon#25), kept
    // consistent with the recitation session screen. The Arabic mode label is
    // always shown, so the mode is never signalled by color alone.
    final modeColor = AppColors.forMemorizationPart(part);

    return Scaffold(
      appBar: AppBar(
        title: Text('نتيجة $_partTitle'),
        backgroundColor: modeColor,
        foregroundColor: AppColors.textOnPrimary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Spacer(),

              // Part indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الجزء $part من 3',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: modeColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 24),

              // Grade display — withhold until the real level resolves (#36).
              studentAsync.when(
                data: (_) => GradeDisplay(
                  errorCount: errorCount,
                  gradeInfo: gradeInfo,
                  showStars: true,
                  showPassStatus: true,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('تعذّر تحميل النتيجة'),
                ),
              ),

              const Spacer(),

              // Summary so far (if not first part). Withheld until the real
              // level resolves so per-part grades aren't computed at level 1 (#36).
              if (part > 1 && activeSession != null && level != null)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملخص الأجزاء السابقة',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      if (part >= 2)
                        _SummaryRow(
                          title: 'الحفظ الجديد',
                          errors: activeSession.part1Errors,
                          level: level,
                        ),
                      if (part >= 3)
                        _SummaryRow(
                          title: 'المراجعة القريبة',
                          errors: activeSession.part2Errors,
                          level: level,
                        ),
                    ],
                  ),
                ),

              // Action buttons
              if (part < 3)
                Column(
                  children: [
                    AppButton(
                      text: 'التالي: ${_getNextPartTitle()}',
                      onPressed: () {
                        context.pushReplacement(
                          AppRoutes.recitation
                              .replaceFirst(':studentId', studentId)
                              .replaceFirst(':part', '${part + 1}'),
                        );
                      },
                      isFullWidth: true,
                      size: AppButtonSize.large,
                    ),
                    const SizedBox(height: 12),
                    if (gradeInfo != null && !gradeInfo.passed)
                      AppButton(
                        text: 'إعادة $_partTitle',
                        onPressed: () {
                          context.pushReplacement(
                            AppRoutes.recitation
                                .replaceFirst(':studentId', studentId)
                                .replaceFirst(':part', '$part'),
                          );
                        },
                        type: AppButtonType.outline,
                        isFullWidth: true,
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    AppButton(
                      text: 'عرض ملخص الحلقة',
                      onPressed: () {
                        context.push(
                          AppRoutes.sessionSummary
                              .replaceFirst(':studentId', studentId),
                        );
                      },
                      isFullWidth: true,
                      size: AppButtonSize.large,
                    ),
                    const SizedBox(height: 12),
                    if (gradeInfo != null && !gradeInfo.passed)
                      AppButton(
                        text: 'إعادة $_partTitle',
                        onPressed: () {
                          context.pushReplacement(
                            AppRoutes.recitation
                                .replaceFirst(':studentId', studentId)
                                .replaceFirst(':part', '$part'),
                          );
                        },
                        type: AppButtonType.outline,
                        isFullWidth: true,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getNextPartTitle() {
    switch (part + 1) {
      case 2:
        return 'المراجعة القريبة';
      case 3:
        return 'المراجعة البعيدة';
      default:
        return '';
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final int errors;
  final int level;

  const _SummaryRow({
    required this.title,
    required this.errors,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            gradeInfo.passed ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: gradeInfo.passed ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$errors أخطاء',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: gradeInfo.color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
