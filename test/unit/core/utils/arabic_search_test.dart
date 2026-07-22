import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/core/utils/arabic_search.dart';

void main() {
  group('normalizeArabic', () {
    test('folds hamza forms onto bare alef', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إبراهيم'), 'ابراهيم');
      expect(normalizeArabic('آمنة'), 'امنه');
      expect(normalizeArabic('ٱلرحمن'), 'الرحمن');
    });

    test('folds taa marbuta onto haa', () {
      expect(normalizeArabic('فاطمة'), 'فاطمه');
    });

    test('folds alef maqsura onto yaa', () {
      expect(normalizeArabic('هدى'), 'هدي');
      expect(normalizeArabic('مصطفى'), 'مصطفي');
    });

    test('strips diacritics and tatweel', () {
      expect(normalizeArabic('مُحَمَّد'), 'محمد');
      expect(normalizeArabic('محـــمد'), 'محمد');
    });

    test('lowercases Latin text', () {
      expect(normalizeArabic('Ahmad'), 'ahmad');
    });

    test('collapses and trims whitespace', () {
      expect(normalizeArabic('  عبد   الله '), 'عبد الله');
    });
  });

  group('matchesSearch', () {
    test('empty and blank queries match everything', () {
      expect(matchesSearch('', ['أحمد']), isTrue);
      expect(matchesSearch('   ', ['أحمد']), isTrue);
    });

    test('hamza-variant query matches stored spelling and vice versa', () {
      expect(matchesSearch('احمد', ['أحمد علي']), isTrue);
      expect(matchesSearch('أحمد', ['احمد علي']), isTrue);
      expect(matchesSearch('هدي', ['هدى']), isTrue);
    });

    test('matches a phone-digit substring', () {
      expect(matchesSearch('0501', ['أحمد', '0501234567']), isTrue);
    });

    test('matches Latin usernames case-insensitively', () {
      expect(matchesSearch('TEACH', ['teacher_1']), isTrue);
    });

    test('skips null fields', () {
      expect(matchesSearch('احمد', [null, 'أحمد']), isTrue);
      expect(matchesSearch('احمد', [null]), isFalse);
    });

    test('returns false when nothing matches', () {
      expect(matchesSearch('خالد', ['أحمد', '0501234567']), isFalse);
    });
  });
}
