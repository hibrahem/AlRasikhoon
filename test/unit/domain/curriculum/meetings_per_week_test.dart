import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/meetings_per_week.dart';

void main() {
  group('MeetingsPerWeek', () {
    test('the standard cadence is two meetings a week', () {
      expect(MeetingsPerWeek.standard.count, 2);
    });

    test('a cadence below one meeting a week is not a cadence', () {
      expect(() => MeetingsPerWeek(0), throwsArgumentError);
      expect(() => MeetingsPerWeek(-1), throwsArgumentError);
    });

    test('a week holds at most seven meetings', () {
      expect(MeetingsPerWeek(7).count, 7);
      expect(() => MeetingsPerWeek(8), throwsArgumentError);
    });

    test('a student with no stored cadence reads back as the standard', () {
      expect(MeetingsPerWeek.fromJson(null), MeetingsPerWeek.standard);
    });

    test('a stored cadence reads back as itself', () {
      expect(MeetingsPerWeek.fromJson(3), MeetingsPerWeek(3));
      expect(MeetingsPerWeek(3).toJson(), 3);
    });

    test('a corrupted stored cadence surfaces rather than defaulting', () {
      expect(() => MeetingsPerWeek.fromJson(0), throwsArgumentError);
      expect(() => MeetingsPerWeek.fromJson(9), throwsArgumentError);
      expect(() => MeetingsPerWeek.fromJson('two'), throwsArgumentError);
    });

    test('two cadences of the same count are the same cadence', () {
      expect(MeetingsPerWeek(3), MeetingsPerWeek(3));
      expect(MeetingsPerWeek(3).hashCode, MeetingsPerWeek(3).hashCode);
      expect(MeetingsPerWeek(3), isNot(MeetingsPerWeek(4)));
    });
  });
}
