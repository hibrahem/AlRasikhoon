import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/icon_medallion.dart';
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
          SnackBar(
            content: const Text('تم إنشاء المعهد بنجاح'),
            backgroundColor: context.tokens.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('createInstitute failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر إنشاء المعهد، حاول مرة أخرى'),
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
      appBar: AppBar(title: const Text('إضافة معهد')),
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
                    icon: Icons.account_balance,
                    accent: tokens.green,
                    size: 80,
                    iconSize: 40,
                  ),
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
