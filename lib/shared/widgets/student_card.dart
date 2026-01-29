import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/student_repository.dart';
import 'progress_bar.dart';

class StudentCard extends StatelessWidget {
  final StudentWithUser studentWithUser;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool showSession;

  const StudentCard({
    super.key,
    required this.studentWithUser,
    this.onTap,
    this.showProgress = true,
    this.showSession = true,
  });

  @override
  Widget build(BuildContext context) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name and level
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0] : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'المستوى ${student.currentLevel}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Current session indicator
                  if (showSession)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getSessionColor(student.currentSession)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getSessionColor(student.currentSession),
                        ),
                      ),
                      child: Text(
                        _getSessionLabel(student.currentSession),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getSessionColor(student.currentSession),
                        ),
                      ),
                    ),
                ],
              ),

              if (showProgress) ...[
                const SizedBox(height: 16),
                // Progress info
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.menu_book,
                      label: 'الجزء ${student.currentJuz}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.bookmark,
                      label: 'الحزب ${student.currentHizb}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.school,
                      label: 'الحلقة ${student.currentSession}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ProgressBar(
                  progress: student.currentSession / 36,
                  height: 4,
                  showPercentage: false,
                ),
              ],

              // Attempt indicator if not first attempt
              if (student.currentAttempt > 1) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'المحاولة ${student.currentAttempt}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getSessionColor(int session) {
    if (session == 36) return AppColors.secondary; // Exam
    if (session == 35) return AppColors.info; // Sard
    return AppColors.primary; // Regular
  }

  String _getSessionLabel(int session) {
    if (session == 36) return 'اختبار';
    if (session == 35) return 'سرد';
    return 'حلقة $session';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for lists
class StudentListTile extends StatelessWidget {
  final StudentWithUser studentWithUser;
  final VoidCallback? onTap;
  final Widget? trailing;

  const StudentListTile({
    super.key,
    required this.studentWithUser,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          user.name.isNotEmpty ? user.name[0] : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(user.name),
      subtitle: Text(
        'المستوى ${student.currentLevel} - الحلقة ${student.currentSession}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_left,
            color: AppColors.textSecondary,
          ),
    );
  }
}
