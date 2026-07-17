import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';

void main() {
  group('CurriculumPace', () {
    test('the standard pace is one session per meeting', () {
      expect(CurriculumPace.standard.multiplier, 1);
      expect(CurriculumPace.standard.isStandard, isTrue);
    });

    test('a doubled pace is not the standard pace', () {
      final doubled = CurriculumPace(2);
      expect(doubled.multiplier, 2);
      expect(doubled.isStandard, isFalse);
    });

    test('a pace below one is not a pace', () {
      expect(() => CurriculumPace(0), throwsArgumentError);
      expect(() => CurriculumPace(-1), throwsArgumentError);
    });

    test('a pace above the ceiling is not a pace', () {
      expect(CurriculumPace(CurriculumPace.maxMultiplier).multiplier, 10);
      expect(
        () => CurriculumPace(CurriculumPace.maxMultiplier + 1),
        throwsArgumentError,
      );
      expect(() => CurriculumPace.fromJson(99), throwsArgumentError);
    });

    test('a student with no stored pace reads back as the standard pace', () {
      expect(CurriculumPace.fromJson(null), CurriculumPace.standard);
    });

    test('a stored pace reads back as itself', () {
      expect(CurriculumPace.fromJson(3), CurriculumPace(3));
      expect(CurriculumPace(3).toJson(), 3);
    });

    test('a corrupted stored pace surfaces rather than defaulting', () {
      expect(() => CurriculumPace.fromJson(0), throwsArgumentError);
      expect(() => CurriculumPace.fromJson('two'), throwsArgumentError);
    });

    test('two paces of the same multiplier are the same pace', () {
      expect(CurriculumPace(2), CurriculumPace(2));
      expect(CurriculumPace(2).hashCode, CurriculumPace(2).hashCode);
      expect(CurriculumPace(2), isNot(CurriculumPace(3)));
    });
  });
}
