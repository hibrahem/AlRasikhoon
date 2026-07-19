import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../domain/assessment/assessment_evaluation.dart';
import '../../../routing/app_router.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/assessment_outcome_display.dart';
import '../providers/supervisor_provider.dart';

/// The sheet's own ordinals for the five questions.
const _questionNamesAr = [
  'السؤال الأول',
  'السؤال الثاني',
  'السؤال الثالث',
  'السؤال الرابع',
  'السؤال الخامس',
];

class ExamResultScreen extends ConsumerStatefulWidget {
  final String studentId;

  /// The per-question error tallies the supervisor recorded, in sheet order
  /// (السؤال الأول..الخامس).
  final List<RecitationErrorTally> questions;

  final DateTime? startedAt;

  const ExamResultScreen({
    super.key,
    required this.studentId,
    required this.questions,
    this.startedAt,
  });

  @override
  ConsumerState<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends ConsumerState<ExamResultScreen> {
  bool _isSaving = false;
  final _notesController = TextEditingController();

  /// The curriculum's verdict: موفق only if every question stayed within the
  /// per-question allowance (3/2/1/5). Level plays no part — the allowance is
  /// the same across all ten levels.
  late final ExamEvaluation _evaluation = ExamEvaluation(widget.questions);

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

      // Record and student progress are STAGED into one WriteBatch and
      // committed without awaiting server ack: offline, the save must return
      // instantly (the commit Future only completes on server ack) and the
      // pair must sync atomically.
      final batch = sessionRepo.newWriteBatch();
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
        evaluation: _evaluation,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        startedAt: widget.startedAt,
        batch: batch,
      );

      // Update student progress
      StudentAdvanceOutcome? advanceOutcome;
      if (record.passed) {
        advanceOutcome = await studentRepo.advanceStudentSession(
          student.id,
          batch: batch,
        );
      } else {
        await studentRepo.incrementStudentAttempt(student.id, batch: batch);
      }

      unawaited(
        batch.commit().catchError((Object e, StackTrace s) {
          debugPrint('exam save sync failed: $e');
        }),
      );

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

      // Invalidate providers — including the supervisor's cached view of this
      // student's سجل الحلقات, which would otherwise keep showing the
      // pre-save history without this اختبار (al_rasikhoon-5ri).
      ref.invalidate(examQueueProvider);
      ref.invalidate(supervisorStatsProvider);
      ref.invalidate(supervisorStudentSessionHistoryProvider(widget.studentId));

      if (mounted) {
        final tokens = context.tokens;
        String message;
        final Color background;
        if (progressNotAdvanced) {
          message =
              'تم حفظ النتيجة، لكن تعذر تحديث تقدم الطالب: لا توجد حلقات '
              'تالية في المنهج.';
          // A genuine system anomaly (curriculum data gap) -> tokens.maroon
          // per the table's AppColors.error mapping.
          background = tokens.maroon;
        } else if (curriculumCompleted) {
          message = 'تم حفظ الاختبار - موفق. أتم الطالب المنهج كاملًا.';
          // No manuscript token for a distinct "success" hue — the primary
          // green already carries the positive/affirmative role, so it is
          // reused here.
          background = tokens.green;
        } else if (record.passed) {
          message = 'تم حفظ الاختبار - موفق';
          background = tokens.green;
        } else {
          message = 'تم حفظ الاختبار - غير موفق';
          // AppColors.warning has no direct AppTokens equivalent. A failed
          // اختبار is an expected, non-alarming outcome — distinct from the
          // genuine data anomaly above, which already uses tokens.maroon —
          // so it gets tokens.gold instead of reusing maroon for a second,
          // unrelated meaning in this same method.
          background = tokens.gold;
        }

        // Saved locally either way — but the supervisor must not read an
        // unqualified "saved" as "reached the server" while offline.
        if (!ref.read(isConnectedProvider)) {
          message = '$message — ستتم المزامنة عند عودة الاتصال';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: background),
        );

        // Navigate back to exam queue
        context.go(AppRoutes.examQueue);
      }
    } catch (e) {
      debugPrint('saving exam result failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تعذر حفظ النتيجة، حاول مرة أخرى'),
            backgroundColor: context.tokens.maroon,
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
    final studentAsync = ref.watch(examStudentProvider(widget.studentId));

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
                      color: tokens.surfaceVariant,
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

              // The verdict. Unlike a lesson's grade it does NOT wait for the
              // student's level to resolve: the اختبار allowance is the same
              // for every level, so the outcome is already final (contrast
              // #36, which only applies to level-based grades).
              AssessmentOutcomeDisplay(
                outcome: _evaluation.outcome,
                // The اختبار sheet's own consequence: موفق ويستكمل حفظه.
                passedDetailAr: 'ويستكمل حفظه',
              ),

              const SizedBox(height: 16),

              // The sheet's error table — question by question, the failing
              // questions marked.
              AssessmentBreakdownTable(
                units: widget.questions,
                limits: ExamEvaluation.limits,
                unitLabelAr: (i) => _questionNamesAr[i],
              ),

              const SizedBox(height: 32),

              // Notes
              Align(
                // Directional: centerStart is the reading-start edge in RTL.
                alignment: AlignmentDirectional.centerStart,
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
                backgroundColor: tokens.gold,
              ),
              const SizedBox(height: 12),
              if (!_evaluation.passed)
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
