import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/pii_scrubber.dart';

void main() {
  group('scrubMessage', () {
    test('redacts the synthetic login email', () {
      const input =
          'FirebaseAuthException: no user for ahmad.ali@alrasikhoon.local';
      expect(scrubMessage(input), isNot(contains('ahmad.ali')));
      expect(scrubMessage(input), contains('<redacted>@alrasikhoon.local'));
    });

    test('templates document ids embedded in firestore paths', () {
      const input =
          'PERMISSION_DENIED on students/aB3xY9kL2mN7pQ4rS8tU/sessions';
      expect(scrubMessage(input), contains('students/:id/sessions'));
      expect(scrubMessage(input), isNot(contains('aB3xY9kL2mN7pQ4rS8tU')));
    });

    test('leaves ordinary error messages intact', () {
      const input = 'Network request failed after 3 retries';
      expect(scrubMessage(input), input);
    });

    test('redacts a digit-free firestore id embedded in a path', () {
      const input =
          'PERMISSION_DENIED on students/qRstUVwXYZabcdefghij/sessions';
      expect(scrubMessage(input), contains('students/:id/sessions'));
      expect(scrubMessage(input), isNot(contains('qRstUVwXYZabcdefghij')));
    });
  });

  group('templateRoute', () {
    test('replaces a student id with a placeholder', () {
      expect(templateRoute('/students/aB3xY9kL2mN7pQ4rS8tU'), '/students/:id');
    });

    test('replaces a uuid segment with a placeholder', () {
      expect(
        templateRoute('/sessions/3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
        '/sessions/:id',
      );
    });

    test('preserves a hyphenated route name that is not an id', () {
      expect(templateRoute('/account-not-found'), '/account-not-found');
    });

    test('preserves a nested static route', () {
      expect(templateRoute('/admin/institutes'), '/admin/institutes');
    });

    test('templates a digit-free firestore-style student id', () {
      expect(templateRoute('/students/qRstUVwXYZabcdefghij'), '/students/:id');
    });

    test('preserves a hyphenated segment of 16 or more characters', () {
      expect(templateRoute('/account-not-found'), '/account-not-found');
    });
  });

  group('buckets', () {
    test('maps a recitation error count to its expected range', () {
      expect(errorsBucket(0), '0');
      expect(errorsBucket(3), '1-3');
      expect(errorsBucket(4), '4-10');
      expect(errorsBucket(11), '10+');
    });

    test('maps a session duration to its expected range', () {
      expect(durationBucket(const Duration(minutes: 4)), '<5m');
      expect(durationBucket(const Duration(minutes: 15)), '5-15m');
      expect(durationBucket(const Duration(minutes: 29)), '15-30m');
      expect(durationBucket(const Duration(minutes: 31)), '30m+');
    });

    test('maps a pending write count to its expected range', () {
      expect(pendingBucket(1), '1');
      expect(pendingBucket(5), '2-5');
      expect(pendingBucket(20), '6-20');
      expect(pendingBucket(21), '20+');
    });
  });
}
