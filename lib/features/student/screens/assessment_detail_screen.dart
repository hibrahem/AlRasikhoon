import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../domain/assessment/assessment_evaluation.dart';
import '../../../domain/session/student_history_entry.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_large_top_bar.dart';
import '../../../shared/widgets/assessment_outcome_display.dart';
import '../../../shared/widgets/states/error_state.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';

/// Parses the `:kind` path segment of an assessment-detail route.
///
/// Only `sard` and `exam` name assessment collections; anything else is a
/// hand-crafted URL and MUST surface, not silently open the wrong record type.
StudentHistoryKind assessmentKindFromPath(String kind) {
  switch (kind) {
    case 'sard':
      return StudentHistoryKind.sard;
    case 'exam':
      return StudentHistoryKind.exam;
    default:
      throw ArgumentError.value(kind, 'kind', 'Unknown assessment kind');
  }
}

/// The sheet's own ordinals for the five اختبار questions.
const _questionNamesAr = [
  'السؤال الأول',
  'السؤال الثاني',
  'السؤال الثالث',
  'السؤال الرابع',
  'السؤال الخامس',
];

/// A past سرد or اختبار record, opened from a student's history
/// (al_rasikhoon-nyp). Read-only: the verdict, the sheet's per-face /
/// per-question error table, and the record's facts.
///
/// Role-agnostic like [SessionDetailScreen]: every shell registers its own
/// route to it, so opening a record never crosses shells (al_rasikhoon-3hn).
class AssessmentDetailScreen extends ConsumerWidget {
  /// Which collection the record lives in — [StudentHistoryKind.sard] or
  /// [StudentHistoryKind.exam]. A lesson/تلقين record belongs to
  /// SessionDetailScreen instead.
  final StudentHistoryKind kind;

  final String recordId;

  const AssessmentDetailScreen({
    super.key,
    required this.kind,
    required this.recordId,
  }) : assert(
         kind == StudentHistoryKind.sard || kind == StudentHistoryKind.exam,
         'AssessmentDetailScreen shows a سرد or an اختبار, not a lesson',
       );

  bool get _isSard => kind == StudentHistoryKind.sard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The two record models don't share a base type, so the screen resolves
    // its own view-facts from whichever collection [kind] names.
    final viewAsync = _isSard
        ? ref
              .watch(sardRecordByIdProvider(recordId))
              .whenData(
                (r) => r == null
                    ? null
                    : _AssessmentViewFacts(
                        scopeLabelAr: r.scopeLabelAr,
                        levelId: r.levelId,
                        date: r.date,
                        attemptNumber: r.attemptNumber,
                        duration: r.duration,
                        grade: r.grade,
                        passed: r.passed,
                        errorCount: r.errorCount,
                        tallies: r.faceErrors,
                        notes: r.notes,
                      ),
              )
        : ref
              .watch(examRecordByIdProvider(recordId))
              .whenData(
                (r) => r == null
                    ? null
                    : _AssessmentViewFacts(
                        scopeLabelAr: r.scopeLabelAr,
                        levelId: r.levelId,
                        date: r.date,
                        attemptNumber: r.attemptNumber,
                        duration: r.duration,
                        grade: r.grade,
                        passed: r.passed,
                        errorCount: r.errorCount,
                        tallies: r.questionErrors,
                        notes: r.notes,
                      ),
              );

    return Scaffold(
      // Large-title sliver bar for this read-only detail view.
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          AppLargeTopBar(title: _isSard ? 'تفاصيل السرد' : 'تفاصيل الاختبار'),
          viewAsync.when(
            data: (facts) {
              if (facts == null) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('السجل غير موجود')),
                );
              }
              return _AssessmentDetailBody(isSard: _isSard, facts: facts);
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingState(),
            ),
            error: (e, _) {
              // The raw exception goes to the log, never onto the screen.
              debugPrint('assessment record $recordId failed to load: $e');
              return SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: _isSard
                      ? 'تعذر تحميل تفاصيل السرد'
                      : 'تعذر تحميل تفاصيل الاختبار',
                  onRetry: () => ref.invalidate(
                    _isSard
                        ? sardRecordByIdProvider(recordId)
                        : examRecordByIdProvider(recordId),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The record facts the detail view renders, shaped identically for both
/// collections.
class _AssessmentViewFacts {
  final String scopeLabelAr;
  final int levelId;
  final DateTime date;
  final int attemptNumber;
  final Duration? duration;
  final String grade;
  final bool passed;
  final int errorCount;
  final List<RecitationErrorTally> tallies;
  final String? notes;

  const _AssessmentViewFacts({
    required this.scopeLabelAr,
    required this.levelId,
    required this.date,
    required this.attemptNumber,
    required this.duration,
    required this.grade,
    required this.passed,
    required this.errorCount,
    required this.tallies,
    required this.notes,
  });
}

class _AssessmentDetailBody extends StatelessWidget {
  final bool isSard;
  final _AssessmentViewFacts facts;

  const _AssessmentDetailBody({required this.isSard, required this.facts});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // What was assessed: the curriculum's own wording, exactly as the
            // record carries it.
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  facts.scopeLabelAr.isNotEmpty
                      ? facts.scopeLabelAr
                      : (isSard ? 'سرد' : 'اختبار'),
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // The verdict, exactly as the result screen showed it when the
            // assessment was conducted.
            AssessmentOutcomeDisplay(
              outcome: facts.passed
                  ? AssessmentOutcome.muwaffaq
                  : AssessmentOutcome.ghayrMuwaffaq,
              passedDetailAr: isSard ? 'وينقل للاختبار' : 'ويستكمل حفظه',
            ),
            const SizedBox(height: 16),

            // The sheet's error table — or, for a record written before
            // assessments tracked per-unit error types, the total it stored.
            if (facts.tallies.isNotEmpty)
              AssessmentBreakdownTable(
                units: facts.tallies,
                limits: isSard ? SardEvaluation.limits : ExamEvaluation.limits,
                unitLabelAr: (i) =>
                    isSard ? 'الوجه ${i + 1}' : _questionNamesAr[i],
              )
            else
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: tokens.sepia),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سُجّل هذا التقييم قبل تتبع تفاصيل الأخطاء — '
                        'إجمالي الأخطاء: ${facts.errorCount}'
                        '${facts.grade.isNotEmpty ? '، التقدير: ${facts.grade}' : ''}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // The record's facts.
            AppCard(
              child: Column(
                children: [
                  _FactRow(
                    label: 'التاريخ',
                    value: DateFormat('yyyy/MM/dd', 'ar').format(facts.date),
                  ),
                  _FactRow(label: 'المستوى', value: '${facts.levelId}'),
                  _FactRow(label: 'المحاولة', value: '${facts.attemptNumber}'),
                  if (facts.duration != null)
                    _FactRow(
                      label: 'المدة',
                      value: _formatDuration(facts.duration!),
                    ),
                ],
              ),
            ),

            if (facts.notes != null && facts.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملاحظات',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(facts.notes!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes == 0) return '$seconds ثانية';
    return '$minutes دقيقة $seconds ثانية';
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.sepia),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
