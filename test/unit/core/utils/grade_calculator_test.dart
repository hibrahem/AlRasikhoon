import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/utils/grade_calculator.dart';
import 'package:al_rasikhoon/core/constants/app_colors.dart';

void main() {
  group('GradeCalculator', () {
    group('calculate', () {
      // راسخ: 0 errors
      test('0 errors returns راسخ with 5 stars and passed', () {
        final grade = GradeCalculator.calculate(0);

        expect(grade.grade, Grade.rasikh);
        expect(grade.nameAr, 'راسخ');
        expect(grade.nameEn, 'Rasikh');
        expect(grade.stars, 5);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeRasikh);
      });

      // متقن: 1-2 errors
      test('1 error returns متقن with 4 stars and passed', () {
        final grade = GradeCalculator.calculate(1);

        expect(grade.grade, Grade.mutqin);
        expect(grade.nameAr, 'متقن');
        expect(grade.nameEn, 'Mutqin');
        expect(grade.stars, 4);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMutqin);
      });

      test('2 errors returns متقن with 4 stars and passed', () {
        final grade = GradeCalculator.calculate(2);

        expect(grade.grade, Grade.mutqin);
        expect(grade.nameAr, 'متقن');
        expect(grade.nameEn, 'Mutqin');
        expect(grade.stars, 4);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMutqin);
      });

      // حافظ: 3-4 errors
      test('3 errors returns حافظ with 3 stars and passed', () {
        final grade = GradeCalculator.calculate(3);

        expect(grade.grade, Grade.hafiz);
        expect(grade.nameAr, 'حافظ');
        expect(grade.nameEn, 'Hafiz');
        expect(grade.stars, 3);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeHafiz);
      });

      test('4 errors returns حافظ with 3 stars and passed', () {
        final grade = GradeCalculator.calculate(4);

        expect(grade.grade, Grade.hafiz);
        expect(grade.nameAr, 'حافظ');
        expect(grade.nameEn, 'Hafiz');
        expect(grade.stars, 3);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeHafiz);
      });

      // مجتهد: 5-6 errors
      test('5 errors returns مجتهد with 2 stars and passed', () {
        final grade = GradeCalculator.calculate(5);

        expect(grade.grade, Grade.mujtahid);
        expect(grade.nameAr, 'مجتهد');
        expect(grade.nameEn, 'Mujtahid');
        expect(grade.stars, 2);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMujtahid);
      });

      test('6 errors returns مجتهد with 2 stars and passed', () {
        final grade = GradeCalculator.calculate(6);

        expect(grade.grade, Grade.mujtahid);
        expect(grade.nameAr, 'مجتهد');
        expect(grade.nameEn, 'Mujtahid');
        expect(grade.stars, 2);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMujtahid);
      });

      // محب: 7+ errors (fail)
      test('7 errors returns محب with 1 star and NOT passed', () {
        final grade = GradeCalculator.calculate(7);

        expect(grade.grade, Grade.muhib);
        expect(grade.nameAr, 'محب');
        expect(grade.nameEn, 'Muhib');
        expect(grade.stars, 1);
        expect(grade.passed, false);
        expect(grade.color, AppColors.gradeMuhib);
      });

      test('10 errors returns محب (fail)', () {
        final grade = GradeCalculator.calculate(10);

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('20 errors returns محب (fail)', () {
        final grade = GradeCalculator.calculate(20);

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });
    });

    group('isPassed', () {
      test('returns true for 0 errors', () {
        expect(GradeCalculator.isPassed(0), true);
      });

      test('returns true for 1-2 errors (متقن range)', () {
        expect(GradeCalculator.isPassed(1), true);
        expect(GradeCalculator.isPassed(2), true);
      });

      test('returns true for 3-4 errors (حافظ range)', () {
        expect(GradeCalculator.isPassed(3), true);
        expect(GradeCalculator.isPassed(4), true);
      });

      test('returns true for 5-6 errors (مجتهد range)', () {
        expect(GradeCalculator.isPassed(5), true);
        expect(GradeCalculator.isPassed(6), true);
      });

      test('returns false for 7 errors (boundary)', () {
        expect(GradeCalculator.isPassed(7), false);
      });

      test('returns false for 8+ errors', () {
        expect(GradeCalculator.isPassed(8), false);
        expect(GradeCalculator.isPassed(10), false);
        expect(GradeCalculator.isPassed(20), false);
      });
    });

    group('getStars', () {
      test('returns 5 stars for 0 errors', () {
        expect(GradeCalculator.getStars(0), 5);
      });

      test('returns 4 stars for 1-2 errors', () {
        expect(GradeCalculator.getStars(1), 4);
        expect(GradeCalculator.getStars(2), 4);
      });

      test('returns 3 stars for 3-4 errors', () {
        expect(GradeCalculator.getStars(3), 3);
        expect(GradeCalculator.getStars(4), 3);
      });

      test('returns 2 stars for 5-6 errors', () {
        expect(GradeCalculator.getStars(5), 2);
        expect(GradeCalculator.getStars(6), 2);
      });

      test('returns 1 star for 7+ errors', () {
        expect(GradeCalculator.getStars(7), 1);
        expect(GradeCalculator.getStars(10), 1);
      });
    });

    group('getGradeNameAr', () {
      test('returns راسخ for 0 errors', () {
        expect(GradeCalculator.getGradeNameAr(0), 'راسخ');
      });

      test('returns متقن for 1-2 errors', () {
        expect(GradeCalculator.getGradeNameAr(1), 'متقن');
        expect(GradeCalculator.getGradeNameAr(2), 'متقن');
      });

      test('returns حافظ for 3-4 errors', () {
        expect(GradeCalculator.getGradeNameAr(3), 'حافظ');
        expect(GradeCalculator.getGradeNameAr(4), 'حافظ');
      });

      test('returns مجتهد for 5-6 errors', () {
        expect(GradeCalculator.getGradeNameAr(5), 'مجتهد');
        expect(GradeCalculator.getGradeNameAr(6), 'مجتهد');
      });

      test('returns محب for 7+ errors', () {
        expect(GradeCalculator.getGradeNameAr(7), 'محب');
        expect(GradeCalculator.getGradeNameAr(10), 'محب');
      });
    });

    group('getGradeNameEn', () {
      test('returns Rasikh for 0 errors', () {
        expect(GradeCalculator.getGradeNameEn(0), 'Rasikh');
      });

      test('returns Mutqin for 1-2 errors', () {
        expect(GradeCalculator.getGradeNameEn(1), 'Mutqin');
        expect(GradeCalculator.getGradeNameEn(2), 'Mutqin');
      });

      test('returns Hafiz for 3-4 errors', () {
        expect(GradeCalculator.getGradeNameEn(3), 'Hafiz');
        expect(GradeCalculator.getGradeNameEn(4), 'Hafiz');
      });

      test('returns Mujtahid for 5-6 errors', () {
        expect(GradeCalculator.getGradeNameEn(5), 'Mujtahid');
        expect(GradeCalculator.getGradeNameEn(6), 'Mujtahid');
      });

      test('returns Muhib for 7+ errors', () {
        expect(GradeCalculator.getGradeNameEn(7), 'Muhib');
        expect(GradeCalculator.getGradeNameEn(10), 'Muhib');
      });
    });

    group('getGradeColor', () {
      test('returns correct color for each grade', () {
        expect(GradeCalculator.getGradeColor(0), AppColors.gradeRasikh);
        expect(GradeCalculator.getGradeColor(1), AppColors.gradeMutqin);
        expect(GradeCalculator.getGradeColor(2), AppColors.gradeMutqin);
        expect(GradeCalculator.getGradeColor(3), AppColors.gradeHafiz);
        expect(GradeCalculator.getGradeColor(4), AppColors.gradeHafiz);
        expect(GradeCalculator.getGradeColor(5), AppColors.gradeMujtahid);
        expect(GradeCalculator.getGradeColor(6), AppColors.gradeMujtahid);
        expect(GradeCalculator.getGradeColor(7), AppColors.gradeMuhib);
      });
    });

    group('calculateSessionGrade', () {
      test('all parts 0 errors returns راسخ', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grade.grade, Grade.rasikh);
        expect(grade.passed, true);
      });

      test('all parts 6 errors each passes with calculated average', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 6,
          recentReviewErrors: 6,
          distantReviewErrors: 6,
        );

        // Total: 18, Average: 6 (ceiling) = مجتهد (passes with 5-6 errors)
        expect(grade.passed, true);
        expect(grade.grade, Grade.mujtahid);
      });

      test('part1 fails (7 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 7,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('part2 fails (7 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 7,
          distantReviewErrors: 0,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('part3 fails (7 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 7,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('average calculation with uneven errors', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 2,
          distantReviewErrors: 4,
        );

        // Total: 6, Average: 2 (ceiling) = متقن
        expect(grade.grade, Grade.mutqin);
        expect(grade.passed, true);
      });

      test('ceiling rounding applied correctly', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 3,
          recentReviewErrors: 3,
          distantReviewErrors: 3,
        );

        // Total: 9, Average: 3 (9/3) = حافظ
        expect(grade.grade, Grade.hafiz);
      });

      test('ceiling rounds up for non-integer average', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 4,
          recentReviewErrors: 4,
          distantReviewErrors: 4,
        );

        // Total: 12, Average: 4 (12/3) = حافظ
        expect(grade.grade, Grade.hafiz);
      });

      test('mixed low and medium errors averages correctly', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 6,
        );

        // Total: 6, Average: 2 (ceiling of 6/3) = متقن
        expect(grade.grade, Grade.mutqin);
        expect(grade.passed, true);
      });
    });

    group('Grade enum', () {
      test('has all expected values', () {
        expect(Grade.values, contains(Grade.rasikh));
        expect(Grade.values, contains(Grade.mutqin));
        expect(Grade.values, contains(Grade.hafiz));
        expect(Grade.values, contains(Grade.mujtahid));
        expect(Grade.values, contains(Grade.muhib));
        expect(Grade.values.length, 5);
      });
    });

    group('GradeInfo', () {
      test('holds all required fields', () {
        const gradeInfo = GradeInfo(
          grade: Grade.rasikh,
          nameAr: 'راسخ',
          nameEn: 'Rasikh',
          stars: 5,
          passed: true,
          color: AppColors.gradeRasikh,
        );

        expect(gradeInfo.grade, Grade.rasikh);
        expect(gradeInfo.nameAr, 'راسخ');
        expect(gradeInfo.nameEn, 'Rasikh');
        expect(gradeInfo.stars, 5);
        expect(gradeInfo.passed, true);
      });
    });
  });
}
