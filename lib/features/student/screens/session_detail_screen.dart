import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/grade_display.dart';
import '../providers/student_provider.dart';

class SessionDetailScreen extends ConsumerWidget {
  final String recordId;

  const SessionDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordAsync = ref.watch(sessionRecordByIdProvider(recordId));

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحلقة')),
      body: recordAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(child: Text('الحلقة غير موجودة'));
          }

          final dateFormat = DateFormat('yyyy/MM/dd hh:mm a', 'ar');

          // The record carries only the session id (`L1_J30_S1`). That id is a
          // key, not a name: the title a student reads is the session's own
          // Arabic title. Fall back to the id only if the session cannot be
          // resolved at all.
          final session = ref
              .watch(curriculumSessionByIdProvider(record.curriculumSessionId))
              .value;
          final title = session?.titleAr ?? record.curriculumSessionId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session info
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.menu_book,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  dateFormat.format(record.date),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'المحاولة',
                        value: '${record.attemptNumber}',
                      ),
                      if (record.repetitionsWithTeacher > 0)
                        _InfoRow(
                          label: 'التكرارات',
                          value: '${record.repetitionsWithTeacher}',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // A تلقين is never graded — no errors, no pass/fail, no
                // attempt cap. It must NOT show `GradeDisplay` or the
                // part-by-part error breakdown below, which both imply a
                // graded outcome that a تلقين never has.
                if (record.isTalqeen)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.record_voice_over,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تلقين — قرأ المعلّم المقطع على الطالب وكرّره معه. '
                            'لا تسميع ولا تقييم ولا نجاح أو رسوب في هذه الحلقة.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Overall session result — binary pass/fail, fails on ANY
                  // محب component, no averaging (#24). The session grade is
                  // the worst of the three level-based component grades (#22).
                  Center(
                    child: GradeDisplay(
                      errorCount: record.grades.totalErrors,
                      gradeInfo: GradeCalculator.calculateSessionGrade(
                        level: record.levelId,
                        newMemorizationErrors:
                            record.grades.newMemorizationErrors,
                        recentReviewErrors: record.grades.recentReviewErrors,
                        distantReviewErrors: record.grades.distantReviewErrors,
                      ),
                      showStars: true,
                      showPassStatus: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Part-by-part results
                  Text(
                    'تفاصيل الأجزاء',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  // Only the parts this meeting actually recited — a
                  // review-only or short meeting omits parts 2/3, so a skipped
                  // part is never rendered as a passing zero-error card. Legacy
                  // records with no marker read back as all three (see
                  // SessionRecordModel.presentParts).
                  for (final part in record.presentParts) ...[
                    _PartResultCard(
                      title: _partTitleAr(part),
                      errors: record.grades.errorsForPart(part),
                      level: record.levelId,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                // Notes
                if (record.notes != null && record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'ملاحظات المعلم',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      record.notes!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// The Arabic label for a recitation part: 1 = new memorization, 2 = recent
/// review, 3 = distant review.
String _partTitleAr(int part) {
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _PartResultCard extends StatelessWidget {
  final String title;
  final int errors;
  final int level;

  const _PartResultCard({
    required this.title,
    required this.errors,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            gradeInfo.passed ? Icons.check_circle : Icons.cancel,
            color: gradeInfo.passed ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$errors أخطاء',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: gradeInfo.color,
                ),
              ),
              Text(
                gradeInfo.nameAr,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: gradeInfo.color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
