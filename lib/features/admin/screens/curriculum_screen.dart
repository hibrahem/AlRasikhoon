import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';

class CurriculumScreen extends ConsumerWidget {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final levelsAsync = ref.watch(levelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المنهج')),
      body: levelsAsync.when(
        data: (levels) {
          // The curriculum's size is the sum of what the catalog actually
          // holds — never a number typed into the UI.
          final totalSessions = levels.fold<int>(
            0,
            (sum, level) => sum + level.sessionCount,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overview card
              AppCard(
                backgroundColor: tokens.green.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu_book,
                        color: tokens.green,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'منهج الراسخون',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${levels.length} مستويات • $totalSessions حلقة',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.sepia),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Levels header
              Text('المستويات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Levels list
              ...levels.map((level) {
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  onTap: () => context.push(
                    '${AppRoutes.curriculum}/${level.levelNumber}',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getLevelColor(
                                tokens,
                                level.levelNumber,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${level.levelNumber}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getLevelColor(
                                    tokens,
                                    level.levelNumber,
                                  ),
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
                                  level.nameAr,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  level.juzRangeAr,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: tokens.sepia),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_left, color: tokens.sepia),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            label: 'الأجزاء',
                            value: '${level.juzNumbers.length}',
                            icon: Icons.menu_book,
                          ),
                          // The session count is DATA, per level (210 in level
                          // 1, 49 in level 10). A level has no fixed number of
                          // "hizbs" — levels 3-10 have none at all — so the
                          // catalog's own count is what is shown.
                          _StatItem(
                            label: 'الحلقات',
                            value: '${level.sessionCount}',
                            icon: Icons.school,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المنهج: $e'),
      ),
    );
  }

  // Purely a per-level identity badge (1-10), never a grade/pass-fail
  // indicator — the level number is always shown as the actual label, this
  // color only adds a quick visual distinction between adjacent cards. The
  // manuscript palette has just 3 accent hues (+5 grade tones that are
  // themselves shades of those 3), nowhere near 10 mutually distinct hues,
  // and reusing the grade tones here would misleadingly imply a level ->
  // performance-grade relationship that doesn't exist. So level 1 keeps the
  // token mapping table's direct AppColors.primary -> tokens.green swap
  // (fixing dark-mode contrast for free), and levels 2-10 intentionally keep
  // their original raw Material swatches, which were never AppColors/theme
  // values and fall outside both mapping tables.
  Color _getLevelColor(AppTokens tokens, int level) {
    final colors = [
      tokens.green,
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.red,
    ];
    return colors[(level - 1) % colors.length];
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Icon(icon, size: 20, color: tokens.sepia),
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
