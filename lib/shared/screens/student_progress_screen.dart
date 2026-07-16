import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/curriculum/paced_session.dart';
import '../../domain/session/student_history_entry.dart';
import '../curriculum/assessment_copy.dart';
import '../widgets/app_card.dart';
import '../widgets/student_level_progress.dart';

/// Read-only student progress view. Mirrors what a teacher sees for their own
/// student in `StudentProfileScreen`, but never offers any action that would
/// start, advance, or end a session.
///
/// Role-agnostic by construction: the three providers it reads are INJECTED by
/// the router (the composition root), so the admin gets its unscoped providers
/// and the supervisor its institute-scoped ones (AgDR-0003) without this screen
/// importing either feature.
class StudentProgressScreen extends ConsumerWidget {
  final String studentId;
  final FutureProviderFamily<StudentWithUser?, String> studentProvider;
  final FutureProviderFamily<PacedSession?, String> currentMeetingProvider;
  final FutureProviderFamily<List<StudentHistoryEntry>, String>
  sessionHistoryProvider;

  /// The session-detail route template (containing `:recordId`) for the shell
  /// this screen is mounted in. INJECTED by the router for the same reason the
  /// providers are: tapping a history record must open the detail view WITHIN
  /// the active shell, never cross into the student shell (al_rasikhoon-3hn).
  final String sessionDetailRoute;

  /// An optional role-specific section rendered under the header, INJECTED by
  /// the router like everything else so this screen stays role-agnostic. The
  /// supervisor shell passes the "edit starting point" affordance
  /// (al_rasikhoon-sne) here; the admin shell passes nothing. The widget owns
  /// its own visibility (it hides itself once the student has started), so this
  /// screen neither knows the rule nor imports the supervisor feature.
  final Widget? repositionSection;

  /// An optional role-specific pace control rendered under the header, INJECTED
  /// by the router like [repositionSection]. The supervisor shell passes a
  /// [StudentPaceControl] here (a supervisor scoped to the student's institute
  /// may set pace — firestore.rules already authorises it); the admin shell
  /// passes nothing and stays read-only. This screen never knows the rule nor
  /// imports the supervisor feature.
  ///
  /// A BUILDER, not a plain widget: the pace control needs the student's
  /// current pace, known only once the student has loaded — so the screen
  /// calls this with the loaded [StudentModel].
  final Widget Function(StudentModel student)? paceSection;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.studentProvider,
    required this.currentMeetingProvider,
    required this.sessionHistoryProvider,
    required this.sessionDetailRoute,
    this.repositionSection,
    this.paceSection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('تقدم الطالب')),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(studentId));
              ref.invalidate(currentMeetingProvider(studentId));
              ref.invalidate(sessionHistoryProvider(studentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _ProgressBody(
                studentWithUser: studentWithUser,
                currentMeetingProvider: currentMeetingProvider,
                sessionHistoryProvider: sessionHistoryProvider,
                sessionDetailRoute: sessionDetailRoute,
                repositionSection: repositionSection,
                paceSection: paceSection,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  final StudentWithUser studentWithUser;
  final FutureProviderFamily<PacedSession?, String> currentMeetingProvider;
  final FutureProviderFamily<List<StudentHistoryEntry>, String>
  sessionHistoryProvider;
  final String sessionDetailRoute;
  final Widget? repositionSection;
  final Widget Function(StudentModel student)? paceSection;

  const _ProgressBody({
    required this.studentWithUser,
    required this.currentMeetingProvider,
    required this.sessionHistoryProvider,
    required this.sessionDetailRoute,
    this.repositionSection,
    this.paceSection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;
    final meetingAsync = ref.watch(currentMeetingProvider(student.id));
    final historyAsync = ref.watch(sessionHistoryProvider(student.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudentHeaderCard(user: user, student: student),
        if (repositionSection != null) ...[
          const SizedBox(height: 16),
          repositionSection!,
        ],
        if (paceSection != null) ...[
          const SizedBox(height: 16),
          paceSection!(student),
        ],
        const SizedBox(height: 24),

        Text('الحلقة الحالية', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        meetingAsync.when(
          data: (meeting) => _CurrentSessionCard(meeting: meeting),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 24),

        Text(
          'التقدم في المستوى',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: StudentLevelProgress(
            level: student.currentLevel,
            orderInLevel: student.currentOrderInLevel,
          ),
        ),

        const SizedBox(height: 24),

        Text('سجل الحلقات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        historyAsync.when(
          data: (entries) => _SessionHistoryList(
            entries: entries,
            sessionDetailRoute: sessionDetailRoute,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _StudentHeaderCard extends StatelessWidget {
  final UserModel user;
  final StudentModel student;

  const _StudentHeaderCard({required this.user, required this.student});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'المستوى ${student.currentLevel} - الجزء ${student.currentJuz}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (student.currentAttempt > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'المحاولة ${student.currentAttempt}',
                style: const TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

/// The MEETING the student stands on, described by the CURRICULUM — the
/// student record is not consulted at all, because the curriculum is the
/// authority on what the meeting is. A batch (a 2x/3x student) merges into
/// one card, exactly like the teacher's `StudentProfileScreen`: showing
/// only the meeting's first session would silently understate a fast
/// student's assignment.
class _CurrentSessionCard extends StatelessWidget {
  final PacedSession? meeting;

  const _CurrentSessionCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final meeting = this.meeting;
    if (meeting == null) {
      return const AppCard(child: Center(child: Text('لا توجد بيانات للحلقة')));
    }

    // The meeting's KIND is the kind of the session it starts on — a batch is
    // all lessons, so they agree. What this session IS comes from the
    // curriculum's own `kind`, never from its number.
    //
    // The تلقين branch MUST come before isExam/isSard and the regular-lesson
    // fallthrough (see student_profile_screen.dart's identical ordering): a
    // تلقين is neither an assessment nor a graded lesson — falling through to
    // the lesson card would show a supervisor "الحفظ الجديد" (new
    // memorization) framing and part tiles for a session that is graded on
    // nothing and cannot be failed.
    final session = meeting.first;
    if (session.isTalqeen) {
      return _SimpleSessionCard(
        icon: Icons.record_voice_over,
        color: AppColors.primary,
        title: session.titleAr,
        subtitle:
            'يقرأ المعلّم المقطع على الطالب ويردده معه. لا تسميع ولا تقييم '
            'في هذه الحلقة.',
      );
    }
    if (session.isExam) {
      return _SimpleSessionCard(
        icon: Icons.quiz,
        color: AppColors.secondary,
        title: session.titleAr,
        subtitle: 'في انتظار المشرف لإجراء الاختبار',
      );
    }
    if (session.isSard) {
      return _SimpleSessionCard(
        icon: Icons.record_voice_over,
        color: AppColors.info,
        title: session.titleAr,
        subtitle: session.assessmentInstructionAr,
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحلقة ${session.sessionNumber}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      // Never an app-derived hizb — level 2's structural hizb
                      // is known to disagree with the source text for the
                      // same session. The juz is always consistent.
                      'الجزء ${session.juzNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // A content block may legitimately be absent (review-only lessons
          // carry no new memorization) — absence reads as '-'. A batched
          // meeting's lines already merge contiguous ranges and de-duplicate
          // (see `PacedSession._line`), so a 2x/3x student's whole meeting
          // renders here, not just its first session.
          _PartTile(
            number: 1,
            title: 'الحفظ الجديد',
            content: meeting.newContentAr,
          ),
          const SizedBox(height: 8),
          _PartTile(
            number: 2,
            title: 'المراجعة القريبة',
            content: meeting.recentReviewAr,
          ),
          const SizedBox(height: 8),
          _PartTile(
            number: 3,
            title: 'المراجعة البعيدة',
            content: meeting.distantReviewAr,
          ),
        ],
      ),
    );
  }
}

class _SimpleSessionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _SimpleSessionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: color.withValues(alpha: 0.05),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  subtitle,
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

class _PartTile extends StatelessWidget {
  final int number;
  final String title;
  final String content;

  const _PartTile({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  content.isNotEmpty ? content : '-',
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

class _SessionHistoryList extends StatelessWidget {
  final List<StudentHistoryEntry> entries;
  final String sessionDetailRoute;

  const _SessionHistoryList({
    required this.entries,
    required this.sessionDetailRoute,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            const Text('لا يوجد سجل للحلقات'),
          ],
        ),
      );
    }
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        // A تلقين is never graded — no pass/fail, no errors — so it must
        // never render with a pass/fail badge, even though
        // `createTalqeenRecord` writes `passed: true` unconditionally (that
        // flag exists for the stats query, not for display). Listing shows
        // only a binary pass/fail (نجح / رسب) for a graded record, never an
        // average of the three component grades (#24). The per-component
        // breakdown lives in the session detail view. Mirrors
        // `session_history_screen.dart`'s student-facing list.
        final isTalqeen = entry.isTalqeen;
        final badgeColor = isTalqeen
            ? AppColors.primary
            : (entry.passed ? AppColors.success : AppColors.error);
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          // A سرد / اختبار has no detail screen yet, so its row renders but
          // does not navigate (entry.isNavigable is false).
          onTap: entry.isNavigable
              ? () => context.push(
                  sessionDetailRoute.replaceFirst(
                    ':recordId',
                    entry.detailRecordId!,
                  ),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isTalqeen
                      ? Icons.record_voice_over
                      : (entry.passed ? Icons.check_circle : Icons.cancel),
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.titleAr,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final line in entry.subtitleLines)
                      Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    Text(
                      dateFormat.format(entry.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  isTalqeen ? 'تلقين' : (entry.passed ? 'نجح' : 'رسب'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
