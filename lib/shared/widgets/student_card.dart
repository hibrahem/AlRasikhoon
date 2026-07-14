import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../data/repositories/student_repository.dart';
import 'progress_bar.dart';

/// A student, as every list shows them.
///
/// What the student is standing on comes from `current_session_kind` — the
/// curriculum's own word for the session — never from its number: the juz-30
/// اختبار of level 1 is session 68, and session 35 is an ordinary lesson.
/// Progress is measured against the level's real session count, read from the
/// catalog.
class StudentCard extends ConsumerWidget {
  final StudentWithUser studentWithUser;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool showSession;

  /// Optional institute name shown as a small text badge on the card.
  /// Used when a list spans more than one institute (e.g. the admin
  /// teacher-detail view) so each card names which institute the student
  /// belongs to. Null or empty hides the badge — redundant when the list
  /// already shows a single institute. See hibrahem/AlRasikhoon#53.
  final String? instituteName;

  const StudentCard({
    super.key,
    required this.studentWithUser,
    this.onTap,
    this.showProgress = true,
    this.showSession = true,
    this.instituteName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;
    final level = ref.watch(levelProvider(student.currentLevel)).value;
    final sessionCount = level?.sessionCount ?? 0;
    final progress = sessionCount > 0
        ? (student.currentOrderInLevel - 1).clamp(0, sessionCount) /
              sessionCount
        : 0.0;

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
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (instituteName != null &&
                            instituteName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _InstituteBadge(name: instituteName!),
                        ],
                      ],
                    ),
                  ),
                  // What the student is standing on — the curriculum's word for
                  // it (kind), not an inference from the session number.
                  if (showSession)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _kindColor(
                          student.currentSessionKind,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _kindColor(student.currentSessionKind),
                        ),
                      ),
                      child: Text(
                        _kindLabel(
                          student.currentSessionKind,
                          student.currentSession,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _kindColor(student.currentSessionKind),
                        ),
                      ),
                    ),
                ],
              ),

              if (showProgress) ...[
                const SizedBox(height: 16),
                // Progress info. `currentHizb` is never shown here: it is the
                // denormalized STRUCTURAL value, which can disagree with the
                // student's own assessment's verbatim label (level 2's source
                // workbooks contradict themselves on which hizb is which). The
                // juz is always consistent with the data.
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.menu_book,
                      label: 'الجزء ${student.currentJuz}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.school,
                      label: 'الحلقة ${student.currentSession}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress through the LEVEL: order_in_level over the level's
                // real session count, from the catalog — never `/ 36`.
                ProgressBar(
                  progress: progress,
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
                    color: AppColors.warning.withValues(alpha: 0.1),
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

  Color _kindColor(SessionKind kind) {
    switch (kind) {
      case SessionKind.exam:
        return AppColors.secondary;
      case SessionKind.sard:
        return AppColors.info;
      case SessionKind.talqeen:
      case SessionKind.lesson:
        // A تلقين teaches new content like a lesson does and is never
        // assessed, so it gets the same badge color.
        return AppColors.primary;
    }
  }

  String _kindLabel(SessionKind kind, int sessionNumber) {
    switch (kind) {
      case SessionKind.exam:
        return 'اختبار';
      case SessionKind.sard:
        return 'سرد';
      case SessionKind.talqeen:
        // Unlike a lesson, a تلقين is not labelled by its session number —
        // calling it 'حلقة $sessionNumber' here would misname it as an
        // ordinary lesson in the exact UI meant to show what the student is
        // truly standing on.
        return 'تلقين';
      case SessionKind.lesson:
        return 'حلقة $sessionNumber';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

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
          Icon(icon, size: 14, color: AppColors.textSecondary),
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

/// Small text badge naming the institute a student belongs to. Text-based
/// (not colour-only) so the affiliation is accessible. Shown on student
/// cards when a list spans more than one institute — see #53.
class _InstituteBadge extends StatelessWidget {
  final String name;

  const _InstituteBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
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
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
      trailing:
          trailing ??
          const Icon(Icons.chevron_left, color: AppColors.textSecondary),
    );
  }
}
