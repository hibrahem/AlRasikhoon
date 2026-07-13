import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../providers/supervisor_provider.dart';

class ExamSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const ExamSessionScreen({super.key, required this.studentId});

  @override
  ConsumerState<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends ConsumerState<ExamSessionScreen> {
  int _errorCount = 0;

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(examStudentProvider(widget.studentId));
    // WHAT is being examined comes from the curriculum session the student
    // stands on — its verbatim label and its tier — never from a hizb: the
    // juz-30 اختبار covers a whole juz, and the level's اختبار covers three.
    final session = ref.watch(examSessionProvider(widget.studentId)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبار'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showExitConfirmation();
          },
        ),
      ),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }

          final student = studentWithUser.student;
          final user = studentWithUser.user;

          return Column(
            children: [
              // Student and exam info
              AppCard(
                margin: const EdgeInsets.all(16),
                backgroundColor: AppColors.secondary.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.secondary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0] : '?',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
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
                                session?.titleAr ??
                                    'اختبار — الجزء ${student.currentJuz}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                session?.scopeAr ??
                                    'الجزء ${student.currentJuz}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 20,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              session?.assessmentInstructionAr ??
                                  'يختبر المشرف الطالب في المقرر',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Error counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorCounter(
                  errorCount: _errorCount,
                  onAddError: () {
                    setState(() => _errorCount++);
                  },
                  onUndoError: () {
                    if (_errorCount > 0) {
                      setState(() => _errorCount--);
                    }
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Action button
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  text: 'إنهاء الاختبار',
                  onPressed: () {
                    context.push(
                      AppRoutes.examResult.replaceFirst(
                        ':studentId',
                        widget.studentId,
                      ),
                      extra: _errorCount,
                    );
                  },
                  isFullWidth: true,
                  size: AppButtonSize.large,
                  backgroundColor: AppColors.secondary,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الاختبار؟'),
        content: const Text('هل تريد إلغاء الاختبار الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}
