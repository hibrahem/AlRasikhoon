/// How a سرد and an اختبار are evaluated, straight from the curriculum's own
/// assessment sheets (نموذج السرد بالجدول / نموذج الاختبار).
///
/// An assessment is NOT graded on the راسخ..محب lesson scale. The sheets track
/// four error types — التنبيهات، التلقينات، أخطاء التشكيل، أخطاء التجويد — and
/// the verdict is binary: موفق or غير موفق.
///
/// - A سرد records errors per FACE (وجه) recited, and passes only if every
///   single face stays within the per-face allowance (5/2/1/8).
/// - An اختبار is five questions, and passes only if every single question
///   stays within the per-question allowance (3/2/1/5).
///
/// The allowances are identical across all ten levels and every scope (حزب,
/// جزء, جزءان, ثلاثة أجزاء) — verified against the level-1 and level-9 sheets.
library;

/// The four error types the curriculum tracks during a سرد or اختبار.
enum RecitationErrorType { tanbeeh, talqeen, tashkeel, tajweed }

extension RecitationErrorTypeX on RecitationErrorType {
  /// The sheet's own column heading for this error type.
  String get nameAr {
    switch (this) {
      case RecitationErrorType.tanbeeh:
        return 'التنبيهات';
      case RecitationErrorType.talqeen:
        return 'التلقينات';
      case RecitationErrorType.tashkeel:
        return 'التشكيل';
      case RecitationErrorType.tajweed:
        return 'التجويد';
    }
  }
}

/// The errors of one assessed unit — one face (وجه) of a سرد, or one question
/// of an اختبار. Immutable; counting up or down returns a new tally.
class RecitationErrorTally {
  final int tanbeehat;
  final int talqeenat;
  final int tashkeel;
  final int tajweed;

  const RecitationErrorTally({
    this.tanbeehat = 0,
    this.talqeenat = 0,
    this.tashkeel = 0,
    this.tajweed = 0,
  }) : assert(
         tanbeehat >= 0 && talqeenat >= 0 && tashkeel >= 0 && tajweed >= 0,
         'Error counts cannot be negative',
       );

  /// Runtime guard for non-const construction paths (deserialization).
  factory RecitationErrorTally.checked({
    int tanbeehat = 0,
    int talqeenat = 0,
    int tashkeel = 0,
    int tajweed = 0,
  }) {
    for (final count in [tanbeehat, talqeenat, tashkeel, tajweed]) {
      if (count < 0) {
        throw ArgumentError.value(count, 'count', 'cannot be negative');
      }
    }
    return RecitationErrorTally(
      tanbeehat: tanbeehat,
      talqeenat: talqeenat,
      tashkeel: tashkeel,
      tajweed: tajweed,
    );
  }

  static const empty = RecitationErrorTally();

  int get total => tanbeehat + talqeenat + tashkeel + tajweed;

  int countOf(RecitationErrorType type) {
    switch (type) {
      case RecitationErrorType.tanbeeh:
        return tanbeehat;
      case RecitationErrorType.talqeen:
        return talqeenat;
      case RecitationErrorType.tashkeel:
        return tashkeel;
      case RecitationErrorType.tajweed:
        return tajweed;
    }
  }

  /// One more error of [type].
  RecitationErrorTally adding(RecitationErrorType type) =>
      _with(type, countOf(type) + 1);

  /// One error of [type] undone. Clamps at zero: undoing what was never
  /// recorded is a no-op, not a negative count.
  RecitationErrorTally removing(RecitationErrorType type) =>
      countOf(type) == 0 ? this : _with(type, countOf(type) - 1);

  RecitationErrorTally _with(RecitationErrorType type, int count) {
    return RecitationErrorTally(
      tanbeehat: type == RecitationErrorType.tanbeeh ? count : tanbeehat,
      talqeenat: type == RecitationErrorType.talqeen ? count : talqeenat,
      tashkeel: type == RecitationErrorType.tashkeel ? count : tashkeel,
      tajweed: type == RecitationErrorType.tajweed ? count : tajweed,
    );
  }

  @override
  String toString() =>
      'RecitationErrorTally(تنبيهات: $tanbeehat, تلقينات: $talqeenat, '
      'تشكيل: $tashkeel, تجويد: $tajweed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecitationErrorTally &&
          other.tanbeehat == tanbeehat &&
          other.talqeenat == talqeenat &&
          other.tashkeel == tashkeel &&
          other.tajweed == tajweed;

  @override
  int get hashCode => Object.hash(tanbeehat, talqeenat, tashkeel, tajweed);
}

/// عدد الأخطاء المسموح بها — the allowance one assessed unit may not exceed.
class AssessmentErrorLimits {
  final int maxTanbeehat;
  final int maxTalqeenat;
  final int maxTashkeel;
  final int maxTajweed;

  const AssessmentErrorLimits({
    required this.maxTanbeehat,
    required this.maxTalqeenat,
    required this.maxTashkeel,
    required this.maxTajweed,
  });

  /// عدد الأخطاء المسموح بها في الوجه الواحد لاجتياز السرد.
  static const sardPerFace = AssessmentErrorLimits(
    maxTanbeehat: 5,
    maxTalqeenat: 2,
    maxTashkeel: 1,
    maxTajweed: 8,
  );

  /// عدد الأخطاء المسموح بها في السؤال الواحد لاجتياز الاختبار.
  static const examPerQuestion = AssessmentErrorLimits(
    maxTanbeehat: 3,
    maxTalqeenat: 2,
    maxTashkeel: 1,
    maxTajweed: 5,
  );

  int limitOf(RecitationErrorType type) {
    switch (type) {
      case RecitationErrorType.tanbeeh:
        return maxTanbeehat;
      case RecitationErrorType.talqeen:
        return maxTalqeenat;
      case RecitationErrorType.tashkeel:
        return maxTashkeel;
      case RecitationErrorType.tajweed:
        return maxTajweed;
    }
  }

  /// Whether [tally] stays within every limit. At the limit is still allowed;
  /// the sheet forgives exactly the allowance, not one less.
  bool allows(RecitationErrorTally tally) => RecitationErrorType.values.every(
    (type) => tally.countOf(type) <= limitOf(type),
  );

  /// The error types [tally] exceeds, for pointing at WHY a unit failed.
  List<RecitationErrorType> exceededBy(RecitationErrorTally tally) =>
      RecitationErrorType.values
          .where((type) => tally.countOf(type) > limitOf(type))
          .toList();
}

/// The sheet's binary verdict.
enum AssessmentOutcome { muwaffaq, ghayrMuwaffaq }

extension AssessmentOutcomeX on AssessmentOutcome {
  String get nameAr => this == AssessmentOutcome.muwaffaq ? 'موفق' : 'غير موفق';

  bool get passed => this == AssessmentOutcome.muwaffaq;
}

/// A سرد, evaluated: one tally per face recited, judged face by face.
class SardEvaluation {
  static const limits = AssessmentErrorLimits.sardPerFace;

  /// Tallies in recitation order — faces[0] is the first face recited.
  final List<RecitationErrorTally> faces;

  SardEvaluation(List<RecitationErrorTally> faces)
    : faces = List.unmodifiable(faces) {
    if (this.faces.isEmpty) {
      throw ArgumentError('A سرد covers at least one face');
    }
  }

  /// موفق only if EVERY face stays within the per-face allowance. One bad
  /// face fails the whole سرد — totals across faces are never compared.
  bool get passed => faces.every(limits.allows);

  AssessmentOutcome get outcome =>
      passed ? AssessmentOutcome.muwaffaq : AssessmentOutcome.ghayrMuwaffaq;

  int get totalErrors => faces.fold(0, (sum, face) => sum + face.total);

  /// Indexes (into [faces]) of the faces that broke a limit.
  List<int> get failedFaceIndexes => [
    for (var i = 0; i < faces.length; i++)
      if (!limits.allows(faces[i])) i,
  ];
}

/// An اختبار, evaluated: exactly five questions, judged question by question.
class ExamEvaluation {
  static const questionCount = 5;
  static const limits = AssessmentErrorLimits.examPerQuestion;

  /// Tallies in sheet order — questions[0] is السؤال الأول.
  final List<RecitationErrorTally> questions;

  ExamEvaluation(List<RecitationErrorTally> questions)
    : questions = List.unmodifiable(questions) {
    if (this.questions.length != questionCount) {
      throw ArgumentError.value(
        questions.length,
        'questions',
        'An اختبار has exactly $questionCount questions',
      );
    }
  }

  /// موفق only if EVERY question stays within the per-question allowance.
  bool get passed => questions.every(limits.allows);

  AssessmentOutcome get outcome =>
      passed ? AssessmentOutcome.muwaffaq : AssessmentOutcome.ghayrMuwaffaq;

  int get totalErrors => questions.fold(0, (sum, q) => sum + q.total);

  /// Indexes (into [questions]) of the questions that broke a limit.
  List<int> get failedQuestionIndexes => [
    for (var i = 0; i < questions.length; i++)
      if (!limits.allows(questions[i])) i,
  ];
}
