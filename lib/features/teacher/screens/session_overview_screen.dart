import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../providers/teacher_provider.dart';

class SessionOverviewScreen extends ConsumerWidget {
  final String studentId;

  const SessionOverviewScreen({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));
    final sessionAsync = ref.watch(studentCurrentSessionProvider(studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحلقة'),
      ),
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
                        backgroundColor: AppColors.primary.withOpacity(0.1),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
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
                            color: AppColors.warning.withOpacity(0.1),
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
                        child: Center(
                          child: Text('لا توجد بيانات للحلقة'),
                        ),
                      );
                    }

                    // Check session type
                    final isSard = student.currentSession ==
                        AppConstants.sardSessionNumber;
                    final isExam = student.currentSession ==
                        AppConstants.examSessionNumber;

                    if (isExam) {
                      return _buildExamCard(context, student);
                    }

                    if (isSard) {
                      return _buildSardCard(context, student, studentId);
                    }

                    return _buildRegularSessionCard(
                        context, session, student, studentId, ref);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),

                const SizedBox(height: 24),

                // Progress section
                Text(
                  'التقدم في الحزب',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: LevelProgressBar(
                    currentSession: student.currentSession,
                    totalSessions: 36,
                    completedHizbs: 0, // TODO: Calculate from completed levels
                    totalHizbs: 6,
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
    dynamic session,
    dynamic student,
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الحلقة ${student.currentSession}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'الحزب ${student.currentHizb}',
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

          // Three parts
          _SessionPartTile(
            number: 1,
            title: 'الحفظ الجديد',
            content: session.currentLevelContent.rangeAr,
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 2,
            title: 'المراجعة القريبة',
            content: session.recentReviewContent.rangeAr,
          ),
          const SizedBox(height: 8),
          _SessionPartTile(
            number: 3,
            title: 'المراجعة البعيدة',
            content: session.distantReviewContent.rangeAr,
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
                ref.read(activeSessionProvider.notifier).startSession(studentId);
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
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSardCard(
      BuildContext context, dynamic student, String studentId) {
    return AppCard(
      backgroundColor: AppColors.info.withOpacity(0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
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
                      'سرد الحزب ${student.currentHizb}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'سرد كامل الحزب من الذاكرة',
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
          // Check if max Sard attempts reached
          if (student.hasReachedMaxSardAttempts)
            _buildMaxAttemptsReachedMessage(context)
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

  Widget _buildExamCard(BuildContext context, dynamic student) {
    return AppCard(
      backgroundColor: AppColors.secondary.withOpacity(0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختبار الحزب ${student.currentHizb}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'يحتاج الطالب للاختبار مع المشرف',
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
              color: AppColors.warning.withOpacity(0.1),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
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

  const _SessionPartTile({
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
              color: AppColors.primary.withOpacity(0.1),
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
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
