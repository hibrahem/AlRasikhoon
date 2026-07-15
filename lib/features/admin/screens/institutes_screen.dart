import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

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
      appBar: AppBar(title: const Text('المعاهد')),
      body: institutesAsync.when(
        data: (institutes) {
          if (institutes.isEmpty) {
            return const EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'لا يوجد معاهد',
              message: 'اضغط على + لإضافة معهد جديد',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(institutesProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: institutes.length,
              itemBuilder: (context, index) {
                final institute = institutes[index];
                return AppCard(
                  onTap: () => context.push(
                    AppRoutes.instituteDetail.replaceFirst(':id', institute.id),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          color: tokens.green,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              institute.name,
                              style: Theme.of(context).textTheme.titleMedium,
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
                                  style: Theme.of(context).textTheme.bodySmall
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
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المعاهد: $e'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createInstitute),
        child: const Icon(Icons.add),
      ),
    );
  }
}
