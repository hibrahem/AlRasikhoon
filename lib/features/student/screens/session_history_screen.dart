import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/student_provider.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الحلقات')),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                // A تلقين is never graded — no pass/fail, no errors — so it
                // must never render with a pass/fail badge, even though
                // `createTalqeenRecord` writes `passed: true` unconditionally
                // (that flag exists for the stats query, not for display).
                // Listing shows only a binary pass/fail (نجح / رسب) for a
                // graded record, never an average of the three component
                // grades (#24). The per-component breakdown lives in the
                // session detail view.
                final isTalqeen = record.isTalqeen;
                final badgeColor = isTalqeen
                    ? AppColors.primary
                    : (record.passed ? AppColors.success : AppColors.error);
                final dateFormat = DateFormat('yyyy/MM/dd', 'ar');

                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () {
                    context.push(
                      AppRoutes.sessionDetail.replaceFirst(
                        ':recordId',
                        record.id,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            isTalqeen
                                ? Icons.record_voice_over
                                : (record.passed
                                      ? Icons.check_circle
                                      : Icons.cancel),
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTalqeen
                                  ? 'تلقين'
                                  : 'الحلقة ${record.sessionNumber}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            // Never an app-derived hizb — `record.hizbNumber`
                            // is the denormalized structural value, which can
                            // disagree with a session's own verbatim label.
                            Text(
                              'المستوى ${record.levelId}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              dateFormat.format(record.date),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: badgeColor),
                        ),
                        child: Text(
                          isTalqeen ? 'تلقين' : (record.passed ? 'نجح' : 'رسب'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا سجلات الحلقات السابقة',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
