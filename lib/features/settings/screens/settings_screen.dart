import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../teacher/providers/teacher_provider.dart';

/// Account screen for the teacher, supervisor and student shells.
///
/// Deliberately small: it exists to give the account actions a home. There is
/// no language or theme toggle — the app is locale-locked to `ar`
/// (`lib/app.dart`) and has no theme mode, so a switch here would flip nothing.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(user: user),
          if (user.role == UserRole.teacher) ...[
            const SizedBox(height: 16),
            const _InstitutesCard(),
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
    final contact = user.email.isNotEmpty ? user.email : (user.phone ?? '');

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
      onPressed: () => _confirmSignOut(context, ref),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider.notifier).signOut();
    }
  }
}
