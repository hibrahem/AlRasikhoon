import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/countries.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/models/institute_model.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../providers/teacher_provider.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  InstituteModel? _selectedInstitute;
  bool _isLoading = false;
  List<InstituteModel> _institutes = [];
  Country _studentCountry = Countries.defaultCountry;
  Country _guardianCountry = Countries.defaultCountry;

  @override
  void initState() {
    super.initState();
    _loadInstitutes();
  }

  Future<void> _loadInstitutes() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final repo = ref.read(instituteRepositoryProvider);
    final institutes = await repo.getInstitutesForTeacher(currentUser.id);

    setState(() {
      _institutes = institutes;
      if (institutes.isNotEmpty) {
        _selectedInstitute = institutes.first;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInstitute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المعهد'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception('User not authenticated');

      final repo = ref.read(studentRepositoryProvider);
      final phone = Validators.formatPhoneWithCountryCode(
        _phoneController.text,
        country: _studentCountry,
      );
      final guardianPhone = _guardianPhoneController.text.isNotEmpty
          ? Validators.formatPhoneWithCountryCode(
              _guardianPhoneController.text,
              country: _guardianCountry,
            )
          : null;

      await repo.createStudent(
        name: _nameController.text.trim(),
        phone: phone,
        instituteId: _selectedInstitute!.id,
        teacherId: currentUser.id,
        guardianPhone: guardianPhone,
      );

      // Refresh students list
      ref.invalidate(teacherStudentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إضافة الطالب بنجاح'),
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
        title: const Text('إضافة طالب'),
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
                label: 'اسم الطالب',
                hint: 'الاسم الكامل',
                controller: _nameController,
                validator: Validators.validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Phone field
              AppPhoneField(
                controller: _phoneController,
                initialCountry: _studentCountry,
                onCountryChanged: (country) {
                  setState(() => _studentCountry = country);
                },
              ),
              const SizedBox(height: 20),

              // Guardian phone field (optional)
              AppPhoneField(
                controller: _guardianPhoneController,
                initialCountry: _guardianCountry,
                onCountryChanged: (country) {
                  setState(() => _guardianCountry = country);
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  'رقم ولي الأمر (اختياري)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              const SizedBox(height: 20),

              // Institute dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المعهد',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<InstituteModel>(
                        isExpanded: true,
                        value: _selectedInstitute,
                        hint: const Text('اختر المعهد'),
                        items: _institutes.map((institute) {
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
                  ),
                ],
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
                        'سيبدأ الطالب من المستوى الأول - الحلقة الأولى',
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
                text: 'إضافة الطالب',
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
