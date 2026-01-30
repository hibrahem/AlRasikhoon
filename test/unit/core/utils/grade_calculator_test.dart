import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/utils/grade_calculator.dart';
import 'package:al_rasikhoon/core/constants/app_colors.dart';

void main() {
  group('GradeCalculator', () {
    group('calculate', () {
      test('0 errors returns راسخ with 5 stars and passed', () {
        final grade = GradeCalculator.calculate(0);

        expect(grade.grade, Grade.rasikh);
        expect(grade.nameAr, 'راسخ');
        expect(grade.nameEn, 'Rasikh');
        expect(grade.stars, 5);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeRasikh);
      });

      test('1 error returns متقن with 4 stars and passed', () {
        final grade = GradeCalculator.calculate(1);

        expect(grade.grade, Grade.mutqin);
        expect(grade.nameAr, 'متقن');
        expect(grade.nameEn, 'Mutqin');
        expect(grade.stars, 4);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMutqin);
      });

      test('2 errors returns حافظ with 3 stars and passed', () {
        final grade = GradeCalculator.calculate(2);

        expect(grade.grade, Grade.hafiz);
        expect(grade.nameAr, 'حافظ');
        expect(grade.nameEn, 'Hafiz');
        expect(grade.stars, 3);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeHafiz);
      });

      test('3 errors returns مجتهد with 2 stars and passed', () {
        final grade = GradeCalculator.calculate(3);

        expect(grade.grade, Grade.mujtahid);
        expect(grade.nameAr, 'مجتهد');
        expect(grade.nameEn, 'Mujtahid');
        expect(grade.stars, 2);
        expect(grade.passed, true);
        expect(grade.color, AppColors.gradeMujtahid);
      });

      test('4 errors returns محب with 1 star and NOT passed', () {
        final grade = GradeCalculator.calculate(4);

        expect(grade.grade, Grade.muhib);
        expect(grade.nameAr, 'محب');
        expect(grade.nameEn, 'Muhib');
        expect(grade.stars, 1);
        expect(grade.passed, false);
        expect(grade.color, AppColors.gradeMuhib);
      });

      test('5 errors returns محب (fail)', () {
        final grade = GradeCalculator.calculate(5);

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('10 errors returns محب (fail)', () {
        final grade = GradeCalculator.calculate(10);

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });
    });

    group('isPassed', () {
      test('returns true for 0 errors', () {
        expect(GradeCalculator.isPassed(0), true);
      });

      test('returns true for 1 error', () {
        expect(GradeCalculator.isPassed(1), true);
      });

      test('returns true for 2 errors', () {
        expect(GradeCalculator.isPassed(2), true);
      });

      test('returns true for 3 errors (boundary)', () {
        expect(GradeCalculator.isPassed(3), true);
      });

      test('returns false for 4 errors (boundary)', () {
        expect(GradeCalculator.isPassed(4), false);
      });

      test('returns false for 5+ errors', () {
        expect(GradeCalculator.isPassed(5), false);
        expect(GradeCalculator.isPassed(10), false);
      });
    });

    group('getStars', () {
      test('returns 5 stars for 0 errors', () {
        expect(GradeCalculator.getStars(0), 5);
      });

      test('returns 4 stars for 1 error', () {
        expect(GradeCalculator.getStars(1), 4);
      });

      test('returns 3 stars for 2 errors', () {
        expect(GradeCalculator.getStars(2), 3);
      });

      test('returns 2 stars for 3 errors', () {
        expect(GradeCalculator.getStars(3), 2);
      });

      test('returns 1 star for 4+ errors', () {
        expect(GradeCalculator.getStars(4), 1);
        expect(GradeCalculator.getStars(10), 1);
      });
    });

    group('getGradeNameAr', () {
      test('returns راسخ for 0 errors', () {
        expect(GradeCalculator.getGradeNameAr(0), 'راسخ');
      });

      test('returns متقن for 1 error', () {
        expect(GradeCalculator.getGradeNameAr(1), 'متقن');
      });

      test('returns حافظ for 2 errors', () {
        expect(GradeCalculator.getGradeNameAr(2), 'حافظ');
      });

      test('returns مجتهد for 3 errors', () {
        expect(GradeCalculator.getGradeNameAr(3), 'مجتهد');
      });

      test('returns محب for 4+ errors', () {
        expect(GradeCalculator.getGradeNameAr(4), 'محب');
      });
    });

    group('getGradeNameEn', () {
      test('returns Rasikh for 0 errors', () {
        expect(GradeCalculator.getGradeNameEn(0), 'Rasikh');
      });

      test('returns Mutqin for 1 error', () {
        expect(GradeCalculator.getGradeNameEn(1), 'Mutqin');
      });

      test('returns Hafiz for 2 errors', () {
        expect(GradeCalculator.getGradeNameEn(2), 'Hafiz');
      });

      test('returns Mujtahid for 3 errors', () {
        expect(GradeCalculator.getGradeNameEn(3), 'Mujtahid');
      });

      test('returns Muhib for 4+ errors', () {
        expect(GradeCalculator.getGradeNameEn(4), 'Muhib');
      });
    });

    group('getGradeColor', () {
      test('returns correct color for each grade', () {
        expect(GradeCalculator.getGradeColor(0), AppColors.gradeRasikh);
        expect(GradeCalculator.getGradeColor(1), AppColors.gradeMutqin);
        expect(GradeCalculator.getGradeColor(2), AppColors.gradeHafiz);
        expect(GradeCalculator.getGradeColor(3), AppColors.gradeMujtahid);
        expect(GradeCalculator.getGradeColor(4), AppColors.gradeMuhib);
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

      test('all parts 3 errors each passes with calculated average', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 3,
          recentReviewErrors: 3,
          distantReviewErrors: 3,
        );

        // Total: 9, Average: 3 (ceiling) = مجتهد
        expect(grade.passed, true);
        expect(grade.grade, Grade.mujtahid);
      });

      test('part1 fails (4 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 4,
          recentReviewErrors: 0,
          distantReviewErrors: 0,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('part2 fails (4 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 4,
          distantReviewErrors: 0,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('part3 fails (4 errors) returns محب', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 4,
        );

        expect(grade.grade, Grade.muhib);
        expect(grade.passed, false);
      });

      test('average calculation with uneven errors', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 1,
          distantReviewErrors: 2,
        );

        // Total: 3, Average: 1 (ceiling) = متقن
        expect(grade.grade, Grade.mutqin);
        expect(grade.passed, true);
      });

      test('ceiling rounding applied correctly', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 1,
          recentReviewErrors: 1,
          distantReviewErrors: 1,
        );

        // Total: 3, Average: 1 (3/3) = متقن
        expect(grade.grade, Grade.mutqin);
      });

      test('ceiling rounds up for non-integer average', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 2,
          recentReviewErrors: 2,
          distantReviewErrors: 2,
        );

        // Total: 6, Average: 2 (6/3) = حافظ
        expect(grade.grade, Grade.hafiz);
      });

      test('mixed low and medium errors averages correctly', () {
        final grade = GradeCalculator.calculateSessionGrade(
          newMemorizationErrors: 0,
          recentReviewErrors: 0,
          distantReviewErrors: 3,
        );

        // Total: 3, Average: 1 (ceiling of 3/3) = متقن
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
