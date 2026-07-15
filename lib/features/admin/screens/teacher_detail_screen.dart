import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/institute_model.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../../../shared/widgets/student_card.dart';
import '../providers/admin_provider.dart';

class TeacherDetailScreen extends ConsumerStatefulWidget {
  final String teacherId;

  const TeacherDetailScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherDetailScreen> createState() =>
      _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends ConsumerState<TeacherDetailScreen> {
  /// Institute ids the admin has selected to filter the student list by.
  /// Empty set = "All" — every student is shown (the default). Local,
  /// view-only state; no persistence, no schema change. See #53.
  final Set<String> _selectedInstituteIds = <String>{};

  String get teacherId => widget.teacherId;

  void _toggleInstitute(String instituteId, bool selected) {
    setState(() {
      if (selected) {
        _selectedInstituteIds.add(instituteId);
      } else {
        _selectedInstituteIds.remove(instituteId);
      }
    });
  }

  void _clearFilter() {
    setState(_selectedInstituteIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final teacherAsync = ref.watch(teacherProvider(teacherId));
    final institutesAsync = ref.watch(institutesForTeacherProvider(teacherId));
    final studentsAsync = ref.watch(studentsForTeacherAdminProvider(teacherId));

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المعلم')),
      body: teacherAsync.when(
        data: (teacher) {
          if (teacher == null) {
            return const Center(child: Text('المعلم غير موجود'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher header
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: tokens.green.withValues(alpha: 0.1),
                        child: Text(
                          teacher.name.isNotEmpty ? teacher.name[0] : '?',
                          style: TextStyle(
                            color: tokens.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
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
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  teacher.phone != null
                                      ? Icons.phone
                                      : Icons.email,
                                  size: 16,
                                  color: tokens.sepia,
                                ),
                                const SizedBox(width: 4),
                                // Falls back to the login username when no
                                // phone was given — it must shrink rather
                                // than overflow the row.
                                Expanded(
                                  child: Text(
                                    teacher.phone ?? teacher.displayUsername,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: tokens.sepia),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                // "success"/"error" reused as green/maroon,
                                // same as the teacher list's status badge.
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Assigned institutes
                Text(
                  'المعاهد المعين بها',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('إعادة تعيين كلمة المرور'),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => ResetPasswordDialog(
                          userId: teacher.id,
                          userDisplayName: teacher.name,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                institutesAsync.when(
                  data: (institutes) {
                    if (institutes.isEmpty) {
                      return const EmptyState(
                        icon: Icons.account_balance_outlined,
                        title: 'غير معين لأي معهد',
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: institutes.length,
                      itemBuilder: (context, index) {
                        final institute = institutes[index];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tokens.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.account_balance,
                                  color: tokens.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      institute.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      institute.location,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.sepia),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) =>
                      ErrorState(message: 'تعذر تحميل المعاهد: $e'),
                ),

                const SizedBox(height: 24),

                Text('الطلاب', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),

                studentsAsync.when(
                  data: (students) {
                    // Institute name lookup, built from the teacher's institutes.
                    final institutes =
                        institutesAsync.asData?.value ??
                        const <InstituteModel>[];
                    final instituteNameById = <String, String>{
                      for (final institute in institutes)
                        institute.id: institute.name,
                    };

                    if (students.isEmpty) {
                      return const EmptyState(
                        icon: Icons.school_outlined,
                        title: 'لا يوجد طلاب لهذا المعلم',
                      );
                    }

                    // Empty selection = "All". Otherwise keep only the students
                    // whose institute is in the selected set.
                    final filtered = _selectedInstituteIds.isEmpty
                        ? students
                        : students
                              .where(
                                (s) => _selectedInstituteIds.contains(
                                  s.student.instituteId,
                                ),
                              )
                              .toList();

                    // Whether the *visible* list spans more than one institute.
                    // The per-card badge is only useful then — when a single
                    // institute is shown the chip already names it.
                    final visibleInstituteIds = filtered
                        .map((s) => s.student.instituteId)
                        .toSet();
                    final showBadges = visibleInstituteIds.length > 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InstituteFilterBar(
                          institutes: institutes,
                          selectedInstituteIds: _selectedInstituteIds,
                          onToggle: _toggleInstitute,
                          onClear: _clearFilter,
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          const EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'لا يوجد طلاب في المعهد المحدد',
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final studentWithUser = filtered[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: StudentCard(
                                  studentWithUser: studentWithUser,
                                  instituteName: showBadges
                                      ? instituteNameById[studentWithUser
                                            .student
                                            .instituteId]
                                      : null,
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
                      ],
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(message: 'تعذر تحميل الطلاب: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المعلم: $e'),
      ),
    );
  }
}

/// Horizontal, scrollable row of multi-select institute filter chips plus an
/// "All" reset affordance. Renders nothing when the teacher has no institutes.
/// RTL-consistent (the parent app forces TextDirection.rtl). See #53.
class _InstituteFilterBar extends StatelessWidget {
  final List<InstituteModel> institutes;
  final Set<String> selectedInstituteIds;
  final void Function(String instituteId, bool selected) onToggle;
  final VoidCallback onClear;

  const _InstituteFilterBar({
    required this.institutes,
    required this.selectedInstituteIds,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (institutes.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = context.tokens;
    final allSelected = selectedInstituteIds.isEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" resets the filter to showing every student.
          FilterChip(
            label: const Text('الكل'),
            selected: allSelected,
            onSelected: (_) => onClear(),
            showCheckmark: false,
            selectedColor: tokens.green.withValues(alpha: 0.15),
            checkmarkColor: tokens.green,
          ),
          const SizedBox(width: 8),
          for (final institute in institutes) ...[
            FilterChip(
              label: Text(institute.name),
              selected: selectedInstituteIds.contains(institute.id),
              onSelected: (selected) => onToggle(institute.id, selected),
              selectedColor: tokens.green.withValues(alpha: 0.15),
              checkmarkColor: tokens.green,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
