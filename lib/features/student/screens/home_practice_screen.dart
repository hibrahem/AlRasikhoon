import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';
import '../widgets/home_assignment_card.dart';

class HomePracticeScreen extends ConsumerStatefulWidget {
  const HomePracticeScreen({super.key});

  @override
  ConsumerState<HomePracticeScreen> createState() => _HomePracticeScreenState();
}

class _HomePracticeScreenState extends ConsumerState<HomePracticeScreen> {
  final _repetitionsController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _repetitionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitPractice() async {
    final tokens = context.tokens;
    final repetitions = int.tryParse(_repetitionsController.text) ?? 0;
    if (repetitions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إدخال عدد التكرارات'),
          backgroundColor: tokens.maroon,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(homePracticeNotifierProvider.notifier)
        .addPractice(
          repetitions: repetitions,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
        );

    setState(() => _isSubmitting = false);

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
      _repetitionsController.text = '1';
      _notesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(homePracticeStatsProvider);
    final practicesAsync = ref.watch(studentHomePracticesProvider);
    final studentAsync = ref.watch(currentStudentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('التكرار في المنزل')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homePracticeStatsProvider);
          ref.invalidate(studentHomePracticesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeAssignmentCard(),
              const SizedBox(height: 16),

              // Stats cards
              statsAsync.when(
                data: (stats) => _buildStatsSection(stats),
                loading: () => const LoadingState(lines: 1),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // Add practice section
              Text(
                'تسجيل تكرار جديد',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              studentAsync.when(
                data: (student) {
                  if (student == null) {
                    return const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'لم يتم العثور على بيانات الطالب',
                    );
                  }
                  return _buildAddPracticeCard(student);
                },
                loading: () => const LoadingState(lines: 1),
                error: (_, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // History section
              Text(
                'سجل التكرارات',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              practicesAsync.when(
                data: (practices) {
                  if (practices.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history,
                      title: 'لا يوجد سجل تكرارات',
                    );
                  }
                  return _buildPracticeHistory(practices);
                },
                loading: () => const LoadingState(),
                error: (e, _) =>
                    ErrorState(message: 'تعذر تحميل سجل التكرارات: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(HomePracticeStats stats) {
    final tokens = context.tokens;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today,
                label: 'اليوم',
                value: '${stats.todayRepetitions}',
                color: tokens.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_view_week,
                label: 'هذا الأسبوع',
                value: '${stats.weekRepetitions}',
                // AppColors.info has no direct AppTokens equivalent. The
                // manuscript palette only has three saturated accent hues
                // (green/gold/maroon), both of which are already claimed by
                // sibling stat cards in this same grid (today->green,
                // total->gold). tokens.ink is used here instead of a
                // repeated accent hue: it is the neutral "primary text"
                // token, visually distinct from tokens.sepia (the caption
                // color used for every stat card's label, including this
                // one), so it cannot collide with the label beneath it.
                color: tokens.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.repeat,
                label: 'إجمالي التكرارات',
                value: '${stats.totalRepetitions}',
                color: tokens.gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'أيام متتالية',
                value: '${stats.streakDays}',
                // AppColors.warning has no direct AppTokens equivalent.
                // tokens.maroon (the palette's rubrication/emphasis hue,
                // per the Task 13 follow-up precedent) is used for the
                // streak stat's "don't break the fire" urgency; it is
                // distinct from tokens.sepia, so it does not collide with
                // this card's own label beneath it.
                color: tokens.maroon,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddPracticeCard(dynamic student) {
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current session info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book, color: tokens.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الحلقة ${student.currentSession}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        // Never an app-derived hizb: level 2's structural hizb
                        // can disagree with the assessment's own verbatim
                        // label (`scope.labelAr`) for the same session. The
                        // level and juz are always consistent with the data.
                        'المستوى ${student.currentLevel} - الجزء ${student.currentJuz}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Repetitions input
          Text('عدد التكرارات', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final current =
                      int.tryParse(_repetitionsController.text) ?? 1;
                  if (current > 1) {
                    _repetitionsController.text = '${current - 1}';
                  }
                },
                icon: const Icon(Icons.remove_circle_outline),
                color: tokens.green,
              ),
              Expanded(
                child: TextField(
                  controller: _repetitionsController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final current =
                      int.tryParse(_repetitionsController.text) ?? 1;
                  _repetitionsController.text = '${current + 1}';
                },
                icon: const Icon(Icons.add_circle_outline),
                color: tokens.green,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notes input
          Text(
            'ملاحظات (اختياري)',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'أضف ملاحظات...',
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          AppButton(
            text: 'تسجيل التكرار',
            onPressed: _isSubmitting ? null : _submitPractice,
            isLoading: _isSubmitting,
            isFullWidth: true,
            icon: Icons.check,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeHistory(List<dynamic> practices) {
    final tokens = context.tokens;
    final dateFormat = DateFormat('EEEE، d MMMM yyyy', 'ar');

    return Column(
      children: practices.take(10).map((practice) {
        return AppCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${practice.repetitions}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: tokens.green,
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
                      'الحلقة ${practice.sessionNumber}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      dateFormat.format(practice.practiceDate),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                    ),
                  ],
                ),
              ),
              Icon(Icons.repeat, color: tokens.sepia),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }
}
