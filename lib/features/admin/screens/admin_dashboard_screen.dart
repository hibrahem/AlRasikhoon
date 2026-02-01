import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Watch auth state for reactivity (user data available via authState.appUser if needed)
    ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الراسخون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 1:
              context.go(AppRoutes.institutes);
              break;
            case 2:
              context.go(AppRoutes.teachers);
              break;
            case 3:
              context.go(AppRoutes.curriculum);
              break;
          }
        },
        role: UserRole.superAdmin,
      ),
    );
  }

  Widget _buildBody() {
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
            // Welcome message
            Text(
              'مرحباً، مدير النظام',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'إدارة المعاهد والمعلمين',
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

            // Quick actions
            Text(
              'الإجراءات السريعة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(AdminStats stats) {
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
          iconColor: AppColors.primary,
          onTap: () => context.go(AppRoutes.institutes),
        ),
        StatCard(
          title: 'المعلمون',
          value: '${stats.teachersCount}',
          icon: Icons.people,
          iconColor: AppColors.info,
          onTap: () => context.go(AppRoutes.teachers),
        ),
        StatCard(
          title: 'المشرفون',
          value: '${stats.supervisorsCount}',
          icon: Icons.admin_panel_settings,
          iconColor: AppColors.secondary,
        ),
        StatCard(
          title: 'الطلاب',
          value: '${stats.studentsCount}',
          icon: Icons.school,
          iconColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        AppListTile(
          title: 'إضافة معهد جديد',
          subtitle: 'إنشاء معهد لتحفيظ القرآن',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_business,
              color: AppColors.primary,
            ),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push(AppRoutes.createInstitute),
        ),
        const SizedBox(height: 8),
        AppListTile(
          title: 'إضافة معلم جديد',
          subtitle: 'تسجيل معلم في النظام',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_add,
              color: AppColors.info,
            ),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push(AppRoutes.addTeacher),
        ),
        const SizedBox(height: 8),
        AppListTile(
          title: 'عرض المنهج',
          subtitle: '10 مستويات - 1453 حلقة',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.menu_book,
              color: AppColors.secondary,
            ),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.go(AppRoutes.curriculum),
        ),
      ],
    );
  }
}
