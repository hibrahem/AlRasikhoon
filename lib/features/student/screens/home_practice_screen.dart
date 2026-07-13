import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
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
    final repetitions = int.tryParse(_repetitionsController.text) ?? 0;
    if (repetitions <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال عدد التكرارات'),
          backgroundColor: AppColors.error,
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
        const SnackBar(
          content: Text('تم تسجيل التكرار بنجاح'),
          backgroundColor: AppColors.success,
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
                loading: () => const Center(child: CircularProgressIndicator()),
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
                    return const AppCard(
                      child: Center(
                        child: Text('لم يتم العثور على بيانات الطالب'),
                      ),
                    );
                  }
                  return _buildAddPracticeCard(student);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
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
                    return const AppCard(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.history,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'لا يوجد سجل تكرارات',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildPracticeHistory(practices);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(HomePracticeStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.today,
                label: 'اليوم',
                value: '${stats.todayRepetitions}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.calendar_view_week,
                label: 'هذا الأسبوع',
                value: '${stats.weekRepetitions}',
                color: AppColors.info,
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
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'أيام متتالية',
                value: '${stats.streakDays}',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddPracticeCard(dynamic student) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current session info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: AppColors.primary),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                color: AppColors.primary,
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
                color: AppColors.primary,
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${practice.repetitions}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      'الحلقة ${practice.sessionNumber}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      dateFormat.format(practice.practiceDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.repeat, color: AppColors.textSecondary),
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
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
