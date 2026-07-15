import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/grade_display.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/teacher_provider.dart';

class SardResultScreen extends ConsumerStatefulWidget {
  final String studentId;
  final int errorCount;
  final DateTime? startedAt;

  const SardResultScreen({
    super.key,
    required this.studentId,
    required this.errorCount,
    this.startedAt,
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
    final tokens = context.tokens;

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception('User not authenticated');

      // سرد is conducted by the TEACHER (al_rasikhoon-801) — resolve the
      // student through the teacher-scoped lookup, like every other teacher
      // session flow.
      final studentAsync = await ref.read(
        studentProvider(widget.studentId).future,
      );
      if (studentAsync == null) throw Exception('Student not found');

      final student = studentAsync.student;
      final sessionRepo = ref.read(sessionRepositoryProvider);
      final studentRepo = ref.read(studentRepositoryProvider);

      // The سرد is recorded with the SCOPE the curriculum gives it: its tier,
      // the juz it covers, the hizb LABEL if it has one, and the source's own
      // Arabic wording. A record keyed on a hizb cannot represent a juz- or
      // level-tier سرد at all.
      final session = await ref
          .read(curriculumRepositoryProvider)
          .getSessionById(student.currentSessionId);
      final scope = session?.scope;
      if (session == null || !session.isSard || scope == null) {
        throw Exception('الحلقة الحالية للطالب ليست سردًا في المنهج');
      }

      // Attempts are counted per curriculum session — and never capped: an
      // assessment may be retried without limit.
      final attemptCount = await sessionRepo.getSardAttemptCount(
        studentId: student.id,
        curriculumSessionId: session.id,
      );

      final record = await sessionRepo.createSardRecord(
        studentId: student.id,
        teacherId: currentUser.id,
        curriculumSessionId: session.id,
        tier: scope.tier,
        juzNumbers: scope.juzNumbers,
        hizbNumber: scope.hizbNumber,
        scopeLabelAr: scope.labelAr,
        levelId: student.currentLevel,
        attemptNumber: attemptCount + 1,
        errorCount: widget.errorCount,
        startedAt: widget.startedAt,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Update student progress
      StudentAdvanceOutcome? advanceOutcome;
      if (record.passed) {
        advanceOutcome = await studentRepo.advanceStudentSession(student.id);
      } else {
        await studentRepo.incrementStudentAttempt(student.id);
      }

      // The four outcomes are four different things, and the teacher is told
      // which: a pass that MOVED the student, a pass that FINISHED the
      // curriculum, and a pass that could not move them at all (a hole in the
      // seeded data, or a student that vanished) — the last of which must never
      // be reported as an unqualified success, or the student is left stuck on
      // the same session forever with nobody the wiser.
      final progressNotAdvanced =
          record.passed &&
          (advanceOutcome == StudentAdvanceOutcome.curriculumDataMissing ||
              advanceOutcome == StudentAdvanceOutcome.studentNotFound);
      final curriculumCompleted =
          advanceOutcome == StudentAdvanceOutcome.curriculumCompleted;

      // Invalidate the teacher's providers so the students list and the
      // resolved student reflect the advanced/incremented state.
      ref.invalidate(teacherStudentsProvider);
      ref.invalidate(studentProvider(widget.studentId));

      if (mounted) {
        final String message;
        final Color background;
        // No manuscript token for "success"/"warning" — the primary green
        // already carries the positive/affirmative role and maroon (the
        // palette's rubrication/emphasis hue) already carries error, so a
        // failed سرد reuses maroon too (these four branches never render
        // together).
        if (progressNotAdvanced) {
          message =
              'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
              'تالية في المنهج.';
          background = tokens.maroon;
        } else if (curriculumCompleted) {
          message = 'تم حفظ السرد - ناجح. أتم الطالب المنهج كاملًا.';
          background = tokens.green;
        } else if (record.passed) {
          message = 'تم حفظ السرد - ناجح';
          background = tokens.green;
        } else {
          message = 'تم حفظ السرد - راسب';
          background = tokens.maroon;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: background),
        );

        // Back to the teacher's students list — سرد is a teacher activity
        // (al_rasikhoon-801), so we always return to the teacher surface.
        context.go(AppRoutes.teacherStudents);
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
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final studentAsync = ref.watch(studentProvider(widget.studentId));
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
              // What was recited: the curriculum's own label for this سرد
              // (`سرد الجزء رقم 30 كاملًا…`), which is exactly what the record
              // will carry. The student's denormalized label is used, so the
              // header is right even before the session document resolves.
              studentAsync.when(
                data: (studentWithUser) {
                  if (studentWithUser == null) return const SizedBox();

                  final label =
                      studentWithUser.student.currentSessionLabelAr ?? 'السرد';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
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
                loading: () => const LoadingState(lines: 1),
                error: (_, _) =>
                    const ErrorState(message: 'تعذّر تحميل النتيجة'),
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
                      AppRoutes.sardSession.replaceFirst(
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
