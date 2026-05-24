import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/admin_provider.dart';

class EditInstituteScreen extends ConsumerStatefulWidget {
  final String instituteId;

  const EditInstituteScreen({
    super.key,
    required this.instituteId,
  });

  @override
  ConsumerState<EditInstituteScreen> createState() =>
      _EditInstituteScreenState();
}

class _EditInstituteScreenState extends ConsumerState<EditInstituteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _initializeFields(String name, String location) {
    if (!_isInitialized) {
      _nameController.text = name;
      _locationController.text = location;
      _isInitialized = true;
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(instituteRepositoryProvider);
      final currentInstitute = ref.read(instituteProvider(widget.instituteId)).value;

      if (currentInstitute == null) {
        throw Exception('المعهد غير موجود');
      }

      final updatedInstitute = currentInstitute.copyWith(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
      );

      await repo.updateInstitute(updatedInstitute);

      // Refresh providers
      ref.invalidate(institutesProvider);
      ref.invalidate(instituteProvider(widget.instituteId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المعهد بنجاح'),
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
    final instituteAsync = ref.watch(instituteProvider(widget.instituteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المعهد'),
      ),
      body: instituteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (institute) {
          if (institute == null) {
            return const Center(child: Text('المعهد غير موجود'));
          }

          _initializeFields(institute.name, institute.location);

          return SingleChildScrollView(
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                    onSubmitted: (_) => _handleUpdate(),
                  ),
                  const SizedBox(height: 32),

                  // Update button
                  AppButton(
                    text: 'حفظ التغييرات',
                    onPressed: _handleUpdate,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
