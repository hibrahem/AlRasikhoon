import '../../domain/curriculum/paced_session.dart';
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

/// The passage the student recited for [part] in [meeting] — the surah/ayah
/// range of the matching content stream (1 = new memorization, 2 = recent
/// review, 3 = distant review). Empty when the meeting is unknown or that
/// stream carries no content, so screens can hide the line rather than show a
/// blank range.
String recitationPartContentAr(PacedSession? meeting, int part) {
  if (meeting == null) return '';
  switch (part) {
    case 1:
      return meeting.newContentAr;
    case 2:
      return meeting.recentReviewAr;
    case 3:
      return meeting.distantReviewAr;
    default:
      return '';
  }
}
