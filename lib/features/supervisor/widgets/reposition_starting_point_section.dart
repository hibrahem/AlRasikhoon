import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/student_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/curriculum/curriculum_position.dart';
import '../../../domain/curriculum/reposition_exceptions.dart';
import '../../../shared/providers/user_provider.dart';
import '../../teacher/widgets/starting_point_picker.dart';
import '../providers/supervisor_provider.dart';

/// The supervisor-only "edit starting point" affordance (al_rasikhoon-sne),
/// injected into the shared student-progress screen for the supervisor shell.
///
/// It offers the edit ONLY while the student has not started — zero
/// session/سرد/اختبار records — because moving the enrollment anchor is a pure
/// re-derivation only then. Once the student has started, the section hides
/// itself entirely (the edit is not offered), and the repository write path
/// rejects a stale attempt regardless. It renders nothing until it positively
/// knows both the student and that they have not started, so it never flashes an
/// affordance it would have to retract.
class RepositionStartingPointSection extends ConsumerWidget {
  final String studentId;

  const RepositionStartingPointSection({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(supervisorStudentProvider(studentId));
    final hasStartedAsync = ref.watch(
      supervisorStudentHasStartedProvider(studentId),
    );

    final student = studentAsync.asData?.value?.student;
    final hasStarted = hasStartedAsync.asData?.value;

    // Offer the edit only when we KNOW the student exists and has not started.
    // A null (loading/error) or a started student shows nothing at all.
    if (student == null || hasStarted == null || hasStarted) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: const Key('reposition_starting_point_button'),
        leading: const Icon(Icons.edit_location_alt, color: AppColors.primary),
        title: const Text('تعديل نقطة البداية'),
        subtitle: const Text(
          'الطالب لم يبدأ بعد — يمكن نقل نقطة بدايته في المنهج.',
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => _openEditor(context, ref, student),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    StudentModel student,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RepositionDialog(student: student),
    );
  }
}

/// The modal that re-picks the starting point. Seeds [StartingPointPicker] from
/// the student's CURRENT enrollment anchor, tracks the picker's selection, and
/// on confirm calls the authoritative
/// [StudentRepository.repositionEnrolledStudent] — which re-verifies the
/// supervisor, the zero-records invariant and the position before writing.
class _RepositionDialog extends ConsumerStatefulWidget {
  final StudentModel student;

  const _RepositionDialog({required this.student});

  @override
  ConsumerState<_RepositionDialog> createState() => _RepositionDialogState();
}

class _RepositionDialogState extends ConsumerState<_RepositionDialog> {
  late CurriculumPosition? _selected = widget.student.enrollmentPosition;
  bool _isSaving = false;

  Future<void> _save() async {
    if (_isSaving) return;
    final position = _selected;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نقطة بداية صالحة في المنهج'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final actor = ref.read(currentUserProvider);
    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('انتهت الجلسة، يرجى تسجيل الدخول من جديد'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(studentRepositoryProvider)
          .repositionEnrolledStudent(
            studentId: widget.student.id,
            newPosition: position,
            actor: actor,
          );

      // The student list is the root of the supervisor's student providers, so
      // invalidating it re-derives the detail, the meeting and the has-started
      // gate off fresh data.
      ref.invalidate(supervisorStudentsProvider);
      ref.invalidate(supervisorStudentProvider(widget.student.id));
      ref.invalidate(supervisorStudentHasStartedProvider(widget.student.id));
      ref.invalidate(
        supervisorStudentCurrentMeetingProvider(widget.student.id),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث نقطة البداية'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on StudentAlreadyStartedException {
      _showError('لا يمكن التعديل: الطالب بدأ المنهج بالفعل.');
    } on RepositionNotAuthorizedException {
      _showError('غير مصرح لك بتعديل نقطة البداية لهذا الطالب.');
    } catch (e) {
      debugPrint('repositionEnrolledStudent failed: $e');
      _showError('تعذر تحديث نقطة البداية، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل نقطة البداية'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: StartingPointPicker(
            initialValue: widget.student.enrollmentPosition,
            onChanged: (position) => setState(() => _selected = position),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
