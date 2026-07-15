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
          if (students.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'لا يوجد طلاب',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allStudentsProvider);
            },
            child: ListView.builder(
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
        error: (e, _) => ErrorState(message: 'تعذر تحميل الطلاب: $e'),
      ),
    );
  }
}
