import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/recitation_parts.dart';

void main() {
  test('recitationPartTitleAr maps each part to its Arabic label', () {
    expect(recitationPartTitleAr(1), 'الحفظ الجديد');
    expect(recitationPartTitleAr(2), 'المراجعة القريبة');
    expect(recitationPartTitleAr(3), 'المراجعة البعيدة');
    expect(recitationPartTitleAr(9), 'التسميع');
  });

  test('recitationPartErrors reads the matching per-part error count', () {
    const session = ActiveSessionState(
      studentId: 's1',
      part1Errors: 4,
      part2Errors: 2,
      part3Errors: 7,
    );
    expect(recitationPartErrors(session, 1), 4);
    expect(recitationPartErrors(session, 2), 2);
    expect(recitationPartErrors(session, 3), 7);
    expect(recitationPartErrors(session, 9), 0);
  });
}
