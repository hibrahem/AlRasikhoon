import '../../data/models/session_model.dart';

/// How the app SPEAKS about an assessment.
///
/// An assessment's name is the curriculum's own words ([SessionModel.titleAr],
/// i.e. `scope.label_ar` verbatim — `سرد الجزء رقم 30 كاملًا على المحفظ المتابع`).
/// Everything else the UI needs to say about it — what is being assessed, and
/// what the supervisor is to do — is derived from the assessment's TIER, never
/// from a hizb: a juz-tier سرد covers a whole juz and a cumulative one covers up
/// to three, so `'سرد الحزب $hizb'` cannot name them at all.
///
/// One place, so the five screens that show an assessment agree.
extension AssessmentCopy on SessionModel {
  /// What this assessment covers, in one short phrase:
  /// `الحزب 59` / `الجزء 30` / `الأجزاء 28 و 29 و 30`.
  ///
  /// Empty for a lesson, which assesses nothing.
  String get scopeAr {
    final scope = this.scope;
    if (scope == null) return '';

    switch (scope.tier) {
      case AssessmentTier.unit:
        final hizb = scope.hizbNumber;
        // A unit is a hizb in levels 1-2 and a surah group elsewhere, where it
        // has no hizb to name — so it is named by the juz it sits in.
        return hizb != null ? 'الحزب $hizb' : 'وحدة من الجزء $juzNumber';
      case AssessmentTier.juz:
        final juz = scope.juzNumbers.isNotEmpty
            ? scope.juzNumbers.first
            : juzNumber;
        return 'الجزء $juz';
      case AssessmentTier.cumulative:
        final juzNumbers = [...scope.juzNumbers]..sort();
        if (juzNumbers.isEmpty) return 'المستوى كاملًا';
        return 'الأجزاء ${juzNumbers.join(' و ')}';
    }
  }

  /// What the supervisor (سرد/اختبار) is to do, worded for the tier being
  /// assessed. Empty for a lesson.
  String get assessmentInstructionAr {
    final scope = this.scope;
    if (scope == null) return '';

    final covers = scopeAr;
    final cumulative = scope.tier == AssessmentTier.cumulative;

    if (isSard) {
      return cumulative
          ? 'يسرد الطالب $covers — المستوى كاملًا — من الذاكرة دون النظر في المصحف'
          : 'يسرد الطالب $covers كاملًا من الذاكرة دون النظر في المصحف';
    }
    return cumulative
        ? 'يختبر المشرف الطالب في $covers — المستوى كاملًا'
        : 'يختبر المشرف الطالب في $covers كاملًا';
  }
}
