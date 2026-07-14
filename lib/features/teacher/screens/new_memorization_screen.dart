import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/teacher_provider.dart';

class NewMemorizationScreen extends ConsumerWidget {
  final String studentId;

  const NewMemorizationScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingAsync = ref.watch(studentCurrentMeetingProvider(studentId));

    // This is the standalone "new memorization" (الجديد) mode screen, so it
    // carries the same accent as part 1 elsewhere (hibrahem/AlRasikhoon#25).
    const modeColor = AppColors.kNewColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ الجديد'),
        backgroundColor: modeColor,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: meetingAsync.when(
        data: (meeting) {
          if (meeting == null) {
            return const Center(child: Text('لا توجد بيانات'));
          }

          // Assessments carry no new memorization, and five review-only lessons
          // carry none either: absence is data, and the screen says so instead
          // of dereferencing null. A batched meeting may draw its new content
          // from more than one curriculum row, which is why this is the
          // meeting's own merged range rather than one session's content block.
          if (!meeting.hasNewContent) {
            return const Center(child: Text('لا يوجد حفظ جديد في هذه الحلقة'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                AppCard(
                  backgroundColor: modeColor.withValues(alpha: 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: modeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_stories,
                              color: modeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'المقطع المطلوب حفظه',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  'للحلقة القادمة',
                                  style: Theme.of(context).textTheme.bodySmall
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
                      const Divider(),
                      const SizedBox(height: 12),
                      // A batch may cover more than one curriculum row, so
                      // this is the meeting's own merged range — never a
                      // single row's discrete from/to fields, which cannot
                      // represent two non-contiguous blocks.
                      _InfoRow(
                        icon: Icons.menu_book,
                        label: 'المقطع',
                        value: meeting.newContentAr,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                Text(
                  'تعليمات للطالب',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    children: [
                      _InstructionTile(
                        number: 1,
                        text: 'قراءة المقطع من المصحف مع التجويد',
                      ),
                      _InstructionTile(
                        number: 2,
                        text: 'تكرار المقطع حتى الإتقان',
                      ),
                      _InstructionTile(
                        number: 3,
                        text: 'المراجعة قبل النوم وبعد الاستيقاظ',
                      ),
                      _InstructionTile(
                        number: 4,
                        text: 'التسميع على أحد الوالدين',
                      ),
                    ],
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _InstructionTile extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
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
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
