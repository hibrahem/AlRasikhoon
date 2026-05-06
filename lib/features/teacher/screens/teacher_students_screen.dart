import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/teacher_provider.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(filteredTeacherStudentsProvider);
    final institutesAsync = ref.watch(teacherInstitutesProvider);
    // Watch auth state for reactivity
    ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Institute filter — only shown when teacher has multiple institutes
          institutesAsync.maybeWhen(
            data: (institutes) {
              if (institutes.length < 2) return const SizedBox.shrink();
              return _InstituteFilter(institutes: institutes);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(teacherStudentsProvider);
                    ref.invalidate(teacherInstitutesProvider);
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
                          onTap: () {
                            context.push(
                              AppRoutes.sessionOverview.replaceFirst(
                                ':studentId',
                                studentWithUser.student.id,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addStudent),
        child: const Icon(Icons.person_add),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Handle navigation based on index
          switch (index) {
            case 1:
              // Session tab - show current session if any
              break;
            case 2:
              // History tab
              break;
            case 3:
              // Settings tab
              break;
          }
        },
        role: UserRole.teacher,
      ),
    );
  }

  Widget _buildEmptyState() {
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

class _InstituteFilter extends ConsumerWidget {
  final List<InstituteModel> institutes;

  const _InstituteFilter({required this.institutes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTeacherInstituteFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String?>(
        initialValue: selected,
        decoration: InputDecoration(
          labelText: 'المعهد',
          prefixIcon: const Icon(Icons.business),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('كل المعاهد'),
          ),
          ...institutes.map(
            (institute) => DropdownMenuItem<String?>(
              value: institute.id,
              child: Text(institute.name),
            ),
          ),
        ],
        onChanged: (value) {
          ref.read(selectedTeacherInstituteFilterProvider.notifier).set(value);
        },
      ),
    );
  }
}
