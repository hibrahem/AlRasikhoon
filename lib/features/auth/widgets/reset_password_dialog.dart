import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Admin-only dialog for resetting another user's password. Calls the
/// setUserPassword Cloud Function via AuthRepository.setPasswordForUser.
/// On success, displays the new password back to the admin once with a
/// copy button so they can communicate it out-of-band.
class ResetPasswordDialog extends ConsumerStatefulWidget {
  final String userId;
  final String userDisplayName;

  const ResetPasswordDialog({
    super.key,
    required this.userId,
    required this.userDisplayName,
  });

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _committedPassword;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // Capture the messenger before the async gap so error-path SnackBars
    // never touch `context` after the await. If the dialog is dismissed
    // while setPasswordForUser is in flight, `context` may point at a
    // defunct element; the captured messenger reference stays valid.
    // Mirrors the copy-button hardening from #18. The post-await
    // `if (!context.mounted) return;` guards the actual context/element
    // (not the bare State.mounted getter, which can pass while the
    // specific element is gone).
    final messenger = ScaffoldMessenger.of(context);
    try {
      final authRepo = ref.read(authRepositoryProvider.notifier);
      await authRepo.setPasswordForUser(
        userId: widget.userId,
        newPassword: _passwordController.text,
      );
      if (!context.mounted) return;
      setState(() => _committedPassword = _passwordController.text);
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل إعادة التعيين: ${e.message ?? e.code}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_committedPassword != null) {
      return AlertDialog(
        title: const Text('تم تعيين كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'كلمة المرور الجديدة لـ ${widget.userDisplayName}:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _committedPassword!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'نسخ',
                    onPressed: () async {
                      // Capture the messenger before the async gap so we
                      // never touch `context` after the await. If the
                      // dialog is dismissed while Clipboard.setData is in
                      // flight, `context` may point at a defunct element;
                      // the captured messenger reference stays valid.
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: _committedPassword!),
                      );
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('تم نسخ كلمة المرور')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لن تظهر مرة أخرى. شاركها مع المستخدم الآن.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('إعادة تعيين كلمة مرور ${widget.userDisplayName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPasswordField(
              label: 'كلمة المرور الجديدة',
              controller: _passwordController,
              validator: Validators.validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              label: 'تأكيد كلمة المرور',
              controller: _confirmController,
              validator: (value) => Validators.validateConfirmPassword(
                value,
                _passwordController.text,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        AppButton(text: 'حفظ', onPressed: _handleSubmit, isLoading: _isLoading),
      ],
    );
  }
}
