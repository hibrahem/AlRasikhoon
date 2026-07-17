import 'package:flutter/material.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// Edit a user's profile fields (name + optional phone). Persistence is
/// INJECTED via [onSave] so the same dialog serves both flows:
///   - self-service (settings screen → AuthRepository.updateOwnProfile)
///   - admin editing another user (detail screens →
///     UserRepository.updateProfileFields + provider invalidation)
/// [onSave] receives the trimmed name and the full international phone
/// (or null when cleared); throwing keeps the dialog open and surfaces the
/// failure, returning normally closes it.
class EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String? initialPhone;
  final String title;
  final Future<void> Function(String name, String? phone) onSave;

  const EditProfileDialog({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
    this.title = 'تعديل الملف الشخصي',
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late Country _selectedCountry;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);

    // Prefill from the stored full international number: recover the country
    // off the dial code and show only the national part in the field.
    final storedPhone = widget.initialPhone ?? '';
    final matched = Countries.findByPhone(storedPhone);
    _selectedCountry = matched ?? Countries.defaultCountry;
    final nationalPart = matched != null
        ? storedPhone.substring(matched.dialCode.length)
        : storedPhone;
    _phoneController = TextEditingController(text: nationalPart);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // Capture the messenger and token color before the async gap so the
    // error path never touches `context` after the await (the dialog may be
    // dismissed while onSave is in flight) — ResetPasswordDialog convention.
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.tokens.maroon;
    final navigator = Navigator.of(context);

    final name = _nameController.text.trim();
    final phoneText = _phoneController.text.trim();
    final phone = phoneText.isEmpty
        ? null
        : Validators.formatPhoneWithCountryCode(
            phoneText,
            country: _selectedCountry,
          );

    try {
      await widget.onSave(name, phone);
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات')));
    } catch (e) {
      debugPrint('EditProfileDialog onSave failed: $e');
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('فشل حفظ التعديلات، حاول مرة أخرى'),
          backgroundColor: errorColor,
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
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              label: 'الاسم',
              controller: _nameController,
              validator: Validators.validateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppPhoneField(
              controller: _phoneController,
              isOptional: true,
              initialCountry: _selectedCountry,
              onCountryChanged: (country) {
                setState(() => _selectedCountry = country);
              },
              validator: (value) =>
                  Validators.validateOptionalPhone(value, _selectedCountry),
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
