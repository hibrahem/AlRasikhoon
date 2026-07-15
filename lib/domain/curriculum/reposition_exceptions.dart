/// Business-rule violations raised when a supervisor tries to move an enrolled
/// student's starting point (al_rasikhoon-sne).
///
/// Moving the enrollment anchor is only safe while the student has NOT started —
/// zero progress records of any kind — because with no history to orphan the
/// move is a pure re-derivation. These exceptions name the two invariants that
/// make the move safe, so the authoritative repository path can reject a move
/// for a precise, testable reason rather than a bare [ArgumentError]. They exist
/// because the invariant they guard (zero records across three collections)
/// cannot be expressed in a Firestore security rule — the app layer is the
/// enforcement point.
library;

/// The student has already started — at least one session, سرد or اختبار record
/// exists — so their enrollment anchor can no longer be moved: doing so would
/// re-derive a position that contradicts recorded history. Thrown by the
/// authoritative reposition path even when the UI believed the student had not
/// started (a stale screen must not move a student who started in the meantime).
class StudentAlreadyStartedException implements Exception {
  final String studentId;

  const StudentAlreadyStartedException(this.studentId);

  @override
  String toString() =>
      'StudentAlreadyStartedException: student $studentId has progress '
      'records, so their starting point can no longer be moved';
}

/// The caller is not a supervisor of the student's institute. Only a supervisor
/// scoped to the student's own institute may move an enrollment anchor; a
/// teacher, a guardian, or a supervisor of another institute is rejected.
class RepositionNotAuthorizedException implements Exception {
  final String reason;

  const RepositionNotAuthorizedException(this.reason);

  @override
  String toString() => 'RepositionNotAuthorizedException: $reason';
}
