import '../constants/app_constants.dart';

enum Grade {
  rasikh, // 0 errors - 5 stars
  mutqin, // 1-2 errors - 4 stars
  hafiz, // 3-4 errors - 3 stars
  mujtahid, // 5-6 errors - 2 stars
  muhib, // 7+ errors - 1 star (fail)
}

/// Presentation metadata for a [Grade] tier.
///
/// Deliberately holds NO color: [GradeCalculator] is a plain Dart utility
/// with no [BuildContext], so it cannot know whether the app is currently in
/// light or dark mode. Baking a `const` color in here would freeze it at the
/// wrong brightness. Callers that need a grade's color must resolve it at
/// render time via `context.tokens.colorForGrade(gradeInfo.grade)` (see
/// `lib/core/theme/grade_color_tokens.dart`, al_rasikhoon-3k3).
class GradeInfo {
  final Grade grade;
  final String nameAr;
  final String nameEn;
  final int stars;
  final bool passed;

  const GradeInfo({
    required this.grade,
    required this.nameAr,
    required this.nameEn,
    required this.stars,
    required this.passed,
  });
}

class GradeCalculator {
  GradeCalculator._();

  /// Build the [GradeInfo] for a given [Grade] value.
  ///
  /// Single source of truth for the per-grade presentation metadata
  /// (Arabic / English names, stars, pass status) so the
  /// level-agnostic [calculate] and the level-aware [calculateForLevel]
  /// never drift apart.
  static GradeInfo _infoFor(Grade grade) {
    switch (grade) {
      case Grade.rasikh:
        return const GradeInfo(
          grade: Grade.rasikh,
          nameAr: 'راسخ',
          nameEn: 'Rasikh',
          stars: 5,
          passed: true,
        );
      case Grade.mutqin:
        return const GradeInfo(
          grade: Grade.mutqin,
          nameAr: 'متقن',
          nameEn: 'Mutqin',
          stars: 4,
          passed: true,
        );
      case Grade.hafiz:
        return const GradeInfo(
          grade: Grade.hafiz,
          nameAr: 'حافظ',
          nameEn: 'Hafiz',
          stars: 3,
          passed: true,
        );
      case Grade.mujtahid:
        return const GradeInfo(
          grade: Grade.mujtahid,
          nameAr: 'مجتهد',
          nameEn: 'Mujtahid',
          stars: 2,
          passed: true,
        );
      case Grade.muhib:
        return const GradeInfo(
          grade: Grade.muhib,
          nameAr: 'محب',
          nameEn: 'Muhib',
          stars: 1,
          passed: false,
        );
    }
  }

  /// Level-aware grade for a single evaluated component (a سرد / اختبار /
  /// recitation part), per the per-level table in
  /// hibrahem/AlRasikhoon#22.
  ///
  /// The same mistake count is stricter at low levels and more lenient at
  /// high levels. Let `B = (level - 1) ~/ 2` (levels 1..10 → 0,0,1,1,2,2,
  /// 3,3,4,4):
  ///
  /// * `mistakes <= B`     → راسخ   (top grade)
  /// * `mistakes == B + 1` → متقن
  /// * `mistakes == B + 2` → حافظ
  /// * `mistakes == B + 3` → مجتهد
  /// * `mistakes >= B + 4` → محب / ويعاد (must repeat — fail)
  ///
  /// [level] is the student's memorization level (clamped to 1..10 for
  /// out-of-range input). [mistakes] is the error count (negative input is
  /// treated as 0). This is the per-component mapping ONLY — it deliberately
  /// does NOT decide whether a whole session passes (that aggregation is the
  /// responsibility of the session-level logic).
  static GradeInfo calculateForLevel(int level, int mistakes) {
    return _infoFor(gradeForLevel(level, mistakes));
  }

  /// Pure (level, mistakes) → [Grade] mapping. See [calculateForLevel].
  static Grade gradeForLevel(int level, int mistakes) {
    final clampedLevel = level < 1 ? 1 : (level > 10 ? 10 : level);
    final safeMistakes = mistakes < 0 ? 0 : mistakes;

    // Base threshold B for راسخ.
    final base = (clampedLevel - 1) ~/ 2;

    if (safeMistakes <= base) {
      return Grade.rasikh;
    } else if (safeMistakes == base + 1) {
      return Grade.mutqin;
    } else if (safeMistakes == base + 2) {
      return Grade.hafiz;
    } else if (safeMistakes == base + 3) {
      return Grade.mujtahid;
    } else {
      // safeMistakes >= base + 4
      return Grade.muhib;
    }
  }

  static GradeInfo calculate(int errorCount) {
    // Grading thresholds per spec:
    // راسخ: 0 errors, متقن: 1-2, حافظ: 3-4, مجتهد: 5-6, محب: 7+
    if (errorCount <= AppConstants.errorsForRasikh) {
      // 0 errors = راسخ
      return const GradeInfo(
        grade: Grade.rasikh,
        nameAr: 'راسخ',
        nameEn: 'Rasikh',
        stars: 5,
        passed: true,
      );
    } else if (errorCount <= AppConstants.maxErrorsForMutqin) {
      // 1-2 errors = متقن
      return const GradeInfo(
        grade: Grade.mutqin,
        nameAr: 'متقن',
        nameEn: 'Mutqin',
        stars: 4,
        passed: true,
      );
    } else if (errorCount <= AppConstants.maxErrorsForHafiz) {
      // 3-4 errors = حافظ
      return const GradeInfo(
        grade: Grade.hafiz,
        nameAr: 'حافظ',
        nameEn: 'Hafiz',
        stars: 3,
        passed: true,
      );
    } else if (errorCount <= AppConstants.maxErrorsForMujtahid) {
      // 5-6 errors = مجتهد
      return const GradeInfo(
        grade: Grade.mujtahid,
        nameAr: 'مجتهد',
        nameEn: 'Mujtahid',
        stars: 2,
        passed: true,
      );
    } else {
      // 7+ errors = محب (fail)
      return const GradeInfo(
        grade: Grade.muhib,
        nameAr: 'محب',
        nameEn: 'Muhib',
        stars: 1,
        passed: false,
      );
    }
  }

  static bool isPassed(int errorCount) {
    return errorCount <= AppConstants.maxErrorsToPass;
  }

  static int getStars(int errorCount) {
    return calculate(errorCount).stars;
  }

  static String getGradeNameAr(int errorCount) {
    return calculate(errorCount).nameAr;
  }

  static String getGradeNameEn(int errorCount) {
    return calculate(errorCount).nameEn;
  }

  /// Whether a whole memorization session passes, given the student's
  /// [level] and the per-component mistake counts (new / near / far), per
  /// hibrahem/AlRasikhoon#24.
  ///
  /// A session is **FAILED if ANY one component grades محب (ويعاد)** — the
  /// student must redo it next time. It PASSES only if **none** of the three
  /// is محب. There is deliberately NO averaging: a single محب can never be
  /// masked by good grades in the other components.
  ///
  /// Each component's grade is computed with the level-based
  /// [gradeForLevel] (#22), so the same mistake count is stricter at low
  /// levels and more lenient at high levels.
  static bool sessionPassesForLevel({
    required int level,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
  }) {
    final newGrade = gradeForLevel(level, newMemorizationErrors);
    final nearGrade = gradeForLevel(level, recentReviewErrors);
    final farGrade = gradeForLevel(level, distantReviewErrors);

    return newGrade != Grade.muhib &&
        nearGrade != Grade.muhib &&
        farGrade != Grade.muhib;
  }

  /// Overall session [GradeInfo] for the three parts at the student's
  /// [level], per hibrahem/AlRasikhoon#24.
  ///
  /// Part 1: New memorization (الجديد)
  /// Part 2: Recent review (القريب)
  /// Part 3: Distant review (البعيد)
  ///
  /// The outcome is **binary** — there is no averaging. If any component is
  /// محب the session is failed and this returns the محب [GradeInfo]
  /// (`passed: false`). Otherwise it returns the **worst (lowest)** of the
  /// three component grades, so the session grade can never claim to be
  /// better than its weakest part. Use [sessionPassesForLevel] when only the
  /// pass/fail boolean is needed.
  static GradeInfo calculateSessionGrade({
    required int level,
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
  }) {
    final grades = <Grade>[
      gradeForLevel(level, newMemorizationErrors),
      gradeForLevel(level, recentReviewErrors),
      gradeForLevel(level, distantReviewErrors),
    ];

    // The worst (lowest) grade drives the session result — enum values are
    // ordered best-to-worst (rasikh .. muhib), so the highest index wins.
    final worst = grades.reduce((a, b) => a.index >= b.index ? a : b);
    return _infoFor(worst);
  }
}
