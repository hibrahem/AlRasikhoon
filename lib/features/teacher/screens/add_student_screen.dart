import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/countries.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/institute_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/models/institute_model.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/curriculum/curriculum_position.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/icon_medallion.dart';
import '../providers/teacher_provider.dart';
import '../widgets/starting_point_picker.dart';
import '../../supervisor/providers/supervisor_provider.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  /// When true, the screen runs in supervisor mode: the institute list is the
  /// supervisor's single bound institute (read off users/{uid}.institute_id,
  /// AgDR-0003), and the supervisor must pick a teacher from that institute
  /// before the form can be submitted (al_rasikhoon-6bw) — a teacher-less
  /// student sits in no teacher's list, so nobody could ever conduct their
  /// حلقة or their سرد. When false (default) it is the teacher flow, and the
  /// created student is assigned to the creating teacher.
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
  UserModel? _selectedTeacher;
  CurriculumPosition? _startingPosition = CurriculumPosition.start;
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
      // Supervisor mode: ALL institutes the supervisor is assigned to, resolved
      // from the supervisor_institutes membership (al_rasikhoon-3n6). A
      // supervisor may supervise several institutes, and picks which one the new
      // student is created in from this list.
      institutes = await repo.getInstitutesForSupervisor(currentUser.id);
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

    final tokens = context.tokens;

    if (_selectedInstitute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار المعهد'),
          backgroundColor: tokens.maroon,
        ),
      );
      return;
    }

    // A supervisor MUST pick a teacher from their institute (al_rasikhoon-6bw):
    // a teacher-less student is invisible to every teacher's
    // getStudentsForTeacher query, so nobody could ever conduct their حلقة or
    // their سرد. The teacher-flow path never hits this — it always assigns
    // the creating teacher below.
    if (widget.asSupervisor && _selectedTeacher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار المعلم'),
          backgroundColor: tokens.maroon,
        ),
      );
      return;
    }

    final startingPosition = _startingPosition;
    if (startingPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار نقطة بداية صالحة في المنهج'),
          backgroundColor: tokens.maroon,
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
            SnackBar(
              content: const Text('اسم المستخدم مسجل مسبقاً'),
              backgroundColor: tokens.maroon,
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
        // A supervisor-created student is assigned the teacher chosen above
        // (al_rasikhoon-6bw, guarded non-null by the check above). A
        // teacher-created student is assigned to the creating teacher.
        teacherId: widget.asSupervisor ? _selectedTeacher!.id : currentUser.id,
        guardianUsername: guardianUsername,
        guardianPassword: guardianPassword,
        guardianPhone: guardianPhone,
        startingPosition: startingPosition,
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
            // No manuscript token for a distinct "success" hue — the
            // primary green already carries the positive/affirmative role
            // elsewhere on this screen, so it is reused here too.
            backgroundColor: tokens.green,
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
          SnackBar(content: Text(msg), backgroundColor: tokens.maroon),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: tokens.maroon,
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
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة طالب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Centered so the stretched form column can't distort the
              // medallion's circle.
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
                      border: Border.all(color: tokens.hairline),
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
                          setState(() {
                            _selectedInstitute = value;
                            // The teacher pool is scoped to the chosen institute
                            // (al_rasikhoon-3n6); a teacher from the previously
                            // selected institute must not carry over.
                            _selectedTeacher = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.asSupervisor && _selectedInstitute != null) ...[
                const SizedBox(height: 24),
                _TeacherPicker(
                  instituteId: _selectedInstitute!.id,
                  selectedTeacher: _selectedTeacher,
                  onChanged: (teacher) {
                    setState(() => _selectedTeacher = teacher);
                  },
                ),
              ],
              const SizedBox(height: 24),
              StartingPointPicker(
                // Only seeds the picker's initial selection — the picker
                // manages its own level/hizb/session state after that and
                // reports every change through onChanged (including `null`
                // while no valid session is selected).
                initialValue: CurriculumPosition.start,
                onChanged: (position) {
                  setState(() => _startingPosition = position);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // No manuscript token for the old "info" blue. This banner
                  // stands alone (no sibling accent card on this screen
                  // competes for a hue), so it gets tokens.gold — the
                  // palette's illumination/note hue — distinct from the
                  // green already used for the avatar icon above.
                  color: tokens.gold.withValues(alpha: 0.1),
                  // Card-level surface sitting directly on the page, so it
                  // carries the card radius rather than the inset 12.
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  border: Border.all(color: tokens.gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: tokens.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'شارك اسم المستخدم وكلمة المرور مع الطالب.',
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

/// The required teacher picker shown only in supervisor mode
/// (al_rasikhoon-6bw). Lists the teachers of the SELECTED institute via
/// [supervisorInstituteTeachersProvider] — scoped to the one institute the
/// student is being created in (al_rasikhoon-3n6), which must be one of the
/// supervisor's institutes. This is the pool a teacher-less student can be
/// rescued into, and the ONLY teachers a supervisor is scoped to assign.
class _TeacherPicker extends ConsumerWidget {
  final String instituteId;
  final UserModel? selectedTeacher;
  final ValueChanged<UserModel?> onChanged;

  const _TeacherPicker({
    required this.instituteId,
    required this.selectedTeacher,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final teachersAsync = ref.watch(
      supervisorInstituteTeachersProvider(instituteId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المعلم', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.hairline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<UserModel>(
              isExpanded: true,
              value: selectedTeacher,
              hint: Text(
                teachersAsync.isLoading ? 'جارٍ التحميل...' : 'اختر المعلم',
              ),
              items: (teachersAsync.value ?? const <UserModel>[]).map((
                teacher,
              ) {
                return DropdownMenuItem(
                  value: teacher,
                  child: Text(teacher.name),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
