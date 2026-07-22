import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/student/student_status.dart';

void main() {
  group('StudentStatus', () {
    test('persists as the snake-case wire values active/excluded', () {
      expect(StudentStatus.active.value, 'active');
      expect(StudentStatus.excluded.value, 'excluded');
    });

    test('every status round-trips through its wire value', () {
      for (final status in StudentStatus.values) {
        expect(StudentStatusX.fromString(status.value), status);
      }
    });

    test('a student document without a status reads as active', () {
      expect(StudentStatusX.fromString(null), StudentStatus.active);
    });

    test('an unknown status value reads as active rather than crashing', () {
      // A newer app version may write a state (e.g. paused) this version
      // does not know; the safe reading is "not excluded".
      expect(StudentStatusX.fromString('paused'), StudentStatus.active);
      expect(StudentStatusX.fromString(''), StudentStatus.active);
    });

    test('carries the Arabic labels the UI shows', () {
      expect(StudentStatus.active.labelAr, 'نشط');
      expect(StudentStatus.excluded.labelAr, 'مستبعد');
    });
  });
}
