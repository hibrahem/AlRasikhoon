import 'providers/teacher_provider.dart';

/// The Arabic label for a recitation part: 1 = new memorization, 2 = recent
/// review, 3 = distant review. Shared by the recitation, result and summary
/// screens so the three never drift apart.
String recitationPartTitleAr(int part) {
  switch (part) {
    case 1:
      return 'الحفظ الجديد';
    case 2:
      return 'المراجعة القريبة';
    case 3:
      return 'المراجعة البعيدة';
    default:
      return 'التسميع';
  }
}

/// The error count [session] recorded for [part].
int recitationPartErrors(ActiveSessionState session, int part) {
  switch (part) {
    case 1:
      return session.part1Errors;
    case 2:
      return session.part2Errors;
    case 3:
      return session.part3Errors;
    default:
      return 0;
  }
}
