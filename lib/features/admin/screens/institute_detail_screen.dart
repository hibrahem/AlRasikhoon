import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

class InstituteDetailScreen extends ConsumerWidget {
  final String instituteId;

  const InstituteDetailScreen({super.key, required this.instituteId});

  void _showAddTeacherSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final allTeachersAsync = ref.watch(allTeachersProvider);
          final assignedTeachersAsync = ref.watch(
            teachersForInstituteProvider(instituteId),
          );

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة معلم',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: allTeachersAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: 'خطأ: $e'),
                    data: (allTeachers) => assignedTeachersAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: 'خطأ: $e'),
                      data: (assignedTeachers) {
                        final assignedIds = assignedTeachers
                            .map((t) => t.id)
                            .toSet();
                        final availableTeachers = allTeachers
                            .where((t) => !assignedIds.contains(t.id))
                            .toList();

                        if (availableTeachers.isEmpty) {
                          return const Center(
                            child: Text('لا يوجد معلمون متاحون للإضافة'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: availableTeachers.length,
                          itemBuilder: (context, index) {
                            final teacher = availableTeachers[index];
                            return _TeacherSelectionTile(
                              teacher: teacher,
                              onTap: () =>
                                  _assignTeacher(context, ref, teacher),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignTeacher(
    BuildContext context,
    WidgetRef ref,
    UserModel teacher,
  ) async {
    Navigator.pop(context);

    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignTeacherToInstitute(
        teacherId: teacher.id,
        instituteId: instituteId,
      );
      ref.invalidate(teachersForInstituteProvider(instituteId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة ${teacher.name} بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إضافة المعلم: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  void _showRemoveTeacherDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel teacher,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة المعلم'),
        content: Text('هل أنت متأكد من إزالة ${teacher.name} من هذا المعهد؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => _removeTeacher(context, ref, teacher),
            style: TextButton.styleFrom(foregroundColor: context.tokens.maroon),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeTeacher(
    BuildContext context,
    WidgetRef ref,
    UserModel teacher,
  ) async {
    Navigator.pop(context);

    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeTeacherFromInstitute(
        teacherId: teacher.id,
        instituteId: instituteId,
      );
      ref.invalidate(teachersForInstituteProvider(instituteId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إزالة ${teacher.name} بنجاح')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في إزالة المعلم: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final instituteAsync = ref.watch(instituteProvider(instituteId));
    final teachersAsync = ref.watch(teachersForInstituteProvider(instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المعهد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.push(
                AppRoutes.editInstitute.replaceFirst(':id', instituteId),
              );
            },
          ),
        ],
      ),
      body: instituteAsync.when(
        data: (institute) {
          if (institute == null) {
            return const Center(child: Text('المعهد غير موجود'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Institute header
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          color: tokens.green,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              institute.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: tokens.sepia,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  institute.location,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: tokens.sepia),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Teachers section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المعلمون',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddTeacherSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                teachersAsync.when(
                  data: (teachers) {
                    if (teachers.isEmpty) {
                      return EmptyState(
                        icon: Icons.people_outline,
                        title: 'لا يوجد معلمون',
                        action: AppButton(
                          text: 'إضافة معلم',
                          onPressed: () => _showAddTeacherSheet(context, ref),
                          type: AppButtonType.outline,
                          size: AppButtonSize.small,
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () => context.push(
                            AppRoutes.teacherDetail.replaceFirst(
                              ':id',
                              teacher.id,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
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
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacher.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      teacher.phone ?? teacher.displayUsername,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: tokens.sepia),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: tokens.maroon,
                                ),
                                onPressed: () => _showRemoveTeacherDialog(
                                  context,
                                  ref,
                                  teacher,
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
                      ErrorState(message: 'تعذر تحميل المعلمين: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: 'تعذر تحميل المعهد: $e'),
      ),
    );
  }
}

class _TeacherSelectionTile extends StatelessWidget {
  final UserModel teacher;
  final VoidCallback onTap;

  const _TeacherSelectionTile({required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.green.withValues(alpha: 0.1),
        child: Text(
          teacher.name.isNotEmpty ? teacher.name[0] : '?',
          style: TextStyle(color: tokens.green, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(teacher.name),
      subtitle: Text(teacher.phone ?? teacher.displayUsername),
      trailing: Icon(Icons.add_circle_outline, color: tokens.green),
      onTap: onTap,
    );
  }
}
