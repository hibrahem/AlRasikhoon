import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../data/repositories/student_repository.dart';
import 'institute_badge.dart';
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

  /// Optional widget at the end of the header row (e.g. a ⋮ actions button on
  /// the teacher roster). Keeps card actions discoverable without gestures.
  final Widget? trailing;

  const StudentCard({
    super.key,
    required this.studentWithUser,
    this.onTap,
    this.showProgress = true,
    this.showSession = true,
    this.instituteName,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final student = studentWithUser.student;
    final user = studentWithUser.user;
    final level = ref.watch(levelProvider(student.currentLevel)).value;
    final sessionCount = level?.sessionCount ?? 0;
    final progress = sessionCount > 0
        ? (student.currentOrderInLevel - 1).clamp(0, sessionCount) /
              sessionCount
        : 0.0;

    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        boxShadow: AppShadows.card(brightness),
        border: brightness == Brightness.dark
            ? Border.all(color: tokens.rewardDim)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name and level. Top-aligned so the kind chip and
                // actions hug the name line instead of floating in the
                // vertical middle of a three-line column (dead-space bug).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      backgroundColor: tokens.green.withValues(alpha: 0.1),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0] : '?',
                        style: TextStyle(
                          color: tokens.green,
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
                                ?.copyWith(color: tokens.sepia),
                          ),
                          if (instituteName != null &&
                              instituteName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            InstituteBadge(name: instituteName!),
                          ],
                          // A teacher-less student is in no teacher's
                          // getStudentsForTeacher list, so nobody can conduct
                          // their حلقة or their سرد — surfaced here so a
                          // supervisor can find and rescue them
                          // (al_rasikhoon-6bw).
                          if (student.teacherId == null) ...[
                            const SizedBox(height: 4),
                            const _TeacherlessBadge(),
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
                            tokens,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _kindColor(
                              student.currentSessionKind,
                              tokens,
                            ),
                          ),
                        ),
                        child: Text(
                          _kindLabel(
                            student.currentSessionKind,
                            student.currentSession,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _kindColor(
                              student.currentSessionKind,
                              tokens,
                            ),
                          ),
                        ),
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),

                if (showProgress) ...[
                  const SizedBox(height: 12),
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
                  // real session count, from the catalog — never `/ 36`. The
                  // count (current/total) mirrors the level-progress figure the
                  // student detail screen shows, so a teacher sees how far into
                  // the level a student is — and how far is left — without
                  // opening the card.
                  Row(
                    children: [
                      Expanded(
                        child: ProgressBar(
                          progress: progress,
                          height: 6,
                          showPercentage: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sessionCount > 0
                            ? '${student.currentOrderInLevel}/$sessionCount'
                            : '—',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tokens.sepia,
                        ),
                      ),
                    ],
                  ),
                ],

                // Attempt indicator if not first attempt. A repeat attempt
                // means a failed سرد/lesson behind it — attention/needs-review
                // is maroon in the manuscript palette, matching the attempt
                // badge on the student profile.
                if (student.currentAttempt > 1) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.maroon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'المحاولة ${student.currentAttempt}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.maroon,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _kindColor(SessionKind kind, AppTokens tokens) {
    switch (kind) {
      case SessionKind.exam:
        return tokens.gold;
      case SessionKind.sard:
        // سرد wears maroon — the palette's rubrication/attention hue — as on
        // the student dashboard's ticket card; the legacy "info" blue has no
        // place in the manuscript palette.
        return tokens.maroon;
      case SessionKind.talqeen:
      case SessionKind.lesson:
        // A تلقين teaches new content like a lesson does and is never
        // assessed, so it gets the same badge color.
        return tokens.green;
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tokens.sepia),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: tokens.sepia)),
        ],
      ),
    );
  }
}

/// Marks a student with no `teacher_id` (al_rasikhoon-6bw). A teacher-less
/// student is invisible to every teacher's roster query, so nobody can ever
/// conduct their حلقة or their سرد — this badge is how a supervisor finds
/// them to assign a teacher. Text-based (not colour-only) for accessibility.
class _TeacherlessBadge extends StatelessWidget {
  const _TeacherlessBadge();

  @override
  Widget build(BuildContext context) {
    // Gold: this is an attention flag for the supervisor, not a failure —
    // maroon is reserved for needs-review/failed outcomes.
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: tokens.gold),
          const SizedBox(width: 4),
          Text(
            'بلا معلم',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.gold,
              fontWeight: FontWeight.w500,
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
    final tokens = context.tokens;
    final student = studentWithUser.student;
    final user = studentWithUser.user;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tokens.green.withValues(alpha: 0.1),
        child: Text(
          user.name.isNotEmpty ? user.name[0] : '?',
          style: TextStyle(color: tokens.green, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(user.name),
      subtitle: Text(
        'المستوى ${student.currentLevel} - الحلقة ${student.currentSession}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: trailing ?? Icon(Icons.chevron_left, color: tokens.sepia),
    );
  }
}
