// The part label/icon/content helpers moved to the shared kernel
// (lib/shared/curriculum/recitation_part_copy.dart) so student- and
// shared-layer screens can use them too; this module re-exports them for
// the teacher screens and keeps the one helper that is teacher-only
// (it reads the teacher's active-session state).
export '../../shared/curriculum/recitation_part_copy.dart';

import 'providers/teacher_provider.dart';

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
