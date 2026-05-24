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
                                  record.curriculumSessionId,
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
                      if (record.repetitions > 0)
                        _InfoRow(
                          label: 'التكرارات',
                          value: '${record.repetitions}',
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Overall session result — binary pass/fail, fails on ANY
                // محب component, no averaging (#24). The session grade is the
                // worst of the three level-based component grades (#22).
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

                _PartResultCard(
                  title: 'الحفظ الجديد',
                  errors: record.grades.newMemorizationErrors,
                  level: record.levelId,
                ),
                const SizedBox(height: 8),
                _PartResultCard(
                  title: 'المراجعة القريبة',
                  errors: record.grades.recentReviewErrors,
                  level: record.levelId,
                ),
                const SizedBox(height: 8),
                _PartResultCard(
                  title: 'المراجعة البعيدة',
                  errors: record.grades.distantReviewErrors,
                  level: record.levelId,
                ),

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
