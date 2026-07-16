import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/icon_medallion.dart';

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
                    IconMedallion(
                      icon: Icons.menu_book,
                      accent: tokens.green,
                      size: 56,
                      iconSize: 28,
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
                          // Level-number badge in the medallion shape
                          // (circular tinted disc), matching the header badge
                          // on level_detail_screen.dart — numeral in Cairo
                          // bold tabular like every data numeral.
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getLevelColor(
                                tokens,
                                level.levelNumber,
                              ).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${level.levelNumber}',
                                style: GoogleFonts.cairo(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getLevelColor(
                                    tokens,
                                    level.levelNumber,
                                  ),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
        error: (e, _) {
          debugPrint('levelsProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل المنهج',
            onRetry: () => ref.invalidate(levelsProvider),
          );
        },
      ),
    );
  }

  // Purely a per-level identity badge (1-10), never a grade/pass-fail
  // indicator — the level number is always shown as the actual label, this
  // color only adds a quick visual distinction between adjacent cards. The
  // manuscript palette has just 3 accent hues, nowhere near 10 mutually
  // distinct ones, so adjacent-card distinction comes from CYCLING the three
  // accents (green, gold, maroon by level % 3): neighbours never share a
  // tint, every tint is a palette token that holds up in dark mode, and no
  // raw Material swatch leaks into the manuscript language. The semantic
  // color rules (gold=achievement, maroon=attention) don't apply here —
  // these are identity tints on separate cards, not status fills competing
  // inside one component.
  Color _getLevelColor(AppTokens tokens, int level) {
    final colors = [tokens.green, tokens.gold, tokens.maroon];
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
