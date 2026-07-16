import 'package:flutter/material.dart';

import '../../domain/curriculum/paced_session.dart';

/// How the app SPEAKS about a recitation part — label, icon and content —
/// shared by every screen that shows one (teacher grading flow, student
/// session detail, the shared progress view), so they can never drift.
///
/// Parts: 1 = الحفظ الجديد (new memorization), 2 = المراجعة القريبة (recent
/// review), 3 = المراجعة البعيدة (distant review).

/// The Arabic label for a recitation part.
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

/// The icon for a recitation part — the non-color signal that accompanies
/// the part ink ([AppTokens.forPart]) everywhere a part is shown, so the
/// mode is never communicated by hue alone: an open book for new
/// memorization, a turning-back clock for the recent review, an hourglass
/// for the distant one.
IconData recitationPartIcon(int part) {
  switch (part) {
    case 1:
      return Icons.auto_stories;
    case 2:
      return Icons.history;
    case 3:
      return Icons.hourglass_bottom;
    default:
      return Icons.menu_book;
  }
}

/// The passage the student recited for [part] in [meeting] — the surah/ayah
/// range of the matching content stream. Empty when the meeting is unknown
/// or that stream carries no content, so screens can hide the line rather
/// than show a blank range.
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
