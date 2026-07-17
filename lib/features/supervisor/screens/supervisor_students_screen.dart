import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../../../shared/widgets/student_pace_control.dart';
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
        // Sign-out is not offered here: it lives, confirmed, in الإعدادات
        // (the shared SettingsScreen) so a destructive action never fires on a
        // single unconfirmed tap next to routine navigation.
        title: const Text('طلاب المعهد'),
      ),
      body: studentsAsync.when(
        data: (students) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(supervisorStudentsProvider);
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
                          message: 'اضغط على + لإضافة طالب جديد',
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
                        child: GestureDetector(
                          onLongPress: () => _showStudentActions(
                            context,
                            studentWithUser.user.id,
                            studentWithUser.user.name,
                            studentWithUser.student,
                          ),
                          child: StudentCard(
                            studentWithUser: studentWithUser,
                            // Visible entry point to the same actions sheet
                            // the long-press opens — a bare long-press is
                            // undiscoverable, so the affordance is explicit.
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'إجراءات الطالب',
                              onPressed: () => _showStudentActions(
                                context,
                                studentWithUser.user.id,
                                studentWithUser.user.name,
                                studentWithUser.student,
                              ),
                            ),
                            onTap: () {
                              // Read-only progress (al_rasikhoon-801). The
                              // supervisor conducts الاختبار, never سرد, so a
                              // student tap leads to progress — not to a
                              // screen with session actions.
                              context.push(
                                AppRoutes.supervisorStudentProgress
                                    .replaceFirst(
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
        loading: () => const LoadingState(),
        error: (e, _) {
          debugPrint('supervisorStudentsProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل الطلاب',
            onRetry: () => ref.invalidate(supervisorStudentsProvider),
          );
        },
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
    final tokens = context.tokens;
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
                // AppColors.warning has no direct AppTokens equivalent.
                // tokens.gold is this codebase's "needs attention" accent
                // (see the exam-queue screen); the tile's own title uses the
                // theme's default text color, not gold, so there is no
                // collision.
                leading: Icon(Icons.person_add_alt, color: tokens.gold),
                title: const Text('تعيين معلم'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showDialog<void>(
                    context: context,
                    builder: (_) => AssignTeacherDialog(
                      studentId: student.id,
                      studentDisplayName: userName,
                      instituteId: student.instituteId,
                    ),
                  );
                },
              ),
            // Change pace without leaving the list — the same control the
            // student view shows, backed by the same setStudentPace write. A
            // supervisor scoped to this student's institute is authorised
            // (firestore.rules). Refreshes the list so the change is reflected.
            ListTile(
              leading: Icon(Icons.speed, color: tokens.gold),
              title: const Text('تغيير خطة الحفظ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    content: SizedBox(
                      width: double.maxFinite,
                      // The dialog stays open on a change — the card holds TWO
                      // dials (pace and cadence) and popping after the first
                      // write would snatch the second away. Dismiss is the
                      // barrier tap, as with any read-and-adjust dialog.
                      child: StudentPaceControl(
                        studentId: student.id,
                        currentPace: student.pace,
                        currentMeetingsPerWeek: student.meetingsPerWeek,
                        onPlanChanged: (ref) {
                          ref.invalidate(supervisorStudentsProvider);
                        },
                      ),
                    ),
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
}
