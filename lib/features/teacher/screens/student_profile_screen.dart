import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Kept only for the memorization-mode accent system
// (forMemorizationPart) used by _SessionPartTile below. Fixed,
// colorblind-safe, WCAG-AA-verified colors (hibrahem/AlRasikhoon#25), not
// theme-adaptive tokens, so they intentionally stay raw.
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../domain/session/session_duration.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/session_record_row.dart';
import '../../../shared/widgets/student_pace_control.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_level_progress.dart';
import '../providers/teacher_provider.dart';

/// A teacher's single view of one student: identity (name + username), level,
/// pace, the current session (which can be started from here), level progress,
/// and that student's session history — all in one place (al_rasikhoon-pb7).
/// The history was previously a separate teacher-wide tab; it now lives here,
/// scoped to this student, so the teacher sees the whole picture at once.
class StudentProfileScreen extends ConsumerWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The supervisor no longer reaches this screen: as of al_rasikhoon-801 the
    // TEACHER conducts the سرد in the teacher shell, and a supervisor gets the
    // read-only StudentProgressScreen instead. So there is no `asSupervisor`
    // branch to keep here — this screen is the teacher's.
    final studentAsync = ref.watch(studentProvider(studentId));
    final meetingAsync = ref.watch(studentCurrentMeetingProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('ملف الطالب')),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }

          final student = studentWithUser.student;
          final user = studentWithUser.user;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(studentId));
              ref.invalidate(studentCurrentMeetingProvider(studentId));
              ref.invalidate(teacherStudentSessionHistoryProvider(studentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Identity: name, username, level/juz.
                  _StudentHeaderCard(user: user, student: student),

                  const SizedBox(height: 24),

                  // Pace control — either a teacher or a supervisor may set it,
                  // and it may change mid-level; there is no approval workflow.
                  // The same control the supervisor sees, invalidating the
                  // teacher's own caches on a change (see _onPaceChanged).
                  StudentPaceControl(
                    studentId: student.id,
                    currentPace: student.pace,
                    onPaceChanged: (ref) => _onPaceChanged(ref, student.id),
                  ),

                  const SizedBox(height: 24),

                  // Current session info
                  Text(
                    'الحلقة الحالية',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  meetingAsync.when(
                    data: (meeting) {
                      if (meeting == null) {
                        return const AppCard(
                          child: Center(child: Text('لا توجد بيانات للحلقة')),
                        );
                      }

                      // The meeting's KIND is the kind of the session it
                      // starts on — a batch is all lessons, so they agree. What
                      // this session IS comes from the curriculum's own `kind`,
                      // never from its number: session 35 of juz 30 is an
                      // ordinary lesson, and the juz-30 اختبار is session 68.
                      //
                      // The تلقين branch MUST come before isExam/isSard and the
                      // regular-lesson fallthrough: a تلقين is neither an
                      // assessment nor a graded lesson, and falling through would
                      // start it as one.
                      final session = meeting.first;

                      if (session.isTalqeen) {
                        return _buildTalqeenCard(
                          context,
                          meeting,
                          studentId,
                          ref,
                        );
                      }

                      if (session.isExam) {
                        return _buildExamCard(context, session);
                      }

                      if (session.isSard) {
                        // سرد is conducted by the TEACHER (al_rasikhoon-801), and
                        // only a teacher reaches this screen.
                        return _buildSardCard(context, session, studentId);
                      }

                      return _buildRegularSessionCard(
                        context,
                        meeting,
                        student,
                        studentId,
                        ref,
                      );
                    },
                    loading: () => const LoadingState(),
                    error: (e, _) =>
                        ErrorState(message: 'تعذر تحميل الحلقة: $e'),
                  ),

                  const SizedBox(height: 24),

                  // Progress section — measured against the level's real
                  // session count, from the levels catalog.
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

                  // Session history — this student's past sessions, embedded
                  // (al_rasikhoon-pb7). Moved here from the teacher-wide history
                  // tab so the teacher sees a student's record in context, and
                  // tapping a row opens that record's detail within the same
                  // (Students) shell branch.
                  Text(
                    'سجل الحلقات',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _SessionHistorySection(studentId: studentId),
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل الطالب: $e'),
      ),
    );
  }

  /// Refresh the teacher's caches after a pace change.
  ///
  /// The student stores where a meeting STARTS, never how far it extends — the
  /// new pace only widens the pending meeting once the student is RE-READ FROM
  /// FIRESTORE.
  ///
  /// `studentProvider` is derived: it picks the student out of the list
  /// `teacherStudentsProvider` already fetched. Invalidating it alone re-runs
  /// its body against that CACHED list — the same student, still carrying the
  /// old pace — so the meeting recomposes from stale data and the teacher sees
  /// no change at all. The source has to be invalidated too, which is exactly
  /// what `completeSession` does after it writes.
  void _onPaceChanged(WidgetRef ref, String studentId) {
    ref.invalidate(teacherStudentsProvider);
    ref.invalidate(studentProvider(studentId));
  }

  Widget _buildRegularSessionCard(
    BuildContext context,
    PacedSession meeting,
    StudentModel student,
    String studentId,
    WidgetRef ref,
  ) {
    final tokens = context.tokens;
    final session = meeting.first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book, color: tokens.green),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
            content: meeting.newContentAr,
            accent: AppColors.forMemorizationPart(1),
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 2,
            title: 'المراجعة القريبة',
            content: meeting.recentReviewAr,
            accent: AppColors.forMemorizationPart(2),
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 3,
            title: 'المراجعة البعيدة',
            content: meeting.distantReviewAr,
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

  /// The تلقين card. No error counters, no grade, no pass/fail — a تلقين
  /// cannot be failed, so there is no attempt cap to gate the start button on
  /// either: it cannot be exhausted.
  Widget _buildTalqeenCard(
    BuildContext context,
    PacedSession meeting,
    String studentId,
    WidgetRef ref,
  ) {
    final tokens = context.tokens;
    final session = meeting.first;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.record_voice_over, color: tokens.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تلقين',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'الجزء ${session.juzNumber}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'المقطع الجديد',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(height: 4),
          Text(
            meeting.newContentAr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'يقرأ المعلّم المقطع على الطالب ويردده معه. لا تسميع ولا تقييم في '
            'هذه الحلقة.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          // No attempt cap: a تلقين cannot be failed, so it cannot be exhausted.
          AppButton(
            text: 'بدء التلقين',
            onPressed: () {
              ref.read(activeSessionProvider.notifier).startSession(studentId);
              context.push(
                AppRoutes.talqeenSession.replaceFirst(':studentId', studentId),
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.maroon.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.maroon.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: tokens.maroon, size: 32),
          const SizedBox(height: 12),
          Text(
            'تم استنفاد جميع المحاولات',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: tokens.maroon,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الطالب استخدم ${AppConstants.maxSessionAttempts} محاولات.\nيرجى التواصل مع المشرف للمساعدة.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
  ) {
    final tokens = context.tokens;
    // No manuscript token maps directly to the old "info" blue, so —
    // matching the same سرد card on the student dashboard
    // (student_dashboard_screen.dart) and on sard_session_screen.dart —
    // this uses tokens.maroon, the palette's rubrication/emphasis hue, as
    // its own distinct accent.
    return AppCard(
      backgroundColor: tokens.maroon.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.maroon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.record_voice_over, color: tokens.maroon),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Assessments have UNLIMITED retries, so there is no attempt cap to
          // gate on here — a student who cannot yet recite a juz keeps at it.
          AppButton(
            text: 'بدء السرد',
            onPressed: () {
              context.push(
                AppRoutes.sardSession.replaceFirst(':studentId', studentId),
              );
            },
            isFullWidth: true,
            backgroundColor: tokens.maroon,
            icon: Icons.play_arrow,
          ),
        ],
      ),
    );
  }

  /// The اختبار card — titled and worded from the assessment's own scope, so a
  /// teacher can see WHAT the supervisor will assess: this hizb, this juz, or
  /// the level so far.
  Widget _buildExamCard(BuildContext context, SessionModel session) {
    final tokens = context.tokens;
    return AppCard(
      backgroundColor: tokens.gold.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.quiz, color: tokens.gold),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
              // No manuscript token for "warning" — maroon (the palette's
              // rubrication/emphasis hue) carries the warning/emphasis role
              // across these teacher screens, so the exam-referral notice
              // reuses it. It does not collide with the gold exam-card
              // identity above.
              color: tokens.maroon.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: tokens.maroon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'يرجى توجيه الطالب للمشرف لإجراء الاختبار',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.maroon),
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Identity block: avatar, name, username, and the current level/juz — plus the
/// attempt badge when the student is on a retry. The username is shown only
/// when present: accounts that predate the username field carry an empty one,
/// and a blank "اسم المستخدم:" line would read as missing data rather than
/// absent by design.
class _StudentHeaderCard extends StatelessWidget {
  final UserModel user;
  final StudentModel student;

  const _StudentHeaderCard({required this.user, required this.student});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: tokens.green.withValues(alpha: 0.1),
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: TextStyle(
                color: tokens.green,
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
                if (user.username.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'اسم المستخدم: ${user.username}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'المستوى ${student.currentLevel} - الجزء ${student.currentJuz}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
              ],
            ),
          ),
          if (student.currentAttempt > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.maroon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'المحاولة ${student.currentAttempt}',
                style: TextStyle(fontSize: 11, color: tokens.maroon),
              ),
            ),
        ],
      ),
    );
  }
}

/// This student's session history, embedded in the profile (al_rasikhoon-pb7).
/// Rows are identified by session (not by student, since it is one student's
/// list) and reuse [SessionRecordRow], the same row the student's own history
/// and the former teacher-wide history used. Tapping a row opens that record's
/// detail via [AppRoutes.teacherSessionDetail] — registered in the same
/// (Students) shell branch, so the push never crosses a shell boundary
/// (al_rasikhoon-3hn).
class _SessionHistorySection extends ConsumerWidget {
  final String studentId;

  const _SessionHistorySection({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      teacherStudentSessionHistoryProvider(studentId),
    );

    return historyAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const AppCard(
            child: Center(child: Text('لا يوجد سجل للحلقات')),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            // Listing shows only binary pass/fail (نجح / رسب), never an
            // average of the three component grades (#24); the per-component
            // breakdown lives in the session detail. Enforced by
            // SessionRecordRow, shared with the student's own history — which
            // also owns the rule that a تلقين shows no outcome at all.
            return SessionRecordRow(
              isTalqeen: record.isTalqeen,
              title: record.isTalqeen
                  ? 'تلقين'
                  : 'الحلقة ${record.sessionNumber}',
              subtitleLines: ['المستوى ${record.levelId}'],
              passed: record.passed,
              date: record.date,
              sessionDuration: SessionDuration.fromRecord(record),
              onTap: () {
                context.push(
                  AppRoutes.teacherSessionDetail.replaceFirst(
                    ':recordId',
                    record.id,
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: 'تعذر تحميل سجل الحلقات: $e'),
    );
  }
}
