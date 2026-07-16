import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/admin_provider.dart';

/// Admin-facing list of every student in the system. Tapping a row opens
/// the read-only progress view; admins never start sessions from here.
class AllStudentsScreen extends ConsumerWidget {
  const AllStudentsScreen({super.key});

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
