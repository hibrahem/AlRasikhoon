import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// Kept only for the memorization-mode accent system (kNewColor,
// textOnPrimary) — see the comment above `modeColor` below. These are fixed,
// colorblind-safe, WCAG-AA-verified colors (hibrahem/AlRasikhoon#25), not
// theme-adaptive tokens, so they intentionally stay raw.
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/teacher_provider.dart';
import '../widgets/active_lesson_timer.dart';

class NewMemorizationScreen extends ConsumerWidget {
  final String studentId;

  const NewMemorizationScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final meetingAsync = ref.watch(studentCurrentMeetingProvider(studentId));

    // This is the standalone "new memorization" (الجديد) mode screen, so it
    // carries the same part-1 ink as everywhere else (tokens.partNew,
    // hibrahem/AlRasikhoon#25). The colored app-bar slab is gone with the
    // redesign — the ink lives on the card identity below.
    final modeColor = tokens.partNew;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ الجديد'),
        actions: [ActiveLessonTimer(studentId: studentId)],
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
                          IconMedallion(
                            icon: Icons.auto_stories,
                            accent: modeColor,
                            size: 48,
                            iconSize: 24,
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
                                      ?.copyWith(color: tokens.sepia),
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
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل الحلقة: $e'),
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
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.sepia),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
          ),
          const Spacer(),
          Text(
            value,
            // A Qur'an range — set in Amiri, the manuscript face passages
            // carry across the design system.
            style: GoogleFonts.amiri(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tokens.ink,
            ),
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
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: tokens.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: tokens.green,
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
