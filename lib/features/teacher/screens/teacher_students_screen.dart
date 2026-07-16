import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/institute_provider.dart';
import '../../../shared/widgets/hero_header.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/teacher_provider.dart';

class TeacherStudentsScreen extends ConsumerStatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  ConsumerState<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends ConsumerState<TeacherStudentsScreen> {
  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(filteredTeacherStudentsProvider);
    final institutesAsync = ref.watch(teacherInstitutesProvider);
    // Watch auth state for reactivity
    ref.watch(authRepositoryProvider);

    // No AppBar: a compact hero owns the top edge (the teacher's calm
    // register — title + roster count, no gamification).
    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلابي',
                        style: GoogleFonts.amiri(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: context.tokens.onHero,
                        ),
                      ),
                      studentsAsync.maybeWhen(
                        data: (students) => Text(
                          _studentCountAr(students.length),
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: context.tokens.onHeroMuted,
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                  return const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'لا يوجد طلاب',
                    message: 'اضغط على + لإضافة طالب جديد',
                  );
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
                        child: GestureDetector(
                          onLongPress: () => _showStudentActions(
                            context,
                            studentWithUser.user.id,
                            studentWithUser.user.name,
                          ),
                          child: StudentCard(
                            studentWithUser: studentWithUser,
                            // Visible entry point to the same actions sheet:
                            // long-press alone is undiscoverable.
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'خيارات الطالب',
                              onPressed: () => _showStudentActions(
                                context,
                                studentWithUser.user.id,
                                studentWithUser.user.name,
                              ),
                            ),
                            onTap: () {
                              context.push(
                                AppRoutes.studentProfile.replaceFirst(
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
                // The raw exception goes to the log, never onto the screen.
                debugPrint('filteredTeacherStudentsProvider failed: $e');
                return ErrorState(
                  message: 'تعذر تحميل الطلاب',
                  onRetry: () => ref.invalidate(teacherStudentsProvider),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addStudent),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  /// Roster count with correct Arabic number agreement: dual, the 3–10
  /// plural, and the 11+ singular accusative are all different forms.
  String _studentCountAr(int count) {
    if (count == 0) return 'لا طلاب';
    if (count == 1) return 'طالب واحد';
    if (count == 2) return 'طالبان';
    if (count <= 10) return '$count طلاب';
    return '$count طالباً';
  }

  void _showStudentActions(
    BuildContext context,
    String userId,
    String userName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
