import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/providers/current_student_provider.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';
import '../widgets/home_practice_view.dart';

class HomePracticeScreen extends ConsumerStatefulWidget {
  const HomePracticeScreen({super.key});

  @override
  ConsumerState<HomePracticeScreen> createState() => _HomePracticeScreenState();
}

class _HomePracticeScreenState extends ConsumerState<HomePracticeScreen> {
  /// Validates and submits; the view resets its own form on true.
  Future<bool> _submitPractice(int repetitions, String? notes) async {
    final tokens = context.tokens;
    if (repetitions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إدخال عدد التكرارات'),
          backgroundColor: tokens.maroon,
        ),
      );
      return false;
    }

    final success = await ref
        .read(homePracticeNotifierProvider.notifier)
        .addPractice(repetitions: repetitions, notes: notes);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تسجيل التكرار بنجاح'),
          // AppColors.success has no direct AppTokens equivalent (not in
          // the task-16 mapping table). Following the Task 13/14
          // precedent, it maps to tokens.green — tokens.green and
          // AppColors.gradeRasikh are byte-identical, and green already
          // carries the "positive/affirmative" role elsewhere on this
          // screen (today's-repetitions stat, session-info accent).
          backgroundColor: tokens.green,
        ),
      );
    }
    return success;
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(homePracticeStatsProvider);
    final practicesAsync = ref.watch(studentHomePracticesProvider);
    final studentAsync = ref.watch(currentStudentProvider);
    final assignment = ref.watch(homeAssignmentProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('التكرار في المنزل')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homePracticeStatsProvider);
          ref.invalidate(studentHomePracticesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.all(16),
          child: statsAsync.when(
            loading: () => const LoadingState(),
            error: (_, _) => const SizedBox.shrink(),
            data: (stats) {
              final student = studentAsync.asData?.value;
              final practices = practicesAsync.asData?.value ?? const [];
              // Constructed only when there is history to format: DateFormat
              // throws before locale data is initialized, and an empty
              // history must not require it.
              final dateFormat = practices.isEmpty
                  ? null
                  : DateFormat('EEEE، d MMMM yyyy', 'ar');

              return HomePracticeView(
                data: HomePracticeData(
                  assignmentDone: assignment?.repetitionsDone,
                  assignmentRequired: assignment?.repetitionsRequired,
                  assignmentComplete: assignment?.isComplete ?? false,
                  todayRepetitions: stats.todayRepetitions,
                  streakDays: stats.streakDays,
                  totalRepetitions: stats.totalRepetitions,
                  // No per-day practice history is available client-side, so
                  // the beads render the streak itself: the last N days,
                  // today first, are lit.
                  weekBeads: List.generate(7, (i) => i < stats.streakDays),
                  sessionTitle: student != null
                      ? 'الحلقة ${student.currentSession}'
                      : null,
                  // Never an app-derived hizb: level 2's structural hizb can
                  // disagree with the assessment's own verbatim label
                  // (`scope.labelAr`) for the same session. The level and juz
                  // are always consistent with the data.
                  sessionSubtitle: student != null
                      ? 'المستوى ${student.currentLevel} - الجزء ${student.currentJuz}'
                      : null,
                  history: [
                    for (final practice in practices.take(10))
                      PracticeHistoryEntry(
                        repetitions: practice.repetitions,
                        title: 'الحلقة ${practice.sessionNumber}',
                        dateLabel: dateFormat!.format(practice.practiceDate),
                      ),
                  ],
                ),
                onSubmit: _submitPractice,
              );
            },
          ),
        ),
      ),
    );
  }
}
