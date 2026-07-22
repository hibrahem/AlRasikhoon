import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/admin_provider.dart';

/// Super-admin-only warning gate in front of the irreversible hard delete of
/// a student (StudentRepository.hardDeleteStudent → hardDeleteStudent Cloud
/// Function). Spells out exactly what is erased before asking for
/// confirmation — this is the one flow in the app that truly destroys data,
/// so the wording must leave no room for "I thought it was archiving".
class DeleteStudentDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentDisplayName;

  const DeleteStudentDialog({
    super.key,
    required this.studentId,
    required this.studentDisplayName,
  });

  @override
  ConsumerState<DeleteStudentDialog> createState() =>
      _DeleteStudentDialogState();
}

class _DeleteStudentDialogState extends ConsumerState<DeleteStudentDialog> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    // Capture the messenger and token colors before the async gap so the
    // SnackBars never touch `context` after the await — mirrors the
    // ResetPasswordDialog hardening (#18).
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.tokens.maroon;
    try {
      await ref
          .read(studentRepositoryProvider)
          .hardDeleteStudent(widget.studentId);
      // The student and their stats are gone; refresh every admin list that
      // could still be showing them.
      ref.invalidate(allStudentsProvider);
      ref.invalidate(adminStatsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم حذف الطالب ${widget.studentDisplayName} نهائيًا'),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل حذف الطالب: ${e.message ?? e.code}'),
          backgroundColor: errorColor,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: errorColor),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: tokens.maroon, size: 32),
      title: const Text('حذف الطالب نهائيًا؟'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سيتم حذف الطالب ${widget.studentDisplayName} وجميع بياناته '
            'نهائيًا:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '• سجلات الجلسات والسرد والاختبارات\n'
            '• التسميع المنزلي\n'
            '• حساب الدخول الخاص به',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'لا يمكن التراجع عن هذا الإجراء.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.maroon,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        AppButton(
          text: 'حذف نهائيًا',
          onPressed: _handleDelete,
          isLoading: _isLoading,
          backgroundColor: tokens.maroon,
        ),
      ],
    );
  }
}
