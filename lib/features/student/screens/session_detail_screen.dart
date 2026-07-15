import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/grade_color_tokens.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';

class SessionDetailScreen extends ConsumerWidget {
  final String recordId;

  const SessionDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
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
                              color: tokens.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.menu_book, color: tokens.green),
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
                                      ?.copyWith(color: tokens.sepia),
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
                // attempt cap. It must NOT show the overall result banner or
                // the part-by-part error breakdown below, which both imply a
                // graded outcome that a تلقين never has.
                if (record.isTalqeen)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: tokens.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.record_voice_over, color: tokens.green),
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
                  // Overall session result is a BINARY pass/fail ONLY (#24):
                  // the session is failed if ANY single part grades محب, and
                  // passes only if none is. It deliberately shows NO combined
                  // grade tier and NO summed error "score" — grades and error
                  // counts are never combined across parts. Each part's own
                  // grade and pass/fail is shown, alone, in the cards below.
                  Center(
                    child: _OverallResultBanner(
                      passed: record.grades.passesForLevel(record.levelId),
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
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل تفاصيل الحلقة: $e'),
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

/// The session-level verdict: a binary ناجح / راسب marker per
/// hibrahem/AlRasikhoon#24. It carries no grade tier and no error count on
/// purpose — the session outcome is pass/fail only, and every per-part grade
/// and error count lives in the part cards below it, each evaluated alone.
class _OverallResultBanner extends StatelessWidget {
  final bool passed;

  const _OverallResultBanner({required this.passed});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // tokens.green / tokens.maroon carry the passed / failed roles used by the
    // per-part cards on this same screen — reuse them so the overall verdict
    // reads with the same colour language as the parts it summarises.
    final color = passed ? tokens.green : tokens.maroon;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            passed ? 'ناجح' : 'راسب',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
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
    final tokens = context.tokens;
    final gradeInfo = GradeCalculator.calculateForLevel(level, errors);

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            gradeInfo.passed ? Icons.check_circle : Icons.cancel,
            // AppColors.success has no direct AppTokens equivalent (not in
            // the Task 9 mapping table). Following the Task 13 precedent,
            // it maps to tokens.green — tokens.green and AppColors.gradeRasikh
            // are byte-identical, and green already carries the
            // "positive/passed" role elsewhere in this screen (تلقين icon,
            // header icon). AppColors.error maps to tokens.maroon per the
            // table. No collision: the errors-count/grade-name text to the
            // right uses tokens.colorForGrade (the brightness-aware
            // grade-tier palette), a separate signal from this pass/fail
            // icon.
            color: gradeInfo.passed ? tokens.green : tokens.maroon,
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
                  color: tokens.colorForGrade(gradeInfo.grade),
                ),
              ),
              Text(
                gradeInfo.nameAr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.colorForGrade(gradeInfo.grade),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
