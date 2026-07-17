import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/edit_profile_dialog.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/admin_provider.dart';

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
    UserModel user,
  ) {
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      body: studentsAsync.when(
        data: (students) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allStudentsProvider);
            },
            // The empty state sits INSIDE the refresh scroll view so
            // pull-to-refresh keeps working when the list is empty.
            child: students.isEmpty
                ? const CustomScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.school_outlined,
                          title: 'لا يوجد طلاب',
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final studentWithUser = students[index];
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
                              studentWithUser.user,
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
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) {
          debugPrint('allStudentsProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل الطلاب',
            onRetry: () => ref.invalidate(allStudentsProvider),
          );
        },
      ),
    );
  }
}
