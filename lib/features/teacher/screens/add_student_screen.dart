import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/countries.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/user_repository.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianEmailController = TextEditingController();
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
    _emailController.dispose();
    _phoneController.dispose();
    _guardianEmailController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required email
    final emailError = Validators.validateEmail(_emailController.text);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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

      final userRepo = ref.read(userRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);
      final email = _emailController.text.trim().toLowerCase();

      // Check if user with this email already exists
      final existingUser = await userRepo.getUserByEmail(email);
      if (existingUser != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('البريد الإلكتروني مسجل مسبقاً'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Format optional phone numbers
      String? phone;
      if (_phoneController.text.isNotEmpty) {
        phone = Validators.formatPhoneWithCountryCode(
          _phoneController.text,
          country: _studentCountry,
        );
      }

      String? guardianEmail;
      if (_guardianEmailController.text.isNotEmpty) {
        guardianEmail = _guardianEmailController.text.trim().toLowerCase();
      }

      String? guardianPhone;
      if (_guardianPhoneController.text.isNotEmpty) {
        guardianPhone = Validators.formatPhoneWithCountryCode(
          _guardianPhoneController.text,
          country: _guardianCountry,
        );
      }

      // Create student with auto-generated user document (no Firebase Auth)
      // Firebase Auth account will be created on first login attempt
      await studentRepo.createStudent(
        name: _nameController.text.trim(),
        email: email,
        phone: phone,
        instituteId: _selectedInstitute!.id,
        teacherId: currentUser.id,
        guardianEmail: guardianEmail,
        guardianPhone: guardianPhone,
      );

      // Refresh students list
      ref.invalidate(teacherStudentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة الطالب: ${_nameController.text.trim()}'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'حدث خطأ: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

              // Student name field
              AppTextField(
                label: 'اسم الطالب',
                hint: 'الاسم الكامل',
                controller: _nameController,
                validator: Validators.validateName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Student email field (required)
              AppEmailField(
                controller: _emailController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),

              // Student phone field (optional)
              AppPhoneField(
                controller: _phoneController,
                initialCountry: _studentCountry,
                isOptional: true,
                onCountryChanged: (country) {
                  setState(() => _studentCountry = country);
                },
              ),
              const SizedBox(height: 24),

              // Guardian section header
              Text(
                'بيانات ولي الأمر (اختياري)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Guardian email field (optional)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'البريد الإلكتروني لولي الأمر (اختياري)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _guardianEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'example@email.com',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Guardian phone field (optional)
              AppPhoneField(
                label: 'رقم ولي الأمر',
                controller: _guardianPhoneController,
                initialCountry: _guardianCountry,
                isOptional: true,
                onCountryChanged: (country) {
                  setState(() => _guardianCountry = country);
                },
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.login,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'يمكن للطالب تسجيل الدخول بـ Google أو بالبريد الإلكتروني',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.info,
                                ),
                          ),
                        ),
                      ],
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
