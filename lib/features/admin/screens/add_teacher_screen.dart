import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/countries.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/firebase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../providers/admin_provider.dart';

class AddTeacherScreen extends ConsumerStatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  ConsumerState<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends ConsumerState<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  Country _selectedCountry = Countries.defaultCountry;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(userRepositoryProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final synthesizedEmail =
          '$username@${AppConstants.synthesizedEmailDomain}';

      // Username uniqueness check
      final existing = await repo.getUserByUsername(username);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('اسم المستخدم مسجل مسبقاً'),
              backgroundColor: context.tokens.maroon,
            ),
          );
        }
        return;
      }

      String? phone;
      if (_phoneController.text.isNotEmpty) {
        phone = Validators.formatPhoneWithCountryCode(
          _phoneController.text,
          country: _selectedCountry,
        );
      }

      final newUid = await firebaseService.provisionUserAccount(
        email: synthesizedEmail,
        password: password,
        role: 'teacher',
        name: _nameController.text.trim(),
        username: username,
        phone: phone,
      );

      // The account is provisioned server-side by the Cloud Function, so the
      // local Firestore cache has no copy of the new teacher doc. A bare
      // invalidate races the write's propagation to the query index, which is
      // why the new teacher only *sometimes* appeared in the list (issue #21).
      // Deterministically confirm the write is queryable from the server
      // before invalidating, so the provider's refetch sees the new teacher.
      await repo.getTeachersConfirmingUid(newUid);

      ref.invalidate(allTeachersProvider);
      ref.invalidate(adminStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة المعلم: ${_nameController.text.trim()}'),
            backgroundColor: context.tokens.green,
          ),
        );
        context.pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        final msg =
            (e.message == 'email-already-in-use' ||
                e.message == 'username-taken')
            ? 'اسم المستخدم مسجل مسبقاً'
            : e.message == 'weak-password'
            ? 'كلمة المرور ضعيفة'
            : 'فشل إنشاء الحساب: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: context.tokens.maroon),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: context.tokens.maroon,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة معلم')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Screen emblem: the design system's medallion disc, centered
              // so the stretched form column can't distort it into an ellipse.
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 32),
                child: Center(
                  child: IconMedallion(
                    icon: Icons.person_add,
                    accent: tokens.green,
                    size: 80,
                    iconSize: 40,
                  ),
                ),
              ),
              AppTextField(
                label: 'اسم المعلم',
                hint: 'الاسم الكامل',
                controller: _nameController,
                validator: Validators.validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'اسم المستخدم',
                hint: 'username',
                controller: _usernameController,
                validator: Validators.validateUsername,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              const SizedBox(height: 20),
              AppPasswordField(
                controller: _passwordController,
                validator: Validators.validatePassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AppPasswordField(
                label: 'تأكيد كلمة المرور',
                controller: _confirmPasswordController,
                validator: (value) => Validators.validateConfirmPassword(
                  value,
                  _passwordController.text,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AppPhoneField(
                controller: _phoneController,
                initialCountry: _selectedCountry,
                isOptional: true,
                onCountryChanged: (country) {
                  setState(() => _selectedCountry = country);
                },
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // No manuscript token for the old "info" blue. Neutral
                  // instructional notice (share credentials), not a
                  // success/error/warning — gold follows the same
                  // neutral-notice precedent as the exam card on
                  // student_dashboard_screen.dart, matching
                  // add_supervisor_screen.dart's identical tip box.
                  color: tokens.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: tokens.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'شارك اسم المستخدم وكلمة المرور مع المعلم. يمكنه تسجيل الدخول مباشرة بهما.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.gold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'إضافة المعلم',
                onPressed: _handleCreate,
                isLoading: _isLoading,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
