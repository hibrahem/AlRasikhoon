import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_sign_out.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
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
            // Admin has no الإعدادات destination, so its sign-out lives here in
            // the AppBar — but behind the same confirmation gate as every other
            // role, never a one-tap destructive action.
            onPressed: () => confirmSignOut(context, ref),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
            // Welcome message
            Text(
              'مرحباً، مدير النظام',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'إدارة المعاهد والمعلمين',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
            ),
            const SizedBox(height: 24),

            // Stats
            statsAsync.when(
              data: (stats) => _buildStats(stats),
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: 'تعذر تحميل الإحصائيات: $e'),
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
          onTap: () => context.go(AppRoutes.institutes),
        ),
        StatCard(
          title: 'المعلمون',
          value: '${stats.teachersCount}',
          icon: Icons.people,
          // No manuscript token for the old "info" blue; maroon (the
          // palette's rubrication/emphasis hue) keeps this card visually
          // distinct from the green institutes card and gold
          // supervisors/students cards below, with no collision against
          // this card's own sepia caption text.
          iconColor: tokens.maroon,
          onTap: () => context.go(AppRoutes.teachers),
        ),
        StatCard(
          title: 'المشرفون',
          value: '${stats.supervisorsCount}',
          icon: Icons.admin_panel_settings,
          iconColor: tokens.gold,
          onTap: () => context.push(AppRoutes.addSupervisor),
        ),
        StatCard(
          title: 'الطلاب',
          value: '${stats.studentsCount}',
          icon: Icons.school,
          // "success" reused as green — the positive/affirmative role
          // green already carries elsewhere (see student dashboard
          // precedent).
          iconColor: tokens.green,
          onTap: () => context.push(AppRoutes.adminStudents),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final tokens = context.tokens;
    return Column(
      children: [
        AppListTile(
          title: 'إضافة معهد جديد',
          subtitle: 'إنشاء معهد لتحفيظ القرآن',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_business, color: tokens.green),
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
              // Same "info" -> maroon judgment call as the teachers stat
              // card above, kept consistent across this screen.
              color: tokens.maroon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_add, color: tokens.maroon),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push(AppRoutes.addTeacher),
        ),
        const SizedBox(height: 8),
        AppListTile(
          title: 'إضافة مشرف جديد',
          subtitle: 'تسجيل مشرف وربطه بمعهد',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.admin_panel_settings, color: tokens.gold),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.push(AppRoutes.addSupervisor),
        ),
        const SizedBox(height: 8),
        AppListTile(
          title: 'عرض المنهج',
          subtitle: '10 مستويات - 1453 حلقة',
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tokens.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.menu_book, color: tokens.gold),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => context.go(AppRoutes.curriculum),
        ),
      ],
    );
  }
}
