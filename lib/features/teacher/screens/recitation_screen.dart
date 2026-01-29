import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/error_counter.dart';
import '../providers/teacher_provider.dart';

class RecitationScreen extends ConsumerStatefulWidget {
  final String studentId;
  final int part;

  const RecitationScreen({
    super.key,
    required this.studentId,
    required this.part,
  });

  @override
  ConsumerState<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends ConsumerState<RecitationScreen> {
  int _errorCount = 0;

  String get _partTitle {
    switch (widget.part) {
      case 1:
        return 'الحفظ الجديد';
      case 2:
        return 'المراجعة القريبة';
      case 3:
        return 'المراجعة البعيدة';
      default:
        return 'التسميع';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(studentCurrentSessionProvider(widget.studentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_partTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _showExitConfirmation();
          },
        ),
      ),
      body: sessionAsync.when(
        data: (session) {
          if (session == null) {
            return const Center(child: Text('لا توجد بيانات'));
          }

          String content;
          switch (widget.part) {
            case 1:
              content = session.currentLevelContent.rangeAr;
              break;
            case 2:
              content = session.recentReviewContent.rangeAr;
              break;
            case 3:
              content = session.distantReviewContent.rangeAr;
              break;
            default:
              content = '';
          }

          return Column(
            children: [
              // Content card
              AppCard(
                margin: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'الجزء ${widget.part} من 3',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _partTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.menu_book,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              content.isNotEmpty ? content : 'لا يوجد محتوى',
                              style: Theme.of(context).textTheme.bodyLarge,
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

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (widget.part > 1)
                      Expanded(
                        child: AppButton(
                          text: 'السابق',
                          onPressed: () {
                            // Save current part errors
                            ref
                                .read(activeSessionProvider.notifier)
                                .setPartErrors(widget.part, _errorCount);

                            context.pop();
                          },
                          type: AppButtonType.outline,
                        ),
                      ),
                    if (widget.part > 1) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: widget.part < 3 ? 'التالي' : 'إنهاء التسميع',
                        onPressed: () {
                          // Save current part errors
                          ref
                              .read(activeSessionProvider.notifier)
                              .setPartErrors(widget.part, _errorCount);

                          // Navigate to result or next part
                          context.push(
                            AppRoutes.recitationResult
                                .replaceFirst(':studentId', widget.studentId)
                                .replaceFirst(':part', '${widget.part}'),
                            extra: _errorCount,
                          );
                        },
                      ),
                    ),
                  ],
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
        title: const Text('إلغاء الحلقة؟'),
        content: const Text('هل تريد إلغاء الحلقة الحالية؟ سيتم فقدان التقدم.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(activeSessionProvider.notifier).endSession();
              Navigator.pop(context);
              context.go(AppRoutes.teacherStudents);
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
