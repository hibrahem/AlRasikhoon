/// The student's TEACHING status (al_rasikhoon-zg1r) — orthogonal to the
/// `is_active` soft-delete flag, which means "this record exists at all".
///
/// - [active] (نشط): the normal state; the student appears in their teacher's
///   lists and queues.
/// - [excluded] (مستبعد): a supervisor or admin has stopped the student from
///   being taught. The student vanishes from every teacher-facing list but
///   stays visible — badged — to supervisors and admins, who may restore them
///   at any time. The student keeps their teacher assignment and their own
///   app access; exclusion hides, it does not detach.
///
/// Designed to grow: a future state (e.g. paused) is one more enum case, and
/// [StudentStatusX.fromString] already reads any value this version does not
/// know as [active] — "not excluded" is the only safe guess for an unknown
/// state written by a newer app.
enum StudentStatus { active, excluded }

extension StudentStatusX on StudentStatus {
  /// The snake-case wire value persisted in the student document's `status`
  /// field.
  String get value {
    switch (this) {
      case StudentStatus.active:
        return 'active';
      case StudentStatus.excluded:
        return 'excluded';
    }
  }

  String get labelAr {
    switch (this) {
      case StudentStatus.active:
        return 'نشط';
      case StudentStatus.excluded:
        return 'مستبعد';
    }
  }

  String get labelEn {
    switch (this) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.excluded:
        return 'Excluded';
    }
  }

  /// Reads a stored status. Null (legacy documents predate the field) and
  /// unknown values (written by a newer app version) both read as [active]:
  /// hiding a student from their teacher is an explicit act, never a guess —
  /// mirrors how a missing `curriculum_completed` reads as "not graduated".
  static StudentStatus fromString(String? value) {
    switch (value) {
      case 'excluded':
        return StudentStatus.excluded;
      default:
        return StudentStatus.active;
    }
  }
}
