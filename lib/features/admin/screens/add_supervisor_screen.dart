import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/countries.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/firebase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/admin_provider.dart';

/// Admin flow to create a Supervisor account bound to a single institute.
///
/// Parallel to [AddTeacherScreen] (used as a read-only template) but adds a
/// required institute selector: one institute per supervisor, many supervisors
/// per institute. The created account carries role=supervisor + instituteId so
/// the supervisor experience resolves their institute and later scoping work
/// can enforce it.
class AddSupervisorScreen extends ConsumerStatefulWidget {
  const AddSupervisorScreen({super.key});

  @override
  ConsumerState<AddSupervisorScreen> createState() =>
      _AddSupervisorScreenState();
}

class _AddSupervisorScreenState extends ConsumerState<AddSupervisorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  Country _selectedCountry = Countries.defaultCountry;
  InstituteModel? _selectedInstitute;

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

    if (_selectedInstitute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار المعهد'),
          backgroundColor: context.tokens.maroon,
        ),
      );
      return;
    }

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

      await firebaseService.provisionUserAccount(
        email: synthesizedEmail,
        password: password,
        role: 'supervisor',
        name: _nameController.text.trim(),
        username: username,
        phone: phone,
        instituteId: _selectedInstitute!.id,
      );

      ref.invalidate(allSupervisorsProvider);
      ref.invalidate(adminStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة المشرف: ${_nameController.text.trim()}'),
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
            : e.message == 'institute-not-found'
            ? 'المعهد المحدد غير موجود'
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
    final institutesAsync = ref.watch(institutesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مشرف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Screen emblem: the design system's medallion disc, centered
              // so the stretched form column can't distort it into an ellipse.
              // Gold stays: the supervisor accent used across admin lists.
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 32),
                child: Center(
                  child: IconMedallion(
                    icon: Icons.admin_panel_settings,
                    accent: tokens.gold,
                    size: 80,
                    iconSize: 40,
                  ),
                ),
              ),
              AppTextField(
                label: 'اسم المشرف',
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
              const SizedBox(height: 24),
              // Required institute selector — one institute per supervisor.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المعهد', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  institutesAsync.when(
                    data: (institutes) {
                      if (institutes.isEmpty) {
                        // A compact inline warning inside the form (not a
                        // full-page empty state) — the admin must create an
                        // institute before this form can proceed, so maroon
                        // (the palette's rubrication/emphasis hue) applies.
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.maroon.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tokens.maroon.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'لا توجد معاهد. أنشئ معهداً أولاً قبل إضافة مشرف.',
                            style: TextStyle(color: tokens.maroon),
                          ),
                        );
                      }
                      // Drop a stale selection if the list changed.
                      if (_selectedInstitute != null &&
                          !institutes.contains(_selectedInstitute)) {
                        _selectedInstitute = null;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: tokens.hairline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<InstituteModel>(
                            isExpanded: true,
                            value: _selectedInstitute,
                            hint: const Text('اختر المعهد'),
                            items: institutes.map((institute) {
                              return DropdownMenuItem(
                                value: institute,
                                child: Text(institute.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedInstitute = value);
                            },
                          ),
                        ),
                      );
                    },
                    // Compact loading placeholder scoped to this one dropdown
                    // slot, not a full-screen section — LoadingState(lines: 1)
                    // matches the compact home-practice-card precedent.
                    loading: () => const LoadingState(lines: 1),
                    // Inline, compact error text tied to this one form field
                    // — the shared ErrorState's icon+retry chrome is built for
                    // full-section failures and would not fit naturally here.
                    error: (e, _) => Text(
                      'تعذر تحميل المعاهد: $e',
                      style: TextStyle(color: tokens.maroon),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // No manuscript token for the old "info" blue. This is a
                  // neutral instructional notice (share the credentials),
                  // not a success/error/warning — gold follows the same
                  // neutral-notice precedent as the exam card on the
                  // student dashboard (student_dashboard_screen.dart).
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
                        'شارك اسم المستخدم وكلمة المرور مع المشرف. يمكنه تسجيل الدخول مباشرة بهما ضمن المعهد المحدد.',
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
                text: 'إضافة المشرف',
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
