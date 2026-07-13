import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../data/models/student_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/student_level_progress.dart';
import '../providers/admin_provider.dart';

/// Read-only student progress view for admins. Mirrors what a teacher sees
/// for their own student in [SessionOverviewScreen], but never offers any
/// action that would start, advance, or end a session.
class AdminStudentProgressScreen extends ConsumerWidget {
  final String studentId;

  const AdminStudentProgressScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(adminStudentProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('تقدم الطالب')),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminStudentProvider(studentId));
              ref.invalidate(adminStudentCurrentSessionProvider(studentId));
              ref.invalidate(adminStudentSessionHistoryProvider(studentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _ProgressBody(studentWithUser: studentWithUser),
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

  const _ProgressBody({required this.studentWithUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;
    final sessionAsync = ref.watch(
      adminStudentCurrentSessionProvider(student.id),
    );
    final historyAsync = ref.watch(
      adminStudentSessionHistoryProvider(student.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudentHeaderCard(user: user, student: student),
        const SizedBox(height: 24),

        Text('الحلقة الحالية', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        sessionAsync.when(
          data: (session) => _CurrentSessionCard(session: session),
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
          data: (records) => _SessionHistoryList(records: records),
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

/// The session the student stands on, described by the CURRICULUM — the student
/// record is not consulted at all, because the session document is the authority
/// on what the session is.
class _CurrentSessionCard extends StatelessWidget {
  final SessionModel? session;

  const _CurrentSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    if (session == null) {
      return const AppCard(child: Center(child: Text('لا توجد بيانات للحلقة')));
    }

    // A session's kind is read from the curriculum, never inferred from its
    // number; an assessment is named by the curriculum's own label and worded
    // for its tier (this hizb / this juz / the level so far).
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
                      session.hizbNumber != null
                          ? 'الجزء ${session.juzNumber} - الحزب ${session.hizbNumber}'
                          : 'الجزء ${session.juzNumber}',
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
          // carry no new memorization) — absence reads as '-'.
          _PartTile(
            number: 1,
            title: 'الحفظ الجديد',
            content: session.currentLevelContent?.rangeAr ?? '',
          ),
          const SizedBox(height: 8),
          _PartTile(
            number: 2,
            title: 'المراجعة القريبة',
            content: session.recentReviewContent?.rangeAr ?? '',
          ),
          const SizedBox(height: 8),
          _PartTile(
            number: 3,
            title: 'المراجعة البعيدة',
            content: session.distantReviewContent?.rangeAr ?? '',
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
  final List<SessionRecordModel> records;

  const _SessionHistoryList({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
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
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        // Listing shows only binary pass/fail (نجح / رسب), never an average
        // of the three component grades (#24). The per-component breakdown
        // lives in the session detail view.
        final passColor = record.passed ? AppColors.success : AppColors.error;
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          onTap: () => context.push(
            AppRoutes.sessionDetail.replaceFirst(':recordId', record.id),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: passColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record.passed ? Icons.check_circle : Icons.cancel,
                  color: passColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحلقة ${record.sessionNumber}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      record.hizbNumber != null
                          ? 'المستوى ${record.levelId} - الحزب ${record.hizbNumber}'
                          : 'المستوى ${record.levelId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      dateFormat.format(record.date),
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
                  color: passColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: passColor),
                ),
                child: Text(
                  record.passed ? 'نجح' : 'رسب',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: passColor,
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
