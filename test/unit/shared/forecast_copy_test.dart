import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/curriculum/forecast_copy.dart';

/// Arabic number agreement is a grammar, not a suffix: singular, dual, the
/// 3-10 plural and the 11+ singular accusative each read differently, and a
/// forecast that says "2 أسبوع" reads broken to every parent it is meant to
/// motivate.
void main() {
  group('weeksAr', () {
    test('singular, dual, small plural, large count', () {
      expect(weeksAr(1), 'أسبوع واحد');
      expect(weeksAr(2), 'أسبوعان');
      expect(weeksAr(3), '3 أسابيع');
      expect(weeksAr(10), '10 أسابيع');
      expect(weeksAr(11), '11 أسبوعًا');
      expect(weeksAr(58), '58 أسبوعًا');
    });
  });

  group('meetingsAr', () {
    test('singular, dual, small plural, large count', () {
      expect(meetingsAr(1), 'لقاء واحد');
      expect(meetingsAr(2), 'لقاءان');
      expect(meetingsAr(7), '7 لقاءات');
      expect(meetingsAr(120), '120 لقاءً');
    });
  });

  group('approxDurationAr', () {
    test('short spans stay in weeks', () {
      expect(approxDurationAr(1), 'أسبوع واحد');
      expect(approxDurationAr(4), '4 أسابيع');
    });

    test('spans of months read in months', () {
      expect(approxDurationAr(9), 'شهران');
      expect(approxDurationAr(22), '5 أشهر');
    });

    test('spans of years read in years and months', () {
      expect(approxDurationAr(52), 'سنة');
      expect(approxDurationAr(65), 'سنة و3 أشهر');
      expect(approxDurationAr(104), 'سنتان');
      expect(approxDurationAr(156), '3 سنوات');
    });
  });
}
