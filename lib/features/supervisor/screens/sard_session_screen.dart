import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../../teacher/providers/teacher_provider.dart';

class SardSessionScreen extends ConsumerStatefulWidget {
  final String studentId;

  const SardSessionScreen({
    super.key,
    required this.studentId,
  });

  @override
  ConsumerState<SardSessionScreen> createState() => _SardSessionScreenState();
}

class _SardSessionScreenState extends ConsumerState<SardSessionScreen> {
  int _errorCount = 0;

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentProvider(widget.studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('السرد'),
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

          return Column(
            children: [
              // Info card
              AppCard(
                margin: const EdgeInsets.all(16),
                backgroundColor: AppColors.info.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'الجزء ${student.currentJuz}',
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
                      ],
                    ),
                    const SizedBox(height: 16),
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
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يقوم الطالب بسرد كامل الحزب من الذاكرة دون النظر للمصحف',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.info,
                                  ),
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
                  text: 'إنهاء السرد',
                  onPressed: () {
                    context.push(
                      AppRoutes.sardResult
                          .replaceFirst(':studentId', widget.studentId),
                      extra: _errorCount,
                    );
                  },
                  isFullWidth: true,
                  size: AppButtonSize.large,
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
        title: const Text('إلغاء السرد؟'),
        content: const Text('هل تريد إلغاء السرد الحالي؟'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}
