import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/supervisor_provider.dart';
import '../widgets/assign_teacher_dialog.dart';

/// Supervisor's institute-scoped student management (#28 / AgDR-0003).
/// Teacher-parity: view, add, and evaluate the students of the supervisor's
/// own institute. The backing [supervisorStudentsProvider] is scoped to
/// `users/{uid}.institute_id`, so the list can only ever contain the
/// supervisor's institute — there is no cross-institute view to filter.
class SupervisorStudentsScreen extends ConsumerWidget {
  const SupervisorStudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(supervisorStudentsProvider);
    // Watch auth state for reactivity (sign-out, institute change).
    ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلاب المعهد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supervisorStudentsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final studentWithUser = students[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onLongPress: () => _showStudentActions(
                      context,
                      studentWithUser.user.id,
                      studentWithUser.user.name,
                      studentWithUser.student,
                    ),
                    child: StudentCard(
                      studentWithUser: studentWithUser,
                      onTap: () {
                        // Read-only progress (al_rasikhoon-801). The supervisor
                        // conducts الاختبار, never سرد, so a student tap leads
                        // to progress — not to a screen with session actions.
                        context.push(
                          AppRoutes.supervisorStudentProgress.replaceFirst(
                            ':studentId',
                            studentWithUser.student.id,
                          ),
                        );
                      },
                    ),
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
        onPressed: () => context.push(AppRoutes.supervisorAddStudent),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showStudentActions(
    BuildContext context,
    String userId,
    String userName,
    StudentModel student,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only offered for a teacher-less student (al_rasikhoon-6bw) —
            // the rescue path for the state creation can no longer produce.
            if (student.teacherId == null)
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt,
                  color: AppColors.warning,
                ),
                title: const Text('تعيين معلم'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => AssignTeacherDialog(
                      studentId: student.id,
                      studentDisplayName: userName,
                    ),
                  );
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
                    userId: userId,
                    userDisplayName: userName,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد طلاب',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على + لإضافة طالب جديد',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
