import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/grade_display.dart';
import '../providers/supervisor_provider.dart';

class ExamResultScreen extends ConsumerStatefulWidget {
  final String studentId;
  final int errorCount;
  final DateTime? startedAt;

  const ExamResultScreen({
    super.key,
    required this.studentId,
    required this.errorCount,
    this.startedAt,
  });

  @override
  ConsumerState<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends ConsumerState<ExamResultScreen> {
  bool _isSaving = false;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExam() async {
    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception('User not authenticated');

      final studentAsync = await ref.read(
        examStudentProvider(widget.studentId).future,
      );
      if (studentAsync == null) throw Exception('Student not found');

      final student = studentAsync.student;
      final sessionRepo = ref.read(sessionRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);

      // The اختبار is recorded with the SCOPE the curriculum gives it: its
      // tier, the juz it covers, the hizb LABEL if it has one, and the source's
      // own Arabic wording. A record keyed on a hizb cannot represent a juz- or
      // level-tier اختبار at all.
      final session = await ref
          .read(curriculumRepositoryProvider)
          .getSessionById(student.currentSessionId);
      final scope = session?.scope;
      if (session == null || !session.isExam || scope == null) {
        throw Exception('الحلقة الحالية للطالب ليست اختبارًا في المنهج');
      }

      // Attempts are counted per curriculum session — and never capped: an
      // assessment may be retried without limit.
      final attemptCount = await sessionRepo.getExamAttemptCount(
        studentId: student.id,
        curriculumSessionId: session.id,
      );

      final record = await sessionRepo.createExamRecord(
        studentId: student.id,
        supervisorId: currentUser.id,
        curriculumSessionId: session.id,
        tier: scope.tier,
        juzNumbers: scope.juzNumbers,
        hizbNumber: scope.hizbNumber,
        scopeLabelAr: scope.labelAr,
        levelId: student.currentLevel,
        attemptNumber: attemptCount + 1,
        errorCount: widget.errorCount,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        startedAt: widget.startedAt,
      );

      // Update student progress
      StudentAdvanceOutcome? advanceOutcome;
      if (record.passed) {
        advanceOutcome = await studentRepo.advanceStudentSession(student.id);
      } else {
        await studentRepo.incrementStudentAttempt(student.id);
      }

      // The four outcomes are four different things, and the supervisor is told
      // which: a pass that MOVED the student, a pass that FINISHED the
      // curriculum, and a pass that could not move them at all (a hole in the
      // seeded data, or a student that vanished) — the last of which must never
      // be reported as an unqualified success.
      final progressNotAdvanced =
          record.passed &&
          (advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
              advanceOutcome == StudentAdvanceOutcome.studentNotFound);
      final curriculumCompleted =
          advanceOutcome == StudentAdvanceOutcome.curriculumCompleted;

      // Invalidate providers
      ref.invalidate(examQueueProvider);
      ref.invalidate(supervisorStatsProvider);

      if (mounted) {
        final String message;
        final Color background;
        if (progressNotAdvanced) {
          message =
              'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
              'تالية في المنهج.';
          background = AppColors.error;
        } else if (curriculumCompleted) {
          message = 'تم حفظ الاختبار - ناجح. أتم الطالب المنهج كاملًا.';
          background = AppColors.success;
        } else if (record.passed) {
          message = 'تم حفظ الاختبار - ناجح';
          background = AppColors.success;
        } else {
          message = 'تم حفظ الاختبار - راسب';
          background = AppColors.warning;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: background),
        );

        // Navigate back to exam queue
        context.go(AppRoutes.examQueue);
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
    final studentAsync = ref.watch(examStudentProvider(widget.studentId));
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
        title: const Text('نتيجة الاختبار'),
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
                    // What was examined: the curriculum's own label for this
                    // اختبار — the same wording the record will carry.
                    child: Text(
                      '${studentWithUser.student.currentSessionLabelAr ?? 'الاختبار'} - ${studentWithUser.user.name}',
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
                onPressed: _saveExam,
                isLoading: _isSaving,
                isFullWidth: true,
                size: AppButtonSize.large,
                backgroundColor: AppColors.secondary,
              ),
              const SizedBox(height: 12),
              if (gradeInfo != null && !gradeInfo.passed)
                AppButton(
                  text: 'إعادة الاختبار',
                  onPressed: () {
                    context.pushReplacement(
                      AppRoutes.examSession.replaceFirst(
                        ':studentId',
                        widget.studentId,
                      ),
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
