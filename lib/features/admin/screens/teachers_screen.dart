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

class TeachersScreen extends ConsumerWidget {
  const TeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final teachersAsync = ref.watch(allTeachersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المعلمون')),
      body: teachersAsync.when(
        data: (teachers) {
          if (teachers.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'لا يوجد معلمون',
              message: 'اضغط على + لإضافة معلم جديد',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allTeachersProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachers.length,
              itemBuilder: (context, index) {
                final teacher = teachers[index];
                return AppCard(
                  onTap: () => context.push(
                    AppRoutes.teacherDetail.replaceFirst(':id', teacher.id),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: tokens.green.withValues(alpha: 0.1),
                        child: Text(
                          teacher.name.isNotEmpty ? teacher.name[0] : '?',
                          style: TextStyle(
                            color: tokens.green,
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
                              teacher.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  teacher.phone != null
                                      ? Icons.phone
                                      : Icons.email,
                                  size: 14,
                                  color: tokens.sepia,
                                ),
                                const SizedBox(width: 4),
                                // A teacher with no phone falls back to their
                                // login username, which can be just as long —
                                // it must shrink, not overflow.
                                Expanded(
                                  child: Text(
                                    teacher.phone ?? teacher.displayUsername,
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
                          // "success"/"error" reused as green/maroon — the
                          // same positive-affirmative/danger roles they
                          // already carry elsewhere (see admin dashboard).
                          color: teacher.isActive
                              ? tokens.green.withValues(alpha: 0.1)
                              : tokens.maroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          teacher.isActive ? 'نشط' : 'غير نشط',
                          style: TextStyle(
                            fontSize: 11,
                            color: teacher.isActive
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
        error: (e, _) => ErrorState(message: 'تعذر تحميل المعلمين: $e'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addTeacher),
        child: const Icon(Icons.add),
      ),
    );
  }
}
