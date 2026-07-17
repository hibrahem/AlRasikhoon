import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../features/auth/widgets/reset_password_dialog.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/edit_profile_dialog.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/states/empty_state.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// Admin detail for one supervisor: identity header + the set of institutes the
/// supervisor is assigned to (via `supervisor_institutes` membership), with
/// assign (bottom sheet of not-yet-assigned institutes) and remove (confirm
/// dialog, soft-delete). Parallel to [InstituteDetailScreen]'s teachers
/// section, viewed from the supervisor side.
class SupervisorDetailScreen extends ConsumerWidget {
  final String supervisorId;

  const SupervisorDetailScreen({super.key, required this.supervisorId});

  void _refresh(WidgetRef ref, String instituteId) {
    ref.invalidate(institutesForSupervisorProvider(supervisorId));
    ref.invalidate(supervisorsForInstituteProvider(instituteId));
    ref.invalidate(allSupervisorsProvider);
  }

  void _showAssignInstituteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final allInstitutesAsync = ref.watch(institutesProvider);
          final assignedAsync = ref.watch(
            institutesForSupervisorProvider(supervisorId),
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
                        'إسناد معهد',
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
                  child: allInstitutesAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) {
                      debugPrint('institutesProvider failed: $e');
                      return ErrorState(
                        message: 'تعذر تحميل المعاهد',
                        onRetry: () => ref.invalidate(institutesProvider),
                      );
                    },
                    data: (allInstitutes) => assignedAsync.when(
                      loading: () => const LoadingState(),
                      error: (e, _) {
                        debugPrint(
                          'institutesForSupervisorProvider failed: $e',
                        );
                        return ErrorState(
                          message: 'تعذر تحميل المعاهد المسندة',
                          onRetry: () => ref.invalidate(
                            institutesForSupervisorProvider(supervisorId),
                          ),
                        );
                      },
                      data: (assigned) {
                        final assignedIds = assigned.map((i) => i.id).toSet();
                        final available = allInstitutes
                            .where((i) => !assignedIds.contains(i.id))
                            .toList();

                        if (available.isEmpty) {
                          return const Center(
                            child: Text('لا توجد معاهد متاحة للإسناد'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: available.length,
                          itemBuilder: (context, index) {
                            final institute = available[index];
                            return _InstituteSelectionTile(
                              institute: institute,
                              onTap: () =>
                                  _assignInstitute(context, ref, institute),
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

  Future<void> _assignInstitute(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.assignSupervisorToInstitute(
        supervisorId: supervisorId,
        instituteId: institute.id,
      );
      _refresh(ref, institute.id);
      messenger.showSnackBar(
        SnackBar(content: Text('تم إسناد ${institute.name} بنجاح')),
      );
    } catch (e) {
      debugPrint('assignSupervisorToInstitute failed: $e');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('فشل في إسناد المعهد، حاول مرة أخرى'),
          backgroundColor: maroon,
        ),
      );
    }
  }

  void _showRemoveInstituteDialog(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة الإسناد'),
        content: Text('هل أنت متأكد من إزالة إسناد ${institute.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => _removeInstitute(context, ref, institute),
            style: TextButton.styleFrom(foregroundColor: context.tokens.maroon),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeInstitute(
    BuildContext context,
    WidgetRef ref,
    InstituteModel institute,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final maroon = context.tokens.maroon;
    Navigator.pop(context);
    try {
      final repo = ref.read(instituteRepositoryProvider);
      await repo.removeSupervisorFromInstitute(
        supervisorId: supervisorId,
        instituteId: institute.id,
      );
      _refresh(ref, institute.id);
      messenger.showSnackBar(
        SnackBar(content: Text('تم إزالة إسناد ${institute.name}')),
      );
    } catch (e) {
      debugPrint('removeSupervisorFromInstitute failed: $e');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('فشل في إزالة الإسناد، حاول مرة أخرى'),
          backgroundColor: maroon,
        ),
      );
    }
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    UserModel supervisor,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => EditProfileDialog(
        initialName: supervisor.name,
        initialPhone: supervisor.phone,
        onSave: (name, phone) async {
          await ref
              .read(userRepositoryProvider)
              .updateProfileFields(
                userId: supervisor.id,
                name: name,
                phone: phone,
              );
          ref.invalidate(supervisorProvider(supervisorId));
          ref.invalidate(allSupervisorsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final supervisorAsync = ref.watch(supervisorProvider(supervisorId));
    final institutesAsync = ref.watch(
      institutesForSupervisorProvider(supervisorId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المشرف'),
        actions: [
          // Account-level actions on the supervisor live with the screen
          // chrome, mirroring TeacherDetailScreen. The setUserPassword Cloud
          // Function already authorizes super_admin → any user.
          if (supervisorAsync.asData?.value != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل الملف الشخصي',
              onPressed: () => _showEditProfileDialog(
                context,
                ref,
                supervisorAsync.asData!.value!,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.lock_reset),
              tooltip: 'إعادة تعيين كلمة المرور',
              onPressed: () {
                final supervisor = supervisorAsync.asData!.value!;
                showDialog<void>(
                  context: context,
                  builder: (_) => ResetPasswordDialog(
                    userId: supervisor.id,
                    userDisplayName: supervisor.name,
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: supervisorAsync.when(
        data: (supervisor) {
          if (supervisor == null) {
            return const Center(child: Text('المشرف غير موجود'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: tokens.gold.withValues(alpha: 0.1),
                        child: Text(
                          supervisor.name.isNotEmpty ? supervisor.name[0] : '?',
                          style: TextStyle(
                            color: tokens.gold,
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
                              supervisor.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              supervisor.phone ?? supervisor.displayUsername,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: tokens.sepia),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المعاهد المسندة',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton.icon(
                      onPressed: () => _showAssignInstituteSheet(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إسناد'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                institutesAsync.when(
                  data: (institutes) {
                    if (institutes.isEmpty) {
                      return EmptyState(
                        icon: Icons.account_balance_outlined,
                        title: 'لا توجد معاهد مسندة',
                        action: AppButton(
                          text: 'إسناد معهد',
                          onPressed: () =>
                              _showAssignInstituteSheet(context, ref),
                          type: AppButtonType.outline,
                          size: AppButtonSize.small,
                        ),
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
                          onTap: () => context.push(
                            AppRoutes.instituteDetail.replaceFirst(
                              ':id',
                              institute.id,
                            ),
                          ),
                          child: Row(
                            children: [
                              IconMedallion(
                                icon: Icons.account_balance,
                                accent: tokens.green,
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
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: tokens.maroon,
                                ),
                                onPressed: () => _showRemoveInstituteDialog(
                                  context,
                                  ref,
                                  institute,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const LoadingState(),
                  error: (e, _) {
                    debugPrint('institutesForSupervisorProvider failed: $e');
                    return ErrorState(
                      message: 'تعذر تحميل المعاهد',
                      onRetry: () => ref.invalidate(
                        institutesForSupervisorProvider(supervisorId),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) {
          debugPrint('supervisorProvider failed: $e');
          return ErrorState(
            message: 'تعذر تحميل المشرف',
            onRetry: () => ref.invalidate(supervisorProvider(supervisorId)),
          );
        },
      ),
    );
  }
}

class _InstituteSelectionTile extends StatelessWidget {
  final InstituteModel institute;
  final VoidCallback onTap;

  const _InstituteSelectionTile({required this.institute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListTile(
      leading: IconMedallion(
        icon: Icons.account_balance,
        accent: tokens.green,
        size: 40,
        iconSize: 20,
      ),
      title: Text(institute.name),
      subtitle: Text(institute.location),
      trailing: Icon(Icons.add_circle_outline, color: tokens.green),
      onTap: onTap,
    );
  }
}
