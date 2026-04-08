import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/utils/validators.dart';
import 'package:al_rasikhoon/core/constants/countries.dart';

void main() {
  group('Validators', () {
    group('validatePhone', () {
      group('Saudi Arabia', () {
        final country = Countries.saudiArabia;

        test('rejects empty phone number', () {
          expect(Validators.validatePhone('', country), isNotNull);
          expect(Validators.validatePhone(null, country), isNotNull);
        });

        test('accepts valid 9-digit phone starting with 5', () {
          expect(Validators.validatePhone('512345678', country), isNull);
          expect(Validators.validatePhone('599999999', country), isNull);
        });

        test('removes leading zero and validates', () {
          expect(Validators.validatePhone('0512345678', country), isNull);
        });

        test('removes spaces and dashes', () {
          expect(Validators.validatePhone('512 345 678', country), isNull);
          expect(Validators.validatePhone('512-345-678', country), isNull);
        });

        test('rejects 8-digit phone number', () {
          final result = Validators.validatePhone('51234567', country);
          expect(result, isNotNull);
          expect(result, contains('9'));
        });

        test('rejects 10-digit phone number', () {
          final result = Validators.validatePhone('5123456789', country);
          expect(result, isNotNull);
        });

        test('rejects phone not starting with 5', () {
          expect(Validators.validatePhone('412345678', country), isNotNull);
          expect(Validators.validatePhone('612345678', country), isNotNull);
        });
      });

      group('Egypt', () {
        final country = Countries.egypt;

        test('accepts valid 10-digit phone starting with 1', () {
          expect(Validators.validatePhone('1012345678', country), isNull);
        });

        test('rejects phone not starting with 1', () {
          expect(Validators.validatePhone('2012345678', country), isNotNull);
        });
      });

      group('Kuwait', () {
        final country = Countries.kuwait;

        test('accepts valid 8-digit phone', () {
          expect(Validators.validatePhone('51234567', country), isNull);
          expect(Validators.validatePhone('91234567', country), isNull);
        });
      });
    });

    group('validateSaudiPhone (legacy)', () {
      test('uses Saudi validation', () {
        expect(Validators.validateSaudiPhone('512345678'), isNull);
        expect(Validators.validateSaudiPhone('412345678'), isNotNull);
      });
    });

    group('formatPhoneWithCountryCode', () {
      test('adds Saudi country code', () {
        final result = Validators.formatPhoneWithCountryCode(
          '512345678',
          country: Countries.saudiArabia,
        );
        expect(result, '+966512345678');
      });

      test('removes leading zero before adding code', () {
        final result = Validators.formatPhoneWithCountryCode(
          '0512345678',
          country: Countries.saudiArabia,
        );
        expect(result, '+966512345678');
      });

      test('handles phone with spaces', () {
        final result = Validators.formatPhoneWithCountryCode(
          '512 345 678',
          country: Countries.saudiArabia,
        );
        expect(result, '+966512345678');
      });

      test('uses default country when not specified', () {
        final result = Validators.formatPhoneWithCountryCode('1012345678');
        expect(result, startsWith(Countries.defaultCountry.dialCode));
      });
    });

    group('validateOtp', () {
      test('rejects empty OTP', () {
        expect(Validators.validateOtp(''), isNotNull);
        expect(Validators.validateOtp(null), isNotNull);
      });

      test('accepts exactly 6 digits', () {
        expect(Validators.validateOtp('123456'), isNull);
        expect(Validators.validateOtp('000000'), isNull);
      });

      test('rejects 5 digits', () {
        final result = Validators.validateOtp('12345');
        expect(result, isNotNull);
        expect(result, contains('6'));
      });

      test('rejects 7 digits', () {
        expect(Validators.validateOtp('1234567'), isNotNull);
      });

      test('rejects alphabetic characters', () {
        expect(Validators.validateOtp('12345a'), isNotNull);
        expect(Validators.validateOtp('abcdef'), isNotNull);
      });

      test('rejects special characters', () {
        expect(Validators.validateOtp('12345!'), isNotNull);
        expect(Validators.validateOtp('123-45'), isNotNull);
      });
    });

    group('validateName', () {
      test('rejects empty name', () {
        expect(Validators.validateName(''), isNotNull);
        expect(Validators.validateName(null), isNotNull);
      });

      test('rejects single character name', () {
        expect(Validators.validateName('أ'), isNotNull);
        expect(Validators.validateName('A'), isNotNull);
      });

      test('accepts 2 character name', () {
        expect(Validators.validateName('علي'), isNull);
        expect(Validators.validateName('Jo'), isNull);
      });

      test('accepts Arabic names', () {
        expect(Validators.validateName('محمد أحمد'), isNull);
        expect(Validators.validateName('عبدالله'), isNull);
      });

      test('accepts English names', () {
        expect(Validators.validateName('John Doe'), isNull);
        expect(Validators.validateName('Ahmed'), isNull);
      });

      test('rejects names over 100 characters', () {
        final longName = 'a' * 101;
        expect(Validators.validateName(longName), isNotNull);
      });

      test('accepts name of exactly 100 characters', () {
        final maxName = 'a' * 100;
        expect(Validators.validateName(maxName), isNull);
      });
    });

    group('validateInstituteName', () {
      test('rejects empty name', () {
        expect(Validators.validateInstituteName(''), isNotNull);
        expect(Validators.validateInstituteName(null), isNotNull);
      });

      test('rejects 2 character name', () {
        expect(Validators.validateInstituteName('AB'), isNotNull);
      });

      test('accepts 3 character name', () {
        expect(Validators.validateInstituteName('معهد'), isNull);
      });

      test('rejects names over 200 characters', () {
        final longName = 'a' * 201;
        expect(Validators.validateInstituteName(longName), isNotNull);
      });
    });

    group('validateLocation', () {
      test('rejects empty location', () {
        expect(Validators.validateLocation(''), isNotNull);
        expect(Validators.validateLocation(null), isNotNull);
      });

      test('rejects single character location', () {
        expect(Validators.validateLocation('A'), isNotNull);
      });

      test('accepts 2 character location', () {
        expect(Validators.validateLocation('UK'), isNull);
      });
    });

    group('validateErrorCount', () {
      test('rejects empty input', () {
        expect(Validators.validateErrorCount(''), isNotNull);
        expect(Validators.validateErrorCount(null), isNotNull);
      });

      test('accepts 0 errors', () {
        expect(Validators.validateErrorCount('0'), isNull);
      });

      test('accepts positive integers', () {
        expect(Validators.validateErrorCount('1'), isNull);
        expect(Validators.validateErrorCount('5'), isNull);
        expect(Validators.validateErrorCount('100'), isNull);
      });

      test('rejects negative numbers', () {
        expect(Validators.validateErrorCount('-1'), isNotNull);
        expect(Validators.validateErrorCount('-5'), isNotNull);
      });

      test('rejects non-numeric input', () {
        expect(Validators.validateErrorCount('abc'), isNotNull);
        expect(Validators.validateErrorCount('1.5'), isNotNull);
      });
    });

    group('validateNotes', () {
      test('accepts empty notes (optional field)', () {
        expect(Validators.validateNotes(''), isNull);
        expect(Validators.validateNotes(null), isNull);
      });

      test('accepts notes up to 500 characters', () {
        final notes = 'a' * 500;
        expect(Validators.validateNotes(notes), isNull);
      });

      test('rejects notes over 500 characters', () {
        final longNotes = 'a' * 501;
        expect(Validators.validateNotes(longNotes), isNotNull);
      });
    });

    group('validateEmail', () {
      test('rejects empty email', () {
        expect(Validators.validateEmail(''), isNotNull);
        expect(Validators.validateEmail(null), isNotNull);
      });

      test('accepts valid emails', () {
        expect(Validators.validateEmail('user@example.com'), isNull);
        expect(Validators.validateEmail('test.name@domain.co'), isNull);
        expect(Validators.validateEmail('user+tag@example.org'), isNull);
      });

      test('rejects emails without @', () {
        expect(Validators.validateEmail('userexample.com'), isNotNull);
      });

      test('rejects emails without domain', () {
        expect(Validators.validateEmail('user@'), isNotNull);
      });

      test('rejects emails without TLD', () {
        expect(Validators.validateEmail('user@domain'), isNotNull);
      });

      test('rejects emails with spaces', () {
        expect(Validators.validateEmail('user @example.com'), isNotNull);
      });
    });

    group('validatePassword', () {
      test('rejects empty password', () {
        expect(Validators.validatePassword(''), isNotNull);
        expect(Validators.validatePassword(null), isNotNull);
      });

      test('rejects password shorter than 6 characters', () {
        expect(Validators.validatePassword('12345'), isNotNull);
        expect(Validators.validatePassword('abc'), isNotNull);
      });

      test('accepts password of exactly 6 characters', () {
        expect(Validators.validatePassword('123456'), isNull);
      });

      test('accepts long passwords', () {
        expect(Validators.validatePassword('a' * 100), isNull);
      });
    });

    group('validateConfirmPassword', () {
      test('rejects empty confirmation', () {
        expect(Validators.validateConfirmPassword('', 'password'), isNotNull);
        expect(Validators.validateConfirmPassword(null, 'password'), isNotNull);
      });

      test('rejects non-matching passwords', () {
        expect(
            Validators.validateConfirmPassword('different', 'password'), isNotNull);
      });

      test('accepts matching passwords', () {
        expect(
            Validators.validateConfirmPassword('password', 'password'), isNull);
      });
    });

    group('validateOptionalPhone', () {
      test('accepts null or empty (optional)', () {
        final country = Countries.saudiArabia;
        expect(Validators.validateOptionalPhone(null, country), isNull);
        expect(Validators.validateOptionalPhone('', country), isNull);
      });

      test('validates phone when provided', () {
        final country = Countries.saudiArabia;
        expect(Validators.validateOptionalPhone('512345678', country), isNull);
        expect(Validators.validateOptionalPhone('123', country), isNotNull);
      });
    });
  });
}
