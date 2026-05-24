import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/grade_display.dart';
import '../providers/supervisor_provider.dart';

class SardResultScreen extends ConsumerStatefulWidget {
  final String studentId;
  final int errorCount;

  const SardResultScreen({
    super.key,
    required this.studentId,
    required this.errorCount,
  });

  @override
  ConsumerState<SardResultScreen> createState() => _SardResultScreenState();
}

class _SardResultScreenState extends ConsumerState<SardResultScreen> {
  bool _isSaving = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveSard() async {
    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception('User not authenticated');

      // Resolve through the supervisor's institute scope (AgDR-0003) — Sard is
      // supervisor-only (#29), and supervisor-created students have
      // teacher_id: null, so the teacher-scoped lookup would fail (#45).
      final studentAsync =
          await ref.read(supervisorStudentProvider(widget.studentId).future);
      if (studentAsync == null) throw Exception('Student not found');

      final student = studentAsync.student;
      final sessionRepo = ref.read(sessionRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);

      // Get attempt count
      final attemptCount = await sessionRepo.getSardAttemptCount(
        studentId: student.id,
        hizbNumber: student.currentHizb,
      );

      // Create sard record
      final record = await sessionRepo.createSardRecord(
        studentId: student.id,
        teacherId: currentUser.id,
        hizbNumber: student.currentHizb,
        juzNumber: student.currentJuz,
        levelId: student.currentLevel,
        attemptNumber: attemptCount + 1,
        errorCount: widget.errorCount,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Update student progress
      if (record.passed) {
        await studentRepo.advanceStudentSession(student.id);
      } else {
        await studentRepo.incrementStudentAttempt(student.id);
      }

      // Invalidate the supervisor's institute-scoped providers so the students
      // list and the resolved student reflect the advanced/incremented state.
      ref.invalidate(supervisorStudentsProvider);
      ref.invalidate(supervisorStudentProvider(widget.studentId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.passed ? 'تم حفظ السرد - ناجح' : 'تم حفظ السرد - راسب',
            ),
            backgroundColor:
                record.passed ? AppColors.success : AppColors.warning,
          ),
        );

        // Navigate back to the supervisor's students list. Sard is a
        // supervisor-only activity (#29), so we always return to the supervisor
        // surface, never the teacher students route.
        context.go(AppRoutes.supervisorStudents);
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync =
        ref.watch(supervisorStudentProvider(widget.studentId));
    // Grade is level-based (hibrahem/AlRasikhoon#22). The level-based grade is
    // only computed once the student value resolves — never from a default
    // level=1 while loading, which would flash a harsher grade (#36).
    final gradeInfo = studentAsync.value != null
        ? GradeCalculator.calculateForLevel(
            studentAsync.value!.student.currentLevel,
            widget.errorCount,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة السرد'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Student info
              studentAsync.when(
                data: (studentWithUser) {
                  if (studentWithUser == null) return const SizedBox();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'سرد الحزب ${studentWithUser.student.currentHizb}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
              ),
              const SizedBox(height: 32),

              // Grade display — withhold until the real level resolves (#36).
              studentAsync.when(
                data: (_) => GradeDisplay(
                  errorCount: widget.errorCount,
                  gradeInfo: gradeInfo,
                  showStars: true,
                  showPassStatus: true,
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('تعذّر تحميل النتيجة'),
                ),
              ),

              const SizedBox(height: 32),

              // Notes
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ملاحظات (اختياري)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'أضف ملاحظات عن أداء الطالب...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              AppButton(
                text: 'حفظ النتيجة',
                onPressed: _saveSard,
                isLoading: _isSaving,
                isFullWidth: true,
                size: AppButtonSize.large,
              ),
              const SizedBox(height: 12),
              if (gradeInfo != null && !gradeInfo.passed)
                AppButton(
                  text: 'إعادة السرد',
                  onPressed: () {
                    context.pushReplacement(
                      AppRoutes.sardSession
                          .replaceFirst(':studentId', widget.studentId),
                    );
                  },
                  type: AppButtonType.outline,
                  isFullWidth: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
