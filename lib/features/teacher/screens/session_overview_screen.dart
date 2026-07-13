import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/student_model.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/student_level_progress.dart';
import '../../../shared/providers/user_provider.dart';
import '../../supervisor/providers/supervisor_provider.dart';
import '../providers/teacher_provider.dart';

class SessionOverviewScreen extends ConsumerWidget {
  final String studentId;

  /// When true, the student + current-session are resolved through the
  /// supervisor's institute scope (AgDR-0003) instead of the teacher-scoped
  /// `getStudentsForTeacher` lookup. A supervisor reaches this screen entirely
  /// within the supervisor shell (route `/supervisor/students/:studentId`), so
  /// the whole Students → session-overview → Sard flow stays in one shell — no
  /// cross-shell push (which trips the go_router duplicate-page-key crash, #45)
  /// — and supervisor-created students with `teacher_id: null` resolve.
  final bool asSupervisor;

  const SessionOverviewScreen({
    super.key,
    required this.studentId,
    this.asSupervisor = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = asSupervisor
        ? ref.watch(supervisorStudentProvider(studentId))
        : ref.watch(studentProvider(studentId));
    final sessionAsync = asSupervisor
        ? ref.watch(supervisorStudentCurrentSessionProvider(studentId))
        : ref.watch(studentCurrentSessionProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('الحلقة')),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }

          final student = studentWithUser.student;
          final user = studentWithUser.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student info card
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
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
                            Text(
                              user.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'المستوى ${student.currentLevel} - الجزء ${student.currentJuz}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (student.currentAttempt > 1)
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
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Current session info
                Text(
                  'الحلقة الحالية',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                sessionAsync.when(
                  data: (session) {
                    if (session == null) {
                      return const AppCard(
                        child: Center(child: Text('لا توجد بيانات للحلقة')),
                      );
                    }

                    // What this session IS comes from the curriculum's own
                    // `kind`, never from its number: session 35 of juz 30 is
                    // an ordinary lesson, and the juz-30 اختبار is session 68.
                    if (session.isExam) {
                      return _buildExamCard(context, session);
                    }

                    if (session.isSard) {
                      // Sard (السرد) is supervisor-only (#29). This screen is
                      // shared by teacher and supervisor students lists, so the
                      // entry point is gated by role: supervisors get the
                      // "Start Sard" action; teachers see a read-only notice
                      // and cannot start or navigate to a Sard session.
                      final isSupervisor = ref.watch(isSupervisorProvider);
                      return _buildSardCard(
                        context,
                        session,
                        studentId,
                        isSupervisor,
                      );
                    }

                    return _buildRegularSessionCard(
                      context,
                      session,
                      student,
                      studentId,
                      ref,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),

                const SizedBox(height: 24),

                // Progress section — measured against the level's real session
                // count, from the levels catalog.
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
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildRegularSessionCard(
    BuildContext context,
    SessionModel session,
    StudentModel student,
    String studentId,
    WidgetRef ref,
  ) {
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

          // Three parts — each carries its memorization-mode accent so the
          // new/near/far color association is learnable from the entry point
          // (hibrahem/AlRasikhoon#25). The Arabic title always accompanies the
          // accent, so the mode is never signalled by color alone.
          // A content block may legitimately be absent (five review-only
          // lessons carry no new memorization) — absence reads as '-'.
          _SessionPartTile(
            number: 1,
            title: 'الحفظ الجديد',
            content: session.currentLevelContent?.rangeAr ?? '',
            accent: AppColors.forMemorizationPart(1),
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 2,
            title: 'المراجعة القريبة',
            content: session.recentReviewContent?.rangeAr ?? '',
            accent: AppColors.forMemorizationPart(2),
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 3,
            title: 'المراجعة البعيدة',
            content: session.distantReviewContent?.rangeAr ?? '',
            accent: AppColors.forMemorizationPart(3),
          ),

          const SizedBox(height: 20),

          // Check if max attempts reached
          if (student.hasReachedMaxAttempts)
            _buildMaxAttemptsReachedMessage(context)
          else
            // Start session button
            AppButton(
              text: 'بدء الحلقة',
              onPressed: () {
                // Start session and navigate to recitation
                ref
                    .read(activeSessionProvider.notifier)
                    .startSession(studentId);
                context.push(
                  AppRoutes.recitation
                      .replaceFirst(':studentId', studentId)
                      .replaceFirst(':part', '1'),
                );
              },
              isFullWidth: true,
              icon: Icons.play_arrow,
            ),
        ],
      ),
    );
  }

  Widget _buildMaxAttemptsReachedMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'تم استنفاد جميع المحاولات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الطالب استخدم ${AppConstants.maxSessionAttempts} محاولات.\nيرجى التواصل مع المشرف للمساعدة.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// The سرد card. Its title is the curriculum's own words for the assessment
  /// (`scope.label_ar`) and its instruction is worded for the TIER — a juz-tier
  /// سرد covers a whole juz and a cumulative one up to three, so neither can be
  /// called "the hizb".
  Widget _buildSardCard(
    BuildContext context,
    SessionModel session,
    String studentId,
    bool isSupervisor,
  ) {
    return AppCard(
      backgroundColor: AppColors.info.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.record_voice_over,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.titleAr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      session.assessmentInstructionAr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Sard (السرد) is supervisor-only (#29). A teacher sees a read-only
          // notice — no "Start Sard" action, no navigation. Only a supervisor
          // gets the action. Assessments have UNLIMITED retries, so there is no
          // attempt cap to gate on here — a student who cannot yet recite a juz
          // keeps working at it.
          if (!isSupervisor)
            _buildSardSupervisorOnlyMessage(context)
          else
            AppButton(
              text: 'بدء السرد',
              onPressed: () {
                context.push(
                  AppRoutes.sardSession.replaceFirst(':studentId', studentId),
                );
              },
              isFullWidth: true,
              backgroundColor: AppColors.info,
              icon: Icons.play_arrow,
            ),
        ],
      ),
    );
  }

  Widget _buildSardSupervisorOnlyMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'السرد يُجرى مع المشرف فقط',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  /// The اختبار card — titled and worded from the assessment's own scope, so a
  /// teacher can see WHAT the supervisor will assess: this hizb, this juz, or
  /// the level so far.
  Widget _buildExamCard(BuildContext context, SessionModel session) {
    return AppCard(
      backgroundColor: AppColors.secondary.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.quiz, color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.titleAr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      session.assessmentInstructionAr,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يرجى توجيه الطالب للمشرف لإجراء الاختبار',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
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

class _SessionPartTile extends StatelessWidget {
  final int number;
  final String title;
  final String content;
  final Color accent;

  const _SessionPartTile({
    required this.number,
    required this.title,
    required this.content,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
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
