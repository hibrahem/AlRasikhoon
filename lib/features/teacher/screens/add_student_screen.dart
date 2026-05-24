import 'package:cloud_functions/cloud_functions.dart';
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
import '../../supervisor/providers/supervisor_provider.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  /// When true, the screen runs in supervisor mode: the institute list is the
  /// supervisor's single bound institute (read off users/{uid}.institute_id,
  /// AgDR-0003) and the created student carries no teacher_id (institute-scoped,
  /// not teacher-owned). When false (default) it is the teacher flow.
  final bool asSupervisor;

  const AddStudentScreen({super.key, this.asSupervisor = false});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianUsernameController = TextEditingController();
  final _guardianPasswordController = TextEditingController();
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

    List<InstituteModel> institutes;
    if (widget.asSupervisor) {
      // Supervisor mode: the only institute is the supervisor's canonical
      // bound institute (users/{uid}.institute_id, AgDR-0003).
      final instituteId = currentUser.instituteId;
      if (instituteId == null || instituteId.isEmpty) {
        institutes = const [];
      } else {
        final institute = await repo.getInstituteById(instituteId);
        institutes = institute == null ? const [] : [institute];
      }
    } else {
      institutes = await repo.getInstitutesForTeacher(currentUser.id);
    }

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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _guardianUsernameController.dispose();
    _guardianPasswordController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (_isLoading) return;
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

      final userRepo = ref.read(userRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);
      final username = _usernameController.text.trim().toLowerCase();

      final existingUser = await userRepo.getUserByUsername(username);
      if (existingUser != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('اسم المستخدم مسجل مسبقاً'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      String? phone;
      if (_phoneController.text.isNotEmpty) {
        phone = Validators.formatPhoneWithCountryCode(
          _phoneController.text,
          country: _studentCountry,
        );
      }

      String? guardianUsername;
      String? guardianPassword;
      if (_guardianUsernameController.text.isNotEmpty) {
        guardianUsername = _guardianUsernameController.text
            .trim()
            .toLowerCase();
        guardianPassword = _guardianPasswordController.text;
      }

      String? guardianPhone;
      if (_guardianPhoneController.text.isNotEmpty) {
        guardianPhone = Validators.formatPhoneWithCountryCode(
          _guardianPhoneController.text,
          country: _guardianCountry,
        );
      }

      await studentRepo.createStudent(
        name: _nameController.text.trim(),
        username: username,
        password: _passwordController.text,
        phone: phone,
        instituteId: _selectedInstitute!.id,
        // Supervisor-created students are institute-scoped, not teacher-owned
        // (AgDR-0003): no teacher_id. Teacher-created students are assigned to
        // the creating teacher.
        teacherId: widget.asSupervisor ? null : currentUser.id,
        guardianUsername: guardianUsername,
        guardianPassword: guardianPassword,
        guardianPhone: guardianPhone,
      );

      if (widget.asSupervisor) {
        ref.invalidate(supervisorStudentsProvider);
      } else {
        ref.invalidate(teacherStudentsProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إضافة الطالب: ${_nameController.text.trim()}'),
            backgroundColor: AppColors.success,
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
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
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

  String? _validateGuardianPassword(String? value) {
    if (_guardianUsernameController.text.isEmpty) return null;
    return Validators.validatePassword(value);
  }

  String? _validateGuardianUsername(String? value) {
    if (value == null || value.isEmpty) return null;
    return Validators.validateUsername(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة طالب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              AppTextField(
                label: 'اسم الطالب',
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
                initialCountry: _studentCountry,
                isOptional: true,
                onCountryChanged: (country) {
                  setState(() => _studentCountry = country);
                },
              ),
              const SizedBox(height: 24),
              Text(
                'بيانات ولي الأمر (اختياري)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'اسم المستخدم لولي الأمر (اختياري)',
                hint: 'guardian_username',
                controller: _guardianUsernameController,
                validator: _validateGuardianUsername,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              const SizedBox(height: 20),
              AppPasswordField(
                label: 'كلمة المرور لولي الأمر',
                controller: _guardianPasswordController,
                validator: _validateGuardianPassword,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المعهد', style: Theme.of(context).textTheme.labelLarge),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'الطالب يبدأ من المستوى الأول. شارك اسم المستخدم وكلمة المرور معه.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
