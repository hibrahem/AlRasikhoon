import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';
import '../../../shared/widgets/icon_medallion.dart';

class InstitutesScreen extends ConsumerStatefulWidget {
  const InstitutesScreen({super.key});

  @override
  ConsumerState<InstitutesScreen> createState() => _InstitutesScreenState();
}

class _InstitutesScreenState extends ConsumerState<InstitutesScreen> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final institutesAsync = ref.watch(institutesProvider);

    return Scaffold(
      // Large-title sliver bar; the refresh indicator wraps the whole scroll
      // view so pull-to-refresh works from the loading/error/empty states too.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(institutesProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppLargeTopBar(title: 'المعاهد'),
            institutesAsync.when(
              data: (institutes) {
                if (institutes.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.account_balance_outlined,
                      title: 'لا يوجد معاهد',
                      message: 'اضغط على + لإضافة معهد جديد',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: institutes.length,
                    itemBuilder: (context, index) {
                      final institute = institutes[index];
                      return AppCard(
                        onTap: () => context.push(
                          AppRoutes.instituteDetail.replaceFirst(
                            ':id',
                            institute.id,
                          ),
                        ),
                        child: Row(
                          children: [
                            IconMedallion(
                              icon: Icons.account_balance,
                              accent: tokens.green,
                              size: 52,
                              iconSize: 26,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    institute.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: tokens.sepia,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        institute.location,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: tokens.sepia),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_left, color: tokens.sepia),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              ),
              error: (e, _) {
                debugPrint('institutesProvider failed: $e');
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: 'تعذر تحميل المعاهد',
                    onRetry: () => ref.invalidate(institutesProvider),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createInstitute),
        child: const Icon(Icons.add),
      ),
    );
  }
}
