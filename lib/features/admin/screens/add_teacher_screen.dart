import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/countries.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/admin_provider.dart';

class AddTeacherScreen extends ConsumerStatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  ConsumerState<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends ConsumerState<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  Country _selectedCountry = Countries.defaultCountry;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(userRepositoryProvider);
      final phone = Validators.formatPhoneWithCountryCode(
        _phoneController.text,
        country: _selectedCountry,
      );

      // Check if user with this phone already exists
      final existingUser = await repo.getUserByPhone(phone);
      if (existingUser != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('رقم الجوال مسجل مسبقاً'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Generate a unique ID for the teacher
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await repo.createUser(
        id: id,
        phone: phone,
        name: _nameController.text.trim(),
        role: UserRole.teacher,
      );

      // Refresh teachers list
      ref.invalidate(allTeachersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة المعلم بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppColors.error,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة معلم'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),

              // Name field
              AppTextField(
                label: 'اسم المعلم',
                hint: 'الاسم الكامل',
                controller: _nameController,
                validator: Validators.validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Phone field
              AppPhoneField(
                controller: _phoneController,
                initialCountry: _selectedCountry,
                onCountryChanged: (country) {
                  setState(() => _selectedCountry = country);
                },
              ),
              const SizedBox(height: 32),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سيتمكن المعلم من تسجيل الدخول برقم الجوال',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Create button
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
