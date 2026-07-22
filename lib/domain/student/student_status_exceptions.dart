/// Business-rule violation raised when someone who is neither an admin nor a
/// supervisor of the student's institute tries to change the student's
/// teaching status (al_rasikhoon-zg1r).
///
/// The invariant is enforced in [StudentRepository.setStudentStatus] — the
/// authoritative path — because a stale UI must not be trusted to have
/// checked, mirroring [RepositionNotAuthorizedException].
class StudentStatusChangeNotAuthorizedException implements Exception {
  final String reason;

  const StudentStatusChangeNotAuthorizedException(this.reason);

  @override
  String toString() => 'StudentStatusChangeNotAuthorizedException: $reason';
}
