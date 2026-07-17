import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Self-service password change for the signed-in user (any role).
/// Proves knowledge of the current password (AuthRepository.changeOwnPassword
/// reauthenticates before updating), so no admin involvement is needed.
class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _submitError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _submitError = null;
    });
    // Capture the messenger before the async gap so nothing touches
    // `context` after the await if the dialog is dismissed mid-flight
    // (ResetPasswordDialog convention).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await ref
        .read(authRepositoryProvider.notifier)
        .changeOwnPassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );

    if (!context.mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _submitError = error;
      });
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppPasswordField(
              label: 'كلمة المرور الحالية',
              controller: _currentController,
              validator: Validators.validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              label: 'كلمة المرور الجديدة',
              controller: _newController,
              validator: Validators.validatePassword,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppPasswordField(
              label: 'تأكيد كلمة المرور الجديدة',
              controller: _confirmController,
              validator: (value) => Validators.validateConfirmPassword(
                value,
                _newController.text,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _submitError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.maroon),
                ),
              ),
            ],
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
