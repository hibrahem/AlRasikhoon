import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/edit_profile_dialog.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/admin_provider.dart';
import '../widgets/delete_student_dialog.dart';

/// Admin-facing list of every student in the system. Tapping a row opens
/// the read-only progress view; admins never start sessions from here.
/// The per-row ⋮ menu carries account-level actions on the student's linked
/// user (edit profile, reset password) — mirroring the teacher roster's
/// actions sheet.
class AllStudentsScreen extends ConsumerWidget {
  const AllStudentsScreen({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => EditProfileDialog(
        initialName: user.name,
        initialPhone: user.phone,
        onSave: (name, phone) async {
          await ref
              .read(userRepositoryProvider)
              .updateProfileFields(userId: user.id, name: name, phone: phone);
          ref.invalidate(allStudentsProvider);
        },
      ),
    );
  }

  void _showStudentActions(
    BuildContext context,
    WidgetRef ref,
    StudentWithUser studentWithUser,
  ) {
    final user = studentWithUser.user;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل الملف الشخصي'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditProfileDialog(context, ref, user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_reset),
              title: const Text('إعادة تعيين كلمة المرور'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (_) => ResetPasswordDialog(
                    userId: user.id,
                    userDisplayName: user.name,
                  ),
                );
              },
            ),
            // Hard delete — the only surface in the app offering it, and this
            // screen is reachable by super admins alone. The Cloud Function
            // re-checks the role server-side regardless.
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: context.tokens.maroon,
              ),
              title: Text(
                'حذف الطالب نهائيًا',
                style: TextStyle(color: context.tokens.maroon),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (_) => DeleteStudentDialog(
                    studentId: studentWithUser.student.id,
                    studentDisplayName: user.name,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      // Large-title sliver bar; the refresh indicator wraps the whole scroll
      // view so pull-to-refresh works from the loading/error/empty states too.
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allStudentsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const AppLargeTopBar(title: 'الطلاب'),
            studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.school_outlined,
                      title: 'لا يوجد طلاب',
                    ),
                  );
                }
                final query = ref.watch(allStudentsSearchQueryProvider);
                final filtered = students
                    .where(
                      (s) => matchesSearch(query, [
                        s.user.name,
                        s.user.phone,
                        s.user.displayUsername,
                      ]),
                    )
                    .toList(growable: false);
                final searchField = SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: AppSearchField(
                      onChanged: (value) => ref
                          .read(allStudentsSearchQueryProvider.notifier)
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
                          final studentWithUser = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StudentCard(
                              studentWithUser: studentWithUser,
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                tooltip: 'خيارات الطالب',
                                onPressed: () => _showStudentActions(
                                  context,
                                  ref,
                                  studentWithUser,
                                ),
                              ),
                              onTap: () => context.push(
                                AppRoutes.adminStudentProgress.replaceFirst(
                                  ':id',
                                  studentWithUser.student.id,
                                ),
                              ),
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
                debugPrint('allStudentsProvider failed: $e');
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(
                    message: 'تعذر تحميل الطلاب',
                    onRetry: () => ref.invalidate(allStudentsProvider),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
