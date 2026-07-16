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

class SupervisorsScreen extends ConsumerWidget {
  const SupervisorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final supervisorsAsync = ref.watch(allSupervisorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المشرفون')),
      body: supervisorsAsync.when(
        data: (supervisors) {
          if (supervisors.isEmpty) {
            return const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'لا يوجد مشرفون',
              message: 'اضغط على + لإضافة مشرف جديد',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allSupervisorsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: supervisors.length,
              itemBuilder: (context, index) {
                final supervisor = supervisors[index];
                return AppCard(
                  onTap: () => context.push(
                    AppRoutes.supervisorDetail.replaceFirst(
                      ':id',
                      supervisor.id,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: tokens.gold.withValues(alpha: 0.1),
                        child: Text(
                          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
                          style: TextStyle(
                            color: tokens.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supervisor.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  supervisor.phone != null
                                      ? Icons.phone
                                      : Icons.email,
                                  size: 14,
                                  color: tokens.sepia,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    supervisor.phone ??
                                        supervisor.displayUsername,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: tokens.sepia),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: supervisor.isActive
                              ? tokens.green.withValues(alpha: 0.1)
                              : tokens.maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          supervisor.isActive ? 'نشط' : 'غير نشط',
                          style: TextStyle(
                            fontSize: 11,
                            color: supervisor.isActive
                                ? tokens.green
                                : tokens.maroon,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_left, color: tokens.sepia),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المشرفين: $e'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addSupervisor),
        child: const Icon(Icons.add),
      ),
    );
  }
}
