import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../providers/admin_provider.dart';

class InstitutesScreen extends ConsumerStatefulWidget {
  const InstitutesScreen({super.key});

  @override
  ConsumerState<InstitutesScreen> createState() => _InstitutesScreenState();
}

class _InstitutesScreenState extends ConsumerState<InstitutesScreen> {
  @override
  Widget build(BuildContext context) {
    final institutesAsync = ref.watch(institutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المعاهد'),
      ),
      body: institutesAsync.when(
        data: (institutes) {
          if (institutes.isEmpty) {
            return _buildEmptyState();
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
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: AppColors.primary,
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
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  institute.location,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.createInstitute),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.adminDashboard);
              break;
            case 2:
              context.go(AppRoutes.teachers);
              break;
            case 3:
              context.go(AppRoutes.curriculum);
              break;
          }
        },
        role: UserRole.superAdmin,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 80,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد معاهد',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة معهد جديد',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
