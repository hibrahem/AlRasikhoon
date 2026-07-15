import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/institute_provider.dart';
import '../../../shared/providers/stats_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/confirm_sign_out.dart';
import '../widgets/theme_mode_selector.dart';

/// Account screen for the teacher, supervisor and student shells.
///
/// Provides user profile, role, activity stats, and appearance preferences.
/// Theme mode can be toggled via the embedded [ThemeModeSelector].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: 16),
          const ThemeModeSelector(),
          if (user.role == UserRole.teacher) ...[
            const SizedBox(height: 16),
            const _TeacherStatsCard(),
            const SizedBox(height: 16),
            const _InstitutesCard(),
          ] else if (user.role == UserRole.student ||
              user.role == UserRole.guardian) ...[
            const SizedBox(height: 16),
            const _StudentStatsCard(),
          ],
          const SizedBox(height: 24),
          _SignOutButton(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    // The person's own login name is the identity worth showing here; fall
    // back to a phone only when there is genuinely no username to show.
    final contact = user.displayUsername.isNotEmpty
        ? user.displayUsername
        : (user.phone ?? '');

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (contact.isNotEmpty)
                  Text(
                    contact,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  user.role.nameAr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The institutes a teacher is assigned to. Teachers can work across several,
/// which is why the students list carries a المعهد filter at all.
class _InstitutesCard extends ConsumerWidget {
  const _InstitutesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutesAsync = ref.watch(teacherInstitutesProvider);

    return institutesAsync.maybeWhen(
      data: (institutes) {
        if (institutes.isEmpty) return const SizedBox.shrink();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المعاهد', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final institute in institutes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(institute.name)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text(
        'تسجيل الخروج',
        style: TextStyle(color: AppColors.error),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => confirmSignOut(context, ref),
    );
  }
}

/// One metric on a stats card: a big value over a small Arabic label.
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? sublabel;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (sublabel != null && sublabel!.isNotEmpty)
            Text(
              sublabel!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// The signed-in teacher's at-a-glance activity.
class _TeacherStatsCard extends ConsumerWidget {
  const _TeacherStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider);

    return statsAsync.maybeWhen(
      data: (stats) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('نشاطي', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  icon: Icons.menu_book_outlined,
                  value: '${stats.totalSessions}',
                  label: 'إجمالي الجلسات',
                ),
                _StatTile(
                  icon: Icons.calendar_month_outlined,
                  value: '${stats.sessionsThisMonth}',
                  label: 'جلسات هذا الشهر',
                ),
                _StatTile(
                  icon: Icons.school_outlined,
                  value: '${stats.studentCount}',
                  label: 'عدد الطلاب',
                ),
                _StatTile(
                  icon: Icons.business_outlined,
                  value: '${stats.instituteCount}',
                  label: 'عدد المعاهد',
                ),
              ],
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The signed-in student's (or a guardian's child's) progress at a glance.
class _StudentStatsCard extends ConsumerWidget {
  const _StudentStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(studentStatsProvider);

    return statsAsync.maybeWhen(
      data: (stats) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تقدّمي', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _StatTile(
                  icon: Icons.menu_book_outlined,
                  value: '${stats.totalSessions}',
                  label: 'إجمالي الجلسات',
                ),
                _StatTile(
                  icon: Icons.check_circle_outline,
                  value: '${(stats.passRate * 100).round()}%',
                  label: 'نسبة النجاح',
                ),
                _StatTile(
                  icon: Icons.workspace_premium_outlined,
                  value: '${stats.completedLevels}',
                  label: 'المستويات المكتملة',
                ),
                _StatTile(
                  icon: Icons.trending_up_outlined,
                  value: '${stats.currentLevel}',
                  label: 'المستوى الحالي',
                  sublabel: 'الجزء ${stats.currentJuz}',
                ),
              ],
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
