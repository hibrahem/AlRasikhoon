import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/supervisor_provider.dart';

/// Supervisor-only dialog that gives a student a teacher (al_rasikhoon-6bw).
/// This is the rescue path for a student who is ALREADY teacher-less: a
/// student with no `teacher_id` sits in no teacher's roster, so nobody can
/// ever conduct their حلقة or their سرد. Lists the teachers of the STUDENT's
/// OWN institute via [supervisorInstituteTeachersProvider] (al_rasikhoon-3n6:
/// a supervisor may supervise several institutes, so the pool is scoped to the
/// student's institute — not a blur across all of them) and writes the choice
/// with [StudentRepository.assignTeacher] — a focused, single-field write, not
/// [StudentRepository.updateStudent].
class AssignTeacherDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentDisplayName;

  /// The institute the student belongs to — the teacher pool is scoped to it.
  final String instituteId;

  const AssignTeacherDialog({
    super.key,
    required this.studentId,
    required this.studentDisplayName,
    required this.instituteId,
  });

  @override
  ConsumerState<AssignTeacherDialog> createState() =>
      _AssignTeacherDialogState();
}

class _AssignTeacherDialogState extends ConsumerState<AssignTeacherDialog> {
  UserModel? _selectedTeacher;
  bool _isLoading = false;
  String? _error;

  Future<void> _handleAssign() async {
    if (_isLoading) return;
    final teacher = _selectedTeacher;
    if (teacher == null) {
      setState(() => _error = 'يرجى اختيار المعلم');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Capture the messenger and navigator before the async gap so a
    // dismissed dialog never touches a defunct context (mirrors
    // ResetPasswordDialog's hardening, #18).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      await studentRepo.assignTeacher(
        studentId: widget.studentId,
        teacherId: teacher.id,
      );
      ref.invalidate(supervisorStudentsProvider);
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'تم تعيين ${teacher.name} معلمًا لـ ${widget.studentDisplayName}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('assignTeacher failed: $e');
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
    final teachersAsync = ref.watch(
      supervisorInstituteTeachersProvider(widget.instituteId),
    );

    return AlertDialog(
      title: Text('تعيين معلم لـ ${widget.studentDisplayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المعلم', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<UserModel>(
                isExpanded: true,
                value: _selectedTeacher,
                hint: Text(
                  teachersAsync.isLoading ? 'جارٍ التحميل...' : 'اختر المعلم',
                ),
                items: (teachersAsync.value ?? const <UserModel>[]).map((
                  teacher,
                ) {
                  return DropdownMenuItem(
                    value: teacher,
                    child: Text(teacher.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTeacher = value;
                    _error = null;
                  });
                },
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
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
          text: 'تعيين معلم',
          onPressed: _handleAssign,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
