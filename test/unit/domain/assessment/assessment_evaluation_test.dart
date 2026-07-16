import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';

void main() {
  group('RecitationErrorTally', () {
    test('starts empty and sums its four error types', () {
      const tally = RecitationErrorTally(
        tanbeehat: 2,
        talqeenat: 1,
        tashkeel: 1,
        tajweed: 3,
      );
      expect(RecitationErrorTally.empty.total, 0);
      expect(tally.total, 7);
      expect(tally.countOf(RecitationErrorType.tanbeeh), 2);
      expect(tally.countOf(RecitationErrorType.talqeen), 1);
      expect(tally.countOf(RecitationErrorType.tashkeel), 1);
      expect(tally.countOf(RecitationErrorType.tajweed), 3);
    });

    test('adding an error returns a new tally, original untouched', () {
      const tally = RecitationErrorTally.empty;
      final added = tally.adding(RecitationErrorType.tajweed);
      expect(added.countOf(RecitationErrorType.tajweed), 1);
      expect(tally.countOf(RecitationErrorType.tajweed), 0);
    });

    test('removing an error clamps at zero instead of going negative', () {
      const tally = RecitationErrorTally.empty;
      final removed = tally.removing(RecitationErrorType.tashkeel);
      expect(removed.countOf(RecitationErrorType.tashkeel), 0);

      final roundTrip = tally
          .adding(RecitationErrorType.tanbeeh)
          .removing(RecitationErrorType.tanbeeh);
      expect(roundTrip.total, 0);
    });

    test('negative counts are rejected as an invariant violation', () {
      expect(
        () => RecitationErrorTally.checked(tanbeehat: -1),
        throwsA(isA<ArgumentError>()),
      );
      expect(() => RecitationErrorTally(tanbeehat: -1), throwsAssertionError);
    });
  });

  group('AssessmentErrorLimits', () {
    test('سرد allows 5 تنبيهات / 2 تلقينات / 1 تشكيل / 8 تجويد per face', () {
      const limits = AssessmentErrorLimits.sardPerFace;
      expect(limits.limitOf(RecitationErrorType.tanbeeh), 5);
      expect(limits.limitOf(RecitationErrorType.talqeen), 2);
      expect(limits.limitOf(RecitationErrorType.tashkeel), 1);
      expect(limits.limitOf(RecitationErrorType.tajweed), 8);
    });

    test('اختبار allows 3 تنبيهات / 2 تلقينات / 1 تشكيل / 5 تجويد '
        'per question', () {
      const limits = AssessmentErrorLimits.examPerQuestion;
      expect(limits.limitOf(RecitationErrorType.tanbeeh), 3);
      expect(limits.limitOf(RecitationErrorType.talqeen), 2);
      expect(limits.limitOf(RecitationErrorType.tashkeel), 1);
      expect(limits.limitOf(RecitationErrorType.tajweed), 5);
    });

    test('a tally at the limit is allowed; one past it is not', () {
      const atLimit = RecitationErrorTally(
        tanbeehat: 5,
        talqeenat: 2,
        tashkeel: 1,
        tajweed: 8,
      );
      expect(AssessmentErrorLimits.sardPerFace.allows(atLimit), isTrue);

      final pastLimit = atLimit.adding(RecitationErrorType.tashkeel);
      expect(AssessmentErrorLimits.sardPerFace.allows(pastLimit), isFalse);
      expect(AssessmentErrorLimits.sardPerFace.exceededBy(pastLimit), [
        RecitationErrorType.tashkeel,
      ]);
    });
  });

  group('SardEvaluation', () {
    test('passes (موفق) when every face stays within the per-face limits', () {
      final evaluation = SardEvaluation([
        const RecitationErrorTally(tanbeehat: 5, tajweed: 8),
        const RecitationErrorTally(talqeenat: 2, tashkeel: 1),
        RecitationErrorTally.empty,
      ]);
      expect(evaluation.passed, isTrue);
      expect(evaluation.outcome, AssessmentOutcome.muwaffaq);
      expect(evaluation.outcome.nameAr, 'موفق');
      expect(evaluation.totalErrors, 16);
    });

    test('fails (غير موفق) when a single face exceeds one limit', () {
      final evaluation = SardEvaluation([
        RecitationErrorTally.empty,
        const RecitationErrorTally(talqeenat: 3),
        RecitationErrorTally.empty,
      ]);
      expect(evaluation.passed, isFalse);
      expect(evaluation.outcome, AssessmentOutcome.ghayrMuwaffaq);
      expect(evaluation.outcome.nameAr, 'غير موفق');
      expect(evaluation.failedFaceIndexes, [1]);
    });

    test('a سرد covers at least one face', () {
      expect(() => SardEvaluation(const []), throwsA(isA<ArgumentError>()));
    });
  });

  group('ExamEvaluation', () {
    test('passes when every one of the 5 questions stays within limits', () {
      final evaluation = ExamEvaluation(
        List.filled(
          ExamEvaluation.questionCount,
          const RecitationErrorTally(tanbeehat: 3, tajweed: 5),
        ),
      );
      expect(evaluation.passed, isTrue);
      expect(evaluation.outcome, AssessmentOutcome.muwaffaq);
      expect(evaluation.totalErrors, 40);
    });

    test('fails when any single question exceeds a limit', () {
      final questions = List.filled(
        ExamEvaluation.questionCount,
        RecitationErrorTally.empty,
      );
      questions[4] = const RecitationErrorTally(tajweed: 6);
      final evaluation = ExamEvaluation(questions);
      expect(evaluation.passed, isFalse);
      expect(evaluation.failedQuestionIndexes, [4]);
    });

    test('an اختبار has exactly 5 questions', () {
      expect(
        () => ExamEvaluation([RecitationErrorTally.empty]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('total errors within limits can still exceed any single question '
        'limit without failing — the rule is per question, not overall', () {
      // 4 تنبيهات total, but never more than 3 on one question.
      final questions = [
        const RecitationErrorTally(tanbeehat: 3),
        const RecitationErrorTally(tanbeehat: 1),
        RecitationErrorTally.empty,
        RecitationErrorTally.empty,
        RecitationErrorTally.empty,
      ];
      expect(ExamEvaluation(questions).passed, isTrue);
    });
  });
}
