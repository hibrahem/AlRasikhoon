import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import 'package:flutter/material.dart';

enum Grade {
  rasikh,   // 0 errors - 5 stars
  mutqin,   // 1 error - 4 stars
  hafiz,    // 2 errors - 3 stars
  mujtahid, // 3 errors - 2 stars
  muhib,    // 4+ errors - 1 star
}

class GradeInfo {
  final Grade grade;
  final String nameAr;
  final String nameEn;
  final int stars;
  final bool passed;
  final Color color;

  const GradeInfo({
    required this.grade,
    required this.nameAr,
    required this.nameEn,
    required this.stars,
    required this.passed,
    required this.color,
  });
}

class GradeCalculator {
  GradeCalculator._();

  static GradeInfo calculate(int errorCount) {
    if (errorCount <= AppConstants.errorsForRasikh) {
      return const GradeInfo(
        grade: Grade.rasikh,
        nameAr: 'راسخ',
        nameEn: 'Rasikh',
        stars: 5,
        passed: true,
        color: AppColors.gradeRasikh,
      );
    } else if (errorCount <= AppConstants.errorsForMutqin) {
      return const GradeInfo(
        grade: Grade.mutqin,
        nameAr: 'متقن',
        nameEn: 'Mutqin',
        stars: 4,
        passed: true,
        color: AppColors.gradeMutqin,
      );
    } else if (errorCount <= AppConstants.errorsForHafiz) {
      return const GradeInfo(
        grade: Grade.hafiz,
        nameAr: 'حافظ',
        nameEn: 'Hafiz',
        stars: 3,
        passed: true,
        color: AppColors.gradeHafiz,
      );
    } else if (errorCount <= AppConstants.errorsForMujtahid) {
      return const GradeInfo(
        grade: Grade.mujtahid,
        nameAr: 'مجتهد',
        nameEn: 'Mujtahid',
        stars: 2,
        passed: true,
        color: AppColors.gradeMujtahid,
      );
    } else {
      return const GradeInfo(
        grade: Grade.muhib,
        nameAr: 'محب',
        nameEn: 'Muhib',
        stars: 1,
        passed: false,
        color: AppColors.gradeMuhib,
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

  static Color getGradeColor(int errorCount) {
    return calculate(errorCount).color;
  }

  /// Calculate overall session grade from the three parts
  /// Part 1: New memorization
  /// Part 2: Recent review
  /// Part 3: Distant review
  static GradeInfo calculateSessionGrade({
    required int newMemorizationErrors,
    required int recentReviewErrors,
    required int distantReviewErrors,
  }) {
    // The session passes if all three parts pass
    final part1Passed = isPassed(newMemorizationErrors);
    final part2Passed = isPassed(recentReviewErrors);
    final part3Passed = isPassed(distantReviewErrors);

    if (!part1Passed || !part2Passed || !part3Passed) {
      // Session failed - return muhib grade
      return const GradeInfo(
        grade: Grade.muhib,
        nameAr: 'محب',
        nameEn: 'Muhib',
        stars: 1,
        passed: false,
        color: AppColors.gradeMuhib,
      );
    }

    // All parts passed - calculate average based on total errors
    final totalErrors = newMemorizationErrors + recentReviewErrors + distantReviewErrors;

    // Use average errors for final grade
    final averageErrors = (totalErrors / 3).ceil();
    return calculate(averageErrors);
  }
}
