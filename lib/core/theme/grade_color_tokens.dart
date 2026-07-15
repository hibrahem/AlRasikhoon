// lib/core/theme/grade_color_tokens.dart
import 'package:flutter/material.dart';
import '../utils/grade_calculator.dart';
import 'app_tokens.dart';

/// Maps a [Grade] tier to its brightness-aware [AppTokens] color.
///
/// [GradeCalculator] (in `core/utils`) is a plain Dart utility with no
/// [BuildContext] — it deliberately never bakes a raw, brightness-unaware
/// color into [GradeInfo]. This mapping is the presentation-layer
/// counterpart: it lives here, in `core/theme`, and is only ever evaluated
/// at a point where a [BuildContext] (and thus a resolved [AppTokens]) is
/// actually available, so the right color comes back for the theme that is
/// currently active (see al_rasikhoon-3k3).
extension GradeColorTokens on AppTokens {
  /// The token color for [grade] under this [AppTokens] (light or dark).
  Color colorForGrade(Grade grade) {
    switch (grade) {
      case Grade.rasikh:
        return gradeRasikh;
      case Grade.mutqin:
        return gradeMutqin;
      case Grade.hafiz:
        return gradeHafiz;
      case Grade.mujtahid:
        return gradeMujtahid;
      case Grade.muhib:
        return gradeMuhib;
    }
  }

  /// Convenience overload for callers that already have a [GradeInfo].
  Color colorForGradeInfo(GradeInfo gradeInfo) =>
      colorForGrade(gradeInfo.grade);
}
