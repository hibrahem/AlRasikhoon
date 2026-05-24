import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
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
    final statsAsync = ref.watch(supervisorStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الراسخون - المشرف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
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
              // Welcome
              Text(
                'مرحباً، المشرف',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'إدارة اختبارات الطلاب',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Stats
              statsAsync.when(
                data: (stats) => _buildStats(stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
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
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.quiz, color: AppColors.secondary),
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => context.go(AppRoutes.examQueue),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(SupervisorStats stats) {
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
          iconColor: AppColors.warning,
          onTap: () => context.go(AppRoutes.examQueue),
        ),
        StatCard(
          title: 'اختبارات اليوم',
          value: '${stats.completedToday}',
          icon: Icons.today,
          iconColor: AppColors.info,
        ),
        StatCard(
          title: 'ناجحون اليوم',
          value: '${stats.passedToday}',
          icon: Icons.check_circle,
          iconColor: AppColors.success,
        ),
        StatCard(
          title: 'راسبون اليوم',
          value: '${stats.failedToday}',
          icon: Icons.cancel,
          iconColor: AppColors.error,
        ),
      ],
    );
  }
}
