import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/admin_provider.dart';

class CreateInstituteScreen extends ConsumerStatefulWidget {
  const CreateInstituteScreen({super.key});

  @override
  ConsumerState<CreateInstituteScreen> createState() =>
      _CreateInstituteScreenState();
}

class _CreateInstituteScreenState extends ConsumerState<CreateInstituteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      final repo = ref.read(instituteRepositoryProvider);

      await repo.createInstitute(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        createdBy: currentUser?.id ?? '',
      );

      // Refresh institutes list
      ref.invalidate(institutesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنشاء المعهد بنجاح'),
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
        title: const Text('إضافة معهد'),
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
                  Icons.account_balance,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),

              // Name field
              AppTextField(
                label: 'اسم المعهد',
                hint: 'مثال: معهد النور لتحفيظ القرآن',
                controller: _nameController,
                validator: Validators.validateInstituteName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Location field
              AppTextField(
                label: 'الموقع',
                hint: 'مثال: الرياض - حي النزهة',
                controller: _locationController,
                validator: Validators.validateLocation,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleCreate(),
              ),
              const SizedBox(height: 32),

              // Create button
              AppButton(
                text: 'إنشاء المعهد',
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
