import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// The admin Management hub (branch 0 of the admin shell). Welcome header + a
/// 2×2 grid of stat cards that double as the navigation into each management
/// area: institutes, teachers, supervisors, students. Sign-out now lives in the
/// Profile tab, so there is no AppBar action here.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('الراسخون')),
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final statsAsync = ref.watch(adminStatsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً، مدير النظام',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'إدارة المعاهد والمعلمين والمشرفين والطلاب',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              data: (stats) => _buildStats(context, stats),
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: 'تعذر تحميل الإحصائيات: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, AdminStats stats) {
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
          title: 'المعاهد',
          value: '${stats.institutesCount}',
          icon: Icons.account_balance,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.institutes),
        ),
        StatCard(
          title: 'المعلمون',
          value: '${stats.teachersCount}',
          icon: Icons.people,
          iconColor: tokens.maroon,
          onTap: () => context.push(AppRoutes.teachers),
        ),
        StatCard(
          title: 'المشرفون',
          value: '${stats.supervisorsCount}',
          icon: Icons.admin_panel_settings,
          iconColor: tokens.gold,
          onTap: () => context.push(AppRoutes.supervisors),
        ),
        StatCard(
          title: 'الطلاب',
          value: '${stats.studentsCount}',
          icon: Icons.school,
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.adminStudents),
        ),
      ],
    );
  }
}
