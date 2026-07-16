import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/icon_medallion.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);

    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignTeacherToInstitute(
        teacherId: teacher.id,
        instituteId: instituteId,
      );
      ref.invalidate(teachersForInstituteProvider(instituteId));

      messenger.showSnackBar(
        SnackBar(content: Text('تم إضافة ${teacher.name} بنجاح')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل في إضافة المعلم: $e'),
          backgroundColor: maroon,
        ),
      );
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
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);

    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeTeacherFromInstitute(
        teacherId: teacher.id,
        instituteId: instituteId,
      );
      ref.invalidate(teachersForInstituteProvider(instituteId));

      messenger.showSnackBar(
        SnackBar(content: Text('تم إزالة ${teacher.name} بنجاح')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل في إزالة المعلم: $e'),
          backgroundColor: maroon,
        ),
      );
    }
  }

  void _showAddSupervisorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final allSupervisorsAsync = ref.watch(allSupervisorsProvider);
          final assignedSupervisorsAsync = ref.watch(
            supervisorsForInstituteProvider(instituteId),
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
                        'إضافة مشرف',
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
                  child: allSupervisorsAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: 'خطأ: $e'),
                    data: (allSupervisors) => assignedSupervisorsAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: 'خطأ: $e'),
                      data: (assignedSupervisors) {
                        final assignedIds = assignedSupervisors
                            .map((s) => s.id)
                            .toSet();
                        final available = allSupervisors
                            .where((s) => !assignedIds.contains(s.id))
                            .toList();

                        if (available.isEmpty) {
                          return const Center(
                            child: Text('لا يوجد مشرفون متاحون للإضافة'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final supervisor = available[index];
                            return _SupervisorSelectionTile(
                              supervisor: supervisor,
                              onTap: () =>
                                  _assignSupervisor(context, ref, supervisor),
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

  Future<void> _assignSupervisor(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignSupervisorToInstitute(
        supervisorId: supervisor.id,
        instituteId: instituteId,
      );
      ref.invalidate(supervisorsForInstituteProvider(instituteId));
      ref.invalidate(institutesForSupervisorProvider(supervisor.id));
      ref.invalidate(allSupervisorsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('تم إضافة ${supervisor.name} بنجاح')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل في إضافة المشرف: $e'),
          backgroundColor: maroon,
        ),
      );
    }
  }

  void _showRemoveSupervisorDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة المشرف'),
        content: Text(
          'هل أنت متأكد من إزالة ${supervisor.name} من هذا المعهد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => _removeSupervisor(context, ref, supervisor),
            style: TextButton.styleFrom(foregroundColor: context.tokens.maroon),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSupervisor(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeSupervisorFromInstitute(
        supervisorId: supervisor.id,
        instituteId: instituteId,
      );
      ref.invalidate(supervisorsForInstituteProvider(instituteId));
      ref.invalidate(institutesForSupervisorProvider(supervisor.id));
      ref.invalidate(allSupervisorsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('تم إزالة ${supervisor.name} بنجاح')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل في إزالة المشرف: $e'),
          backgroundColor: maroon,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final instituteAsync = ref.watch(instituteProvider(instituteId));
    final teachersAsync = ref.watch(teachersForInstituteProvider(instituteId));
    final supervisorsAsync = ref.watch(
      supervisorsForInstituteProvider(instituteId),
    );

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
                      IconMedallion(
                        icon: Icons.account_balance,
                        accent: tokens.green,
                        size: 56,
                        iconSize: 26,
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
                const SizedBox(height: 24),
                // Supervisors section — mirrors the teachers section above.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المشرفون',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddSupervisorSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                supervisorsAsync.when(
                  data: (supervisors) {
                    if (supervisors.isEmpty) {
                      return EmptyState(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'لا يوجد مشرفون',
                        action: AppButton(
                          text: 'إضافة مشرف',
                          onPressed: () =>
                              _showAddSupervisorSheet(context, ref),
                          type: AppButtonType.outline,
                          size: AppButtonSize.small,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: supervisors.length,
                      itemBuilder: (context, index) {
                        final supervisor = supervisors[index];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: () => context.push(
                            AppRoutes.supervisorDetail.replaceFirst(
                              ':id',
                              supervisor.id,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: tokens.gold.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  supervisor.name.isNotEmpty
                                      ? supervisor.name[0]
                                      : '?',
                                  style: TextStyle(
                                    color: tokens.gold,
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
                                      supervisor.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      supervisor.phone ??
                                          supervisor.displayUsername,
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
                                onPressed: () => _showRemoveSupervisorDialog(
                                  context,
                                  ref,
                                  supervisor,
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
                      ErrorState(message: 'تعذر تحميل المشرفين: $e'),
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

class _SupervisorSelectionTile extends StatelessWidget {
  final UserModel supervisor;
  final VoidCallback onTap;

  const _SupervisorSelectionTile({
    required this.supervisor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: tokens.gold.withValues(alpha: 0.1),
        child: Text(
          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
          style: TextStyle(color: tokens.gold, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(supervisor.name),
      subtitle: Text(supervisor.phone ?? supervisor.displayUsername),
      trailing: Icon(Icons.add_circle_outline, color: tokens.gold),
      onTap: onTap,
    );
  }
}
