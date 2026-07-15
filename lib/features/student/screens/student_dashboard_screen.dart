import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../routing/app_router.dart';
import '../../../shared/curriculum/assessment_copy.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/juz_ring.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_level_progress.dart';
import '../../../shared/widgets/level_progression_widget.dart';
import '../providers/student_provider.dart';
import '../widgets/home_assignment_card.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currentUser = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(studentStatsProvider);
    final meetingAsync = ref.watch(studentDashboardMeetingProvider);

    return Scaffold(
      appBar: AppBar(
        // Sign-out is not offered here: it lives, confirmed, in الإعدادات
        // (the shared SettingsScreen) so a destructive action never fires on a
        // single unconfirmed tap next to routine navigation.
        //
        // Aref Ruqaa is reserved for this ONE hero wordmark in the whole app.
        title: Text(
          'الراسخون',
          style: GoogleFonts.arefRuqaa(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers
          ref.invalidate(currentStudentProvider);
          ref.invalidate(studentStatsProvider);
          ref.invalidate(studentDashboardMeetingProvider);
          ref.invalidate(homePracticeStatsProvider);

          // Wait for providers to reload
          await Future.wait([
            ref.read(studentStatsProvider.future),
            ref.read(studentDashboardMeetingProvider.future),
            ref.read(homePracticeStatsProvider.future),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Guardian child switcher — only shown for guardians with 2+ children
              if (currentUser?.role == UserRole.guardian)
                const _GuardianChildSwitcher(),

              // Welcome
              Text(
                'مرحباً، ${currentUser?.name ?? 'الطالب'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'تقدمك في حفظ القرآن الكريم',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
              ),
              const SizedBox(height: 24),

              // Hero: the Illuminated Juz Ring, fed by the same
              // level-progress fraction the progress card already shows via
              // StudentLevelProgress — no new domain concept, no new
              // provider call. Guarded against a level with an unknown/zero
              // session count so the ring never divides by zero.
              statsAsync.when(
                data: (stats) => Column(
                  children: [
                    Center(
                      child: JuzRing(
                        juz: stats.currentJuz,
                        progress: stats.totalSessions > 0
                            ? (stats.currentOrderInLevel / stats.totalSessions)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProgressCard(stats),
                  ],
                ),
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: 'تعذر تحميل التقدم: $e'),
              ),

              const SizedBox(height: 24),

              // Level progression
              statsAsync.when(
                data: (stats) => LevelProgressionWidget(
                  currentLevel: stats.currentLevel,
                  unlockedLevels: stats.unlockedLevelsList,
                  completedLevels: stats.completedLevelsList,
                ),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),

              const SizedBox(height: 24),

              // Current session
              Text(
                'الحلقة الحالية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              meetingAsync.when(
                data: (meeting) => _buildCurrentSessionCard(meeting),
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: 'تعذر تحميل الحلقة: $e'),
              ),

              const SizedBox(height: 24),

              // What the student owes at home — renders nothing when there is
              // no assignment, so it is safe to always place here (spec §5:
              // both the dashboard and the home-practice screen show it).
              const HomeAssignmentCard(),

              const SizedBox(height: 24),

              // Home practice card
              _buildHomePracticeCard(),

              const SizedBox(height: 24),

              // Quick stats
              Text('إحصائياتي', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              statsAsync.when(
                data: (stats) => _buildQuickStats(stats),
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePracticeCard() {
    final tokens = context.tokens;
    final practiceStatsAsync = ref.watch(homePracticeStatsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible, not bare: the title and the action together are wider
            // than a phone at this text size, and an unflexed Row would overflow
            // (75px on a 390pt screen) — cutting the action off the edge where
            // the student cannot reach it.
            Flexible(
              child: Text(
                'التكرار في المنزل',
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push(AppRoutes.homePractice),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('تسجيل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        practiceStatsAsync.when(
          data: (stats) => AppCard(
            onTap: () => context.push(AppRoutes.homePractice),
            child: Row(
              children: [
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.today,
                    label: 'اليوم',
                    value: '${stats.todayRepetitions}',
                  ),
                ),
                Container(width: 1, height: 40, color: tokens.hairline),
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.local_fire_department,
                    label: 'متتالية',
                    value: '${stats.streakDays}',
                  ),
                ),
                Container(width: 1, height: 40, color: tokens.hairline),
                Expanded(
                  child: _PracticeStatItem(
                    icon: Icons.repeat,
                    label: 'الإجمالي',
                    value: '${stats.totalRepetitions}',
                  ),
                ),
              ],
            ),
          ),
          loading: () => const LoadingState(lines: 1),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildProgressCard(StudentStats stats) {
    final tokens = context.tokens;
    return AppCard(
      backgroundColor: tokens.green.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: tokens.green, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستوى ${stats.currentLevel}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      // Never an app-derived hizb: it can disagree with the
                      // assessment's own verbatim label for the very session
                      // the student stands on (level 2's structural hizb is
                      // known to contradict its source text). The juz is
                      // always consistent with the data.
                      'الجزء ${stats.currentJuz}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
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
                  color: tokens.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${stats.completedLevels}/10',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tokens.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress through the level, against the level's real session count
          // from the catalog (210 in level 1, 49 in level 10) — never `/ 36`.
          StudentLevelProgress(
            level: stats.currentLevel,
            orderInLevel: stats.currentOrderInLevel,
          ),
        ],
      ),
    );
  }

  /// The student's current meeting, as the curriculum describes it. What the
  /// meeting IS comes from the `kind` of the session it starts on — a batch is
  /// all lessons, so they agree — and an assessment is named by the
  /// curriculum's own label — never `'سرد الحزب $hizb'`, which cannot name a
  /// juz- or level-tier سرد at all.
  Widget _buildCurrentSessionCard(PacedSession? meeting) {
    final tokens = context.tokens;
    final studentAsync = ref.watch(currentStudentProvider);

    return studentAsync.when(
      data: (student) {
        if (student == null) return const SizedBox();
        if (meeting == null) {
          return const AppCard(
            child: Center(child: Text('لا توجد بيانات للحلقة')),
          );
        }

        final session = meeting.first;

        // The تلقين branch MUST come before isExam/isSard and the regular
        // lesson fallthrough (see session_overview_screen.dart's identical
        // ordering): a تلقين is neither graded nor new memorization for the
        // student to recite alone, and falling through to the lesson card
        // would tell him to memorize a passage the teacher has not yet read
        // to him.
        if (session.isTalqeen) {
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.sepia),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                  'سيقرأ المعلّم هذا المقطع معك ويكرره معك. لا حفظ عليك ولا '
                  'تسميع ولا تقييم في هذه الحلقة.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        if (session.isExam) {
          return AppCard(
            backgroundColor: tokens.gold.withValues(alpha: 0.05),
            child: Row(
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
                        'توجه للمشرف لإجراء الاختبار',
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

        if (session.isSard) {
          // No manuscript token maps directly to the old "info" blue, so
          // سرد is given tokens.maroon — the palette's rubrication/emphasis
          // hue — as its own distinct accent: distinct from the lesson's
          // green, the exam's gold, and (unlike sepia) distinct from this
          // same card's own sepia-toned caption text below.
          return AppCard(
            backgroundColor: tokens.maroon.withValues(alpha: 0.05),
            child: Row(
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
                          // Never an app-derived hizb — see the comment on
                          // the progress-card header above.
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
              _ContentRow(title: 'الحفظ الجديد', content: meeting.newContentAr),
            ],
          ),
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: 'تعذر تحميل الطالب: $e'),
    );
  }

  Widget _buildQuickStats(StudentStats stats) {
    final tokens = context.tokens;
    return Row(
      children: [
        Expanded(
          child: StatCardCompact(
            label: 'الحلقات',
            value: '${stats.totalSessions}',
            icon: Icons.school,
            color: tokens.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCardCompact(
            label: 'الناجحة',
            value: '${stats.passedSessions}',
            icon: Icons.check_circle,
            // No manuscript token for a distinct "success" hue — the
            // primary green already carries the positive/affirmative role
            // elsewhere on this screen, so it is reused here too.
            color: tokens.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCardCompact(
            label: 'المستويات',
            value: '${stats.completedLevels}',
            icon: Icons.emoji_events,
            color: tokens.gold,
          ),
        ),
      ],
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String title;
  final String content;

  const _ContentRow({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content.isNotEmpty ? content : '-',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PracticeStatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Icon(icon, color: tokens.green, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
      ],
    );
  }
}

/// Lets a guardian with multiple children pick which child the dashboard
/// is currently focused on. Hidden when the guardian has only one child.
class _GuardianChildSwitcher extends ConsumerWidget {
  const _GuardianChildSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(guardianChildrenProvider);

    return childrenAsync.maybeWhen(
      data: (children) {
        if (children.length < 2) return const SizedBox.shrink();

        final selected =
            ref.watch(selectedChildIdProvider) ?? children.first.student.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: InputDecoration(
              labelText: 'الطالب',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            items: children
                .map(
                  (child) => DropdownMenuItem<String>(
                    value: child.student.id,
                    child: Text(child.user.name),
                  ),
                )
                .toList(),
            onChanged: (studentId) {
              ref.read(selectedChildIdProvider.notifier).set(studentId);
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
