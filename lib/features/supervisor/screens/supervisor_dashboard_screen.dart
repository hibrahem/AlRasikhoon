import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_greeting_header.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../providers/supervisor_provider.dart';

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final statsAsync = ref.watch(supervisorStatsProvider);
    final currentUser = ref.watch(currentUserProvider);

    // No AppBar: the dashboard leads with a scrolling AppGreetingHeader instead
    // of a green title bar. Sign-out still lives, confirmed, in الإعدادات.
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(supervisorStatsProvider);
            ref.invalidate(examQueueProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppGreetingHeader(
                  greeting: 'السلام عليكم',
                  title: currentUser?.name ?? 'المشرف',
                  trailing: CircleAvatar(
                    radius: 18,
                    backgroundColor: tokens.primaryContainer,
                    child: Text(
                      (currentUser?.name ?? '؟').characters.first,
                      style: TextStyle(
                        color: tokens.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إدارة اختبارات الطلاب',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
                ),
                const SizedBox(height: 24),

                // Stats
                statsAsync.when(
                  data: (stats) => _buildStats(stats),
                  loading: () => const LoadingState(lines: 2),
                  error: (e, _) =>
                      ErrorState(message: 'تعذر تحميل الإحصائيات: $e'),
                ),

                const SizedBox(height: 24),

                // Quick action - Exam queue
                Text(
                  'الإجراءات السريعة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                AppListTile(
                  title: 'قائمة الاختبارات',
                  subtitle: 'الطلاب الجاهزون للاختبار',
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.quiz, color: tokens.gold),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.go(AppRoutes.examQueue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(SupervisorStats stats) {
    final tokens = context.tokens;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          title: 'اختبارات معلقة',
          value: '${stats.pendingExams}',
          icon: Icons.pending_actions,
          // AppColors.warning has no direct AppTokens equivalent. Pending
          // exams are the screen's own "اختبار" quick-action below (which
          // already uses tokens.gold), so gold keeps this card visually tied
          // to that same exam-attention identity — distinct from the
          // pass/fail cards below, which use green/maroon.
          iconColor: tokens.gold,
          onTap: () => context.go(AppRoutes.examQueue),
        ),
        StatCard(
          title: 'اختبارات اليوم',
          value: '${stats.completedToday}',
          icon: Icons.today,
          // AppColors.info has no direct AppTokens equivalent either. This
          // is a neutral daily tally (passed + failed combined), not a
          // warning or an outcome, so it reuses tokens.green — the
          // palette's least alarming accent — rather than the gold/maroon
          // used by the "needs attention" and "failed" cards.
          iconColor: tokens.green,
        ),
        StatCard(
          title: 'ناجحون اليوم',
          value: '${stats.passedToday}',
          icon: Icons.check_circle,
          // No manuscript token for a distinct "success" hue — the primary
          // green already carries the positive/affirmative role, so it is
          // reused here.
          iconColor: tokens.green,
        ),
        StatCard(
          title: 'راسبون اليوم',
          value: '${stats.failedToday}',
          icon: Icons.cancel,
          iconColor: tokens.maroon,
        ),
      ],
    );
  }
}
