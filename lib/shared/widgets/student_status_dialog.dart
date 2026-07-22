import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student_model.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/student/student_status.dart';
import '../providers/user_provider.dart';
import 'app_button.dart';

/// Supervisor/admin dialog that toggles a student's TEACHING status —
/// نشط ⇄ مستبعد (al_rasikhoon-zg1r) — with an OPTIONAL free-text reason.
///
/// The dialog always offers the OPPOSITE of the student's current status:
/// exclude an active student, restore an excluded one. When restoring, the
/// stored exclusion reason is shown so the decision is made in context.
///
/// Lives in shared/ because both the supervisor and the admin screens open
/// it; each passes [onChanged] to refresh its OWN list provider, so this
/// widget never reaches into a feature folder (al_rasikhoon-pz2).
/// Authorization is enforced by [StudentRepository.setStudentStatus], not
/// here — the dialog is a view, not a boundary.
class StudentStatusDialog extends ConsumerStatefulWidget {
  final StudentModel student;
  final String studentDisplayName;

  /// Called after a successful write — the caller invalidates its own list
  /// provider (supervisorStudentsProvider / allStudentsProvider).
  final VoidCallback onChanged;

  const StudentStatusDialog({
    super.key,
    required this.student,
    required this.studentDisplayName,
    required this.onChanged,
  });

  @override
  ConsumerState<StudentStatusDialog> createState() =>
      _StudentStatusDialogState();
}

class _StudentStatusDialogState extends ConsumerState<StudentStatusDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _isExcluding => !widget.student.isExcluded;

  StudentStatus get _targetStatus =>
      _isExcluding ? StudentStatus.excluded : StudentStatus.active;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isLoading) return;
    final actor = ref.read(currentUserProvider);
    if (actor == null) {
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Capture the messenger and navigator before the async gap so a
    // dismissed dialog never touches a defunct context (mirrors
    // AssignTeacherDialog's hardening).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(studentRepositoryProvider)
          .setStudentStatus(
            studentId: widget.student.id,
            status: _targetStatus,
            reason: _reasonController.text,
            actor: actor,
          );
      widget.onChanged();
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isExcluding
                ? 'تم استبعاد ${widget.studentDisplayName} من التدريس'
                : 'تم إلغاء استبعاد ${widget.studentDisplayName}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('setStudentStatus failed: $e');
      if (!context.mounted) return;
      setState(() => _error = 'حدث خطأ، يرجى المحاولة مرة أخرى');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storedReason = widget.student.statusReason;

    return AlertDialog(
      title: Text(
        _isExcluding
            ? 'استبعاد ${widget.studentDisplayName} من التدريس'
            : 'إلغاء استبعاد ${widget.studentDisplayName}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isExcluding
                ? 'لن يظهر الطالب في قوائم المعلم حتى يتم إلغاء الاستبعاد. '
                      'يبقى الطالب ظاهرًا للمشرف والمدير.'
                : 'سيعود الطالب للظهور في قوائم المعلم.',
          ),
          if (!_isExcluding && storedReason != null) ...[
            const SizedBox(height: 12),
            Text(
              'سبب الاستبعاد الحالي:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(storedReason),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'السبب (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        AppButton(
          text: _isExcluding ? 'استبعاد' : 'إلغاء الاستبعاد',
          onPressed: _handleConfirm,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
