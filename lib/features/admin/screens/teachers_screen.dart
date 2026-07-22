import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
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
      // Large-title sliver bar; the refresh indicator wraps the whole scroll
      // view so pull-to-refresh works from the loading/error/empty states too.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allTeachersProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppLargeTopBar(title: 'المعلمون'),
            teachersAsync.when(
              data: (teachers) {
                if (teachers.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.people_outline,
                      title: 'لا يوجد معلمون',
                      message: 'اضغط على + لإضافة معلم جديد',
                    ),
                  );
                }
                final query = ref.watch(allTeachersSearchQueryProvider);
                final filtered = teachers
                    .where(
                      (teacher) => matchesSearch(query, [
                        teacher.name,
                        teacher.phone,
                        teacher.displayUsername,
                      ]),
                    )
                    .toList(growable: false);
                final searchField = SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AppSearchField(
                      onChanged: (value) => ref
                          .read(allTeachersSearchQueryProvider.notifier)
                          .set(value),
                    ),
                  ),
                );
                if (filtered.isEmpty) {
                  return SliverMainAxisGroup(
                    slivers: [
                      searchField,
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: EmptyState(
                            icon: Icons.search_off,
                            title: 'لا توجد نتائج مطابقة للبحث',
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return SliverMainAxisGroup(
                  slivers: [
                    searchField,
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final teacher = filtered[index];
                          return AppCard(
                            onTap: () => context.push(
                              AppRoutes.teacherDetail.replaceFirst(
                                ':id',
                                teacher.id,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: tokens.green.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Text(
                                    teacher.name.isNotEmpty
                                        ? teacher.name[0]
                                        : '?',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
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
                                              teacher.phone ??
                                                  teacher.displayUsername,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: tokens.sepia,
                                                  ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
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
                    ),
                  ],
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: LoadingState(),
              ),
              error: (e, _) {
                debugPrint('allTeachersProvider failed: $e');
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: 'تعذر تحميل المعلمين',
                    onRetry: () => ref.invalidate(allTeachersProvider),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addTeacher),
        child: const Icon(Icons.add),
      ),
    );
  }
}
