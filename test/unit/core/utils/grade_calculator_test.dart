import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/utils/grade_calculator.dart';

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
      });

      // متقن: 1-2 errors
      test('1 error returns متقن with 4 stars and passed', () {
        final grade = GradeCalculator.calculate(1);

        expect(grade.grade, Grade.mutqin);
        expect(grade.nameAr, 'متقن');
        expect(grade.nameEn, 'Mutqin');
        expect(grade.stars, 4);
        expect(grade.passed, true);
      });

      test('2 errors returns متقن with 4 stars and passed', () {
        final grade = GradeCalculator.calculate(2);

        expect(grade.grade, Grade.mutqin);
        expect(grade.nameAr, 'متقن');
        expect(grade.nameEn, 'Mutqin');
        expect(grade.stars, 4);
        expect(grade.passed, true);
      });

      // حافظ: 3-4 errors
      test('3 errors returns حافظ with 3 stars and passed', () {
        final grade = GradeCalculator.calculate(3);

        expect(grade.grade, Grade.hafiz);
        expect(grade.nameAr, 'حافظ');
        expect(grade.nameEn, 'Hafiz');
        expect(grade.stars, 3);
        expect(grade.passed, true);
      });

      test('4 errors returns حافظ with 3 stars and passed', () {
        final grade = GradeCalculator.calculate(4);

        expect(grade.grade, Grade.hafiz);
        expect(grade.nameAr, 'حافظ');
        expect(grade.nameEn, 'Hafiz');
        expect(grade.stars, 3);
        expect(grade.passed, true);
      });

      // مجتهد: 5-6 errors
      test('5 errors returns مجتهد with 2 stars and passed', () {
        final grade = GradeCalculator.calculate(5);

        expect(grade.grade, Grade.mujtahid);
        expect(grade.nameAr, 'مجتهد');
        expect(grade.nameEn, 'Mujtahid');
        expect(grade.stars, 2);
        expect(grade.passed, true);
      });

      test('6 errors returns مجتهد with 2 stars and passed', () {
        final grade = GradeCalculator.calculate(6);

        expect(grade.grade, Grade.mujtahid);
        expect(grade.nameAr, 'مجتهد');
        expect(grade.nameEn, 'Mujtahid');
        expect(grade.stars, 2);
        expect(grade.passed, true);
      });

      // محب: 7+ errors (fail)
      test('7 errors returns محب with 1 star and NOT passed', () {
        final grade = GradeCalculator.calculate(7);

        expect(grade.grade, Grade.muhib);
        expect(grade.nameAr, 'محب');
        expect(grade.nameEn, 'Muhib');
        expect(grade.stars, 1);
        expect(grade.passed, false);
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

    // Session-level aggregation (hibrahem/AlRasikhoon#24): a session is
    // FAILED if ANY one component (new/near/far) grades محب (ويعاد); it
    // passes only if none is محب. NO averaging — a single محب can never be
    // masked by good grades. Component grades are level-based (#22): at
    // level 1 (B = 0), محب starts at 4 mistakes and مجتهد is exactly 3.
    group('sessionPassesForLevel (any-محب fail rule — issue #24)', () {
      test('passes when all parts are راسخ (0 errors)', () {
        expect(
          GradeCalculator.sessionPassesForLevel(
            level: 1,
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          ),
          true,
        );
      });

      test(
        'passes when worst non-محب grade is مجتهد (3 errors at level 1)',
        () {
          expect(
            GradeCalculator.sessionPassesForLevel(
              level: 1,
              newMemorizationErrors: 3,
              recentReviewErrors: 3,
              distantReviewErrors: 3,
            ),
            true,
          );
        },
      );

      test(
        'FAILS when NEW (الجديد) is محب — even with راسخ/متقن elsewhere',
        () {
          // Repro from the issue: new = محب (4 @ L1), near = متقن (1),
          // far = راسخ (0). Averaging would have masked the محب; any-محب fails.
          expect(
            GradeCalculator.sessionPassesForLevel(
              level: 1,
              newMemorizationErrors: 4,
              recentReviewErrors: 1,
              distantReviewErrors: 0,
            ),
            false,
          );
        },
      );

      test('FAILS when NEAR (القريب) is محب — masked by good others', () {
        expect(
          GradeCalculator.sessionPassesForLevel(
            level: 1,
            newMemorizationErrors: 0,
            recentReviewErrors: 4,
            distantReviewErrors: 1,
          ),
          false,
        );
      });

      test(
        'FAILS when FAR (البعيد) is محب — the issue repro (راسخ/متقن/محب)',
        () {
          // new = راسخ (0), near = متقن (1), far = محب (4 @ L1).
          expect(
            GradeCalculator.sessionPassesForLevel(
              level: 1,
              newMemorizationErrors: 0,
              recentReviewErrors: 1,
              distantReviewErrors: 4,
            ),
            false,
          );
        },
      );

      test('respects level — same 4 errors is NOT محب at a high level', () {
        // Level 9: B = 4, محب only at >= 8 mistakes; 4 errors → راسخ.
        expect(
          GradeCalculator.sessionPassesForLevel(
            level: 9,
            newMemorizationErrors: 4,
            recentReviewErrors: 4,
            distantReviewErrors: 4,
          ),
          true,
        );
      });
    });

    group(
      'calculateSessionGrade (worst-component, no averaging — issue #24)',
      () {
        test('all parts راسخ returns راسخ and passes', () {
          final grade = GradeCalculator.calculateSessionGrade(
            level: 1,
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          );

          expect(grade.grade, Grade.rasikh);
          expect(grade.passed, true);
        });

        test('returns the WORST component grade, never an average', () {
          // new = راسخ (0), near = راسخ (0), far = مجتهد (3 @ L1).
          // Old averaging gave متقن (ceil(3/3)=1); worst-component gives مجتهد.
          final grade = GradeCalculator.calculateSessionGrade(
            level: 1,
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 3,
          );

          expect(grade.grade, Grade.mujtahid);
          expect(grade.passed, true);
        });

        test('returns محب (failed) when any single part is محب', () {
          final grade = GradeCalculator.calculateSessionGrade(
            level: 1,
            newMemorizationErrors: 0,
            recentReviewErrors: 0,
            distantReviewErrors: 4,
          );

          expect(grade.grade, Grade.muhib);
          expect(grade.passed, false);
        });

        test('a single محب is never masked by راسخ in the other two parts', () {
          final grade = GradeCalculator.calculateSessionGrade(
            level: 1,
            newMemorizationErrors: 4,
            recentReviewErrors: 0,
            distantReviewErrors: 0,
          );

          expect(grade.grade, Grade.muhib);
          expect(grade.passed, false);
        });
      },
    );

    group('calculateForLevel (level-based grading — issue #22)', () {
      // Exhaustive per-level-pair threshold table. B = (level - 1) ~/ 2.
      // mistakes <= B → راسخ ; == B+1 → متقن ; == B+2 → حافظ ;
      // == B+3 → مجتهد ; >= B+4 → محب (must repeat / fail).
      //
      // Each tuple: (levels sharing this base, base B).
      const levelPairs = <List<int>>[
        [1, 2], // B = 0
        [3, 4], // B = 1
        [5, 6], // B = 2
        [7, 8], // B = 3
        [9, 10], // B = 4
      ];

      for (final pair in levelPairs) {
        final base = (pair.first - 1) ~/ 2;

        for (final level in pair) {
          group('level $level (base B=$base)', () {
            test('mistakes == B ($base) → راسخ (top grade)', () {
              final g = GradeCalculator.calculateForLevel(level, base);
              expect(g.grade, Grade.rasikh);
              expect(g.nameAr, 'راسخ');
              expect(g.stars, 5);
              expect(g.passed, true);
            });

            test('mistakes == B+1 (${base + 1}) → متقن', () {
              final g = GradeCalculator.calculateForLevel(level, base + 1);
              expect(g.grade, Grade.mutqin);
              expect(g.nameAr, 'متقن');
              expect(g.passed, true);
            });

            test('mistakes == B+2 (${base + 2}) → حافظ', () {
              final g = GradeCalculator.calculateForLevel(level, base + 2);
              expect(g.grade, Grade.hafiz);
              expect(g.nameAr, 'حافظ');
              expect(g.passed, true);
            });

            test('mistakes == B+3 (${base + 3}) → مجتهد', () {
              final g = GradeCalculator.calculateForLevel(level, base + 3);
              expect(g.grade, Grade.mujtahid);
              expect(g.nameAr, 'مجتهد');
              expect(g.passed, true);
            });

            test(
              'mistakes == B+4 (${base + 4}) → محب (must repeat / fail)',
              () {
                final g = GradeCalculator.calculateForLevel(level, base + 4);
                expect(g.grade, Grade.muhib);
                expect(g.nameAr, 'محب');
                expect(g.passed, false);
              },
            );

            // ≤B boundary: 0 mistakes is always راسخ (even when B > 0).
            test('mistakes 0 (<= B) → راسخ', () {
              expect(
                GradeCalculator.calculateForLevel(level, 0).grade,
                Grade.rasikh,
              );
            });

            // ≥B+4 boundary: anything well above B+4 stays محب.
            test('mistakes B+10 (>= B+4) → محب', () {
              expect(
                GradeCalculator.calculateForLevel(level, base + 10).grade,
                Grade.muhib,
              );
            });
          });
        }
      }

      group('issue #22 repro examples', () {
        test('level 1 with 2 mistakes → حافظ', () {
          expect(GradeCalculator.calculateForLevel(1, 2).grade, Grade.hafiz);
        });

        test('level 9 with 2 mistakes → راسخ', () {
          expect(GradeCalculator.calculateForLevel(9, 2).grade, Grade.rasikh);
        });

        test('same mistake count yields different grades across levels', () {
          final atLevel1 = GradeCalculator.calculateForLevel(1, 2).grade;
          final atLevel9 = GradeCalculator.calculateForLevel(9, 2).grade;
          expect(atLevel1, isNot(atLevel9));
        });
      });

      group('input clamping / defensive bounds', () {
        test('level below 1 is treated as level 1 (B=0)', () {
          expect(
            GradeCalculator.calculateForLevel(0, 0).grade,
            GradeCalculator.calculateForLevel(1, 0).grade,
          );
          expect(
            GradeCalculator.calculateForLevel(-5, 3).grade,
            GradeCalculator.calculateForLevel(1, 3).grade,
          );
        });

        test('level above 10 is treated as level 10 (B=4)', () {
          expect(
            GradeCalculator.calculateForLevel(99, 4).grade,
            GradeCalculator.calculateForLevel(10, 4).grade,
          );
        });

        test('negative mistakes treated as 0 → راسخ', () {
          expect(GradeCalculator.calculateForLevel(1, -3).grade, Grade.rasikh);
        });
      });

      group('gradeForLevel (pure enum mapping)', () {
        test('matches calculateForLevel grade', () {
          expect(
            GradeCalculator.gradeForLevel(5, 4),
            GradeCalculator.calculateForLevel(5, 4).grade,
          );
        });
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
