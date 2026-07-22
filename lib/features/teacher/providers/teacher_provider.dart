import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/models/session_model.dart';
import '../../../data/models/session_record_model.dart';
import '../../../domain/session/student_history_entry.dart';
import '../../../core/utils/grade_calculator.dart';
import '../../../domain/curriculum/paced_session.dart';
import '../../../shared/providers/search_query_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/providers/meeting_provider.dart'
    show composeMeetingFor, composeNextMeetingAfter;

/// Provider for teacher's students
final teacherStudentsProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsForTeacher(currentUser.id);
});

/// Selected institute id to filter the teacher's students view.
/// `null` means "all institutes".
class SelectedTeacherInstituteFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? instituteId) => state = instituteId;
}

final selectedTeacherInstituteFilterProvider =
    NotifierProvider<SelectedTeacherInstituteFilter, String?>(
      SelectedTeacherInstituteFilter.new,
    );

/// Query text for the teacher's students search field. Composes with the
/// institute dropdown filter — both apply.
final teacherStudentsSearchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

/// Teacher's students filtered by the selected institute filter.
final filteredTeacherStudentsProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final all = await ref.watch(teacherStudentsProvider.future);
  final filter = ref.watch(selectedTeacherInstituteFilterProvider);
  if (filter == null) return all;
  return all
      .where((s) => s.student.instituteId == filter)
      .toList(growable: false);
});

/// Provider for a specific student
final studentProvider = FutureProvider.family<StudentWithUser?, String>((
  ref,
  studentId,
) async {
  final students = await ref.watch(teacherStudentsProvider.future);
  return students.firstWhere(
    (s) => s.student.id == studentId,
    orElse: () => throw Exception('Student not found'),
  );
});

/// Provider for student's current session data
final studentCurrentSessionProvider =
    FutureProvider.family<SessionModel?, String>((ref, studentId) async {
      final studentAsync = await ref.watch(studentProvider(studentId).future);
      if (studentAsync == null) return null;

      final student = studentAsync.student;
      final curriculumRepo = ref.watch(curriculumRepositoryProvider);

      // The student carries the id of the session they stand on
      // (`L{level}_J{juz}_S{n}`) — a direct read, no id rebuilding.
      return curriculumRepo.getSessionById(student.currentSessionId);
    });

/// The MEETING the student stands on: the N curriculum sessions their pace
/// covers, and the three content streams composed from them.
///
/// This is what every screen that teaches or reports on a student must read.
/// [studentCurrentSessionProvider] returns the single authored row and
/// remains correct for anything that browses the CURRICULUM (the
/// starting-point picker, the admin level detail) — but a student at 2x does
/// not meet a row, he meets a meeting.
///
/// The meeting is composed on every read from the student's LIVE pace.
/// Nothing about its extent is stored, which is exactly why a teacher can
/// change a student's pace mid-level and have it land on the next meeting
/// with nothing to migrate.
final studentCurrentMeetingProvider =
    FutureProvider.family<PacedSession?, String>((ref, studentId) async {
      final studentAsync = await ref.watch(studentProvider(studentId).future);
      if (studentAsync == null) return null;

      return composeMeetingFor(ref, studentAsync.student);
    });

/// The meeting to PREVIEW after the active session — the passage the teacher
/// recites (تلقين) with the student before closing. Recomposed from the
/// student's live pace like every other meeting. Null when there is no active
/// meeting, the student can't be resolved, or the active meeting is the last
/// in the level.
final activeSessionNextMeetingProvider = FutureProvider<PacedSession?>((
  ref,
) async {
  // Subscribe only to the two fields the next passage is composed from — the
  // meeting being taught and whose session it is — NOT the whole active
  // session. The recitation counts (and every other field) live on the same
  // state object and are edited on the very screen that shows this preview;
  // watching the whole object would reload the preview — flashing a spinner
  // over the passage card — on every count tap.
  final studentId = ref.watch(
    activeSessionProvider.select((s) => s?.studentId),
  );
  final meeting = ref.watch(activeSessionProvider.select((s) => s?.meeting));
  if (studentId == null || meeting == null) return null;

  final studentAsync = ref.watch(studentProvider(studentId));
  final student = studentAsync.value?.student;
  if (student == null) return null;

  return composeNextMeetingAfter(ref, student, meeting);
});

/// Session state for recording a session
class ActiveSessionState {
  final String studentId;
  final int currentPart; // 1, 2, or 3
  final int part1Errors;
  final int part2Errors;
  final int part3Errors;

  /// How many times teacher and student recited the passage through together.
  final int repetitionsWithTeacher;

  /// How many repetitions the student owes at home before the next session.
  final int homeRepetitionsRequired;
  final String? notes;
  final bool isComplete;

  /// The outcome of the student-progress update triggered by
  /// [ActiveSessionNotifier.completeSession] on a pass. Null until
  /// `completeSession` runs (or when the record failed, since progress is
  /// never advanced on a fail). Screens read this to tell a real advance
  /// apart from a silent no-op (e.g. no seeded curriculum data ahead) so
  /// they never show an unqualified success message for the latter.
  final StudentAdvanceOutcome? advanceOutcome;

  /// The meeting being taught — every curriculum session it covers, composed
  /// from the student's LIVE pace. Composed (best-effort) by
  /// [ActiveSessionNotifier.startSession] and recomposed on
  /// `completeSession` / `completeTalqeenSession`; still null if composition
  /// couldn't run (e.g. unseeded data, a provider still warming up). Screens
  /// read it to render every block it covers rather than just the one the
  /// student started on.
  final PacedSession? meeting;

  /// The instant [ActiveSessionNotifier.startSession] set this state — the
  /// wall-clock start of the recitation. Forwarded to
  /// `completeSession`/`completeTalqeenSession` so the repository can stamp
  /// the record's `duration`.
  final DateTime? startedAt;

  const ActiveSessionState({
    required this.studentId,
    this.currentPart = 1,
    this.part1Errors = 0,
    this.part2Errors = 0,
    this.part3Errors = 0,
    this.repetitionsWithTeacher = 0,
    this.homeRepetitionsRequired = 0,
    this.notes,
    this.isComplete = false,
    this.advanceOutcome,
    this.meeting,
    this.startedAt,
  });

  ActiveSessionState copyWith({
    String? studentId,
    int? currentPart,
    int? part1Errors,
    int? part2Errors,
    int? part3Errors,
    int? repetitionsWithTeacher,
    int? homeRepetitionsRequired,
    String? notes,
    bool? isComplete,
    StudentAdvanceOutcome? advanceOutcome,
    PacedSession? meeting,
    DateTime? startedAt,
  }) {
    return ActiveSessionState(
      studentId: studentId ?? this.studentId,
      currentPart: currentPart ?? this.currentPart,
      part1Errors: part1Errors ?? this.part1Errors,
      part2Errors: part2Errors ?? this.part2Errors,
      part3Errors: part3Errors ?? this.part3Errors,
      repetitionsWithTeacher:
          repetitionsWithTeacher ?? this.repetitionsWithTeacher,
      homeRepetitionsRequired:
          homeRepetitionsRequired ?? this.homeRepetitionsRequired,
      notes: notes ?? this.notes,
      isComplete: isComplete ?? this.isComplete,
      advanceOutcome: advanceOutcome ?? this.advanceOutcome,
      meeting: meeting ?? this.meeting,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  int get errorsForPart {
    switch (currentPart) {
      case 1:
        return part1Errors;
      case 2:
        return part2Errors;
      case 3:
        return part3Errors;
      default:
        return 0;
    }
  }

  /// Whether the in-progress session passes at the student's [level], per
  /// hibrahem/AlRasikhoon#24: FAILED if ANY component (new/near/far) grades
  /// محب (ويعاد); passes only if none is محب. No averaging, no level-agnostic
  /// ≤3 threshold — component grades are level-based (#22).
  bool passesForLevel(int level) => GradeCalculator.sessionPassesForLevel(
    level: level,
    newMemorizationErrors: part1Errors,
    recentReviewErrors: part2Errors,
    distantReviewErrors: part3Errors,
  );

  int get totalErrors => part1Errors + part2Errors + part3Errors;
}

class ActiveSessionNotifier extends Notifier<ActiveSessionState?> {
  @override
  ActiveSessionState? build() => null;

  /// Seeds an active session directly, bypassing `startSession` and Firestore.
  /// Test-only: widget tests for the recitation/summary/talqeen screens need a
  /// composed meeting in state without a full session start.
  @visibleForTesting
  void seedForTest(ActiveSessionState state) => this.state = state;

  /// Starts a session and — while the teacher is teaching it, not only once
  /// it is graded — composes and stores the meeting being taught.
  ///
  /// The session-summary screen shows what was JUST taught. By the time
  /// `completeSession`/`completeTalqeenSession` run, the student has already
  /// advanced past the meeting, so composing from his then-CURRENT position
  /// would describe the NEXT meeting, not the one just recited.
  /// `ActiveSessionState.meeting` is the only thing that can hold the
  /// meeting being taught, so it must be populated here, at the start,
  /// while the position it is composed from is still the one being taught —
  /// not left null until completion.
  ///
  /// `state` is set synchronously first so every other notifier method
  /// (`setPartErrors`, `setNotes`, ...) can be called immediately after,
  /// exactly as before this method became asynchronous.
  Future<void> startSession(String studentId) async {
    state = ActiveSessionState(studentId: studentId, startedAt: DateTime.now());
    await _loadMeetingBeingTaught(studentId);
  }

  /// Best-effort composition of the meeting for [startSession]. This is a
  /// display nicety for the in-progress screens, not the record of what
  /// happened — nothing is graded or written here, so a failure has nothing
  /// to lose. If the student or curriculum can't be read yet (unseeded
  /// data, a provider still warming up, ...) the session still starts with
  /// `meeting == null`. `completeSession` recomposes independently and is
  /// the one place a composition failure must be surfaced — see its doc
  /// comment — because that is where a grade would otherwise be silently
  /// lost.
  Future<void> _loadMeetingBeingTaught(String studentId) async {
    try {
      final studentAsync = await ref.read(studentProvider(studentId).future);
      if (studentAsync == null) return;

      final student = studentAsync.student;
      final curriculumRepo = ref.read(curriculumRepositoryProvider);
      final levelSessions = await curriculumRepo.getSessionsForLevel(
        level: student.currentLevel,
      );
      final meeting = PacedSessionComposer.compose(
        levelSessions: levelSessions,
        startOrderInLevel: student.currentOrderInLevel,
        pace: student.pace,
      );

      // The teacher may have started a different student's session, or
      // ended this one, while this composition was in flight — don't
      // resurrect a stale meeting onto the wrong (or a cleared) state.
      if (state?.studentId != studentId) return;
      state = state!.copyWith(meeting: meeting);
    } catch (_) {
      // See doc comment above: best-effort, nothing written, nothing lost.
    }
  }

  void setPartErrors(int part, int errors) {
    if (state == null) return;

    switch (part) {
      case 1:
        state = state!.copyWith(part1Errors: errors);
        break;
      case 2:
        state = state!.copyWith(part2Errors: errors);
        break;
      case 3:
        state = state!.copyWith(part3Errors: errors);
        break;
    }
  }

  void nextPart() {
    if (state == null) return;
    if (state!.currentPart < 3) {
      state = state!.copyWith(currentPart: state!.currentPart + 1);
    }
  }

  void setNotes(String notes) {
    if (state == null) return;
    state = state!.copyWith(notes: notes);
  }

  void setRepetitionsWithTeacher(int repetitions) {
    if (state == null) return;
    // The floor belongs here, not in the stepper widget that happens to be the
    // only caller today: a negative count is a caller bug, not data to
    // tolerate, so it surfaces the same way SessionKindX.fromString surfaces
    // an unknown kind — by throwing — rather than being clamped into a
    // silently "corrected" value that hides the bug.
    if (repetitions < 0) {
      throw ArgumentError.value(
        repetitions,
        'repetitions',
        'Repetitions with teacher cannot be negative',
      );
    }
    state = state!.copyWith(repetitionsWithTeacher: repetitions);
  }

  void setHomeRepetitionsRequired(int repetitions) {
    if (state == null) return;
    // See setRepetitionsWithTeacher: same invariant, same treatment.
    if (repetitions < 0) {
      throw ArgumentError.value(
        repetitions,
        'repetitions',
        'Home repetitions required cannot be negative',
      );
    }
    state = state!.copyWith(homeRepetitionsRequired: repetitions);
  }

  /// Grades and records the meeting, then advances the student past it on a
  /// pass.
  ///
  /// Composition happens BEFORE the record is written, deliberately: if
  /// `PacedSessionComposer.compose` cannot find a session at the student's
  /// `currentOrderInLevel` (a curriculum row missing or renumbered under
  /// him), it throws `ArgumentError` — and that throw propagates out of this
  /// method uncaught, so NOTHING is written. The recitation the teacher just
  /// heard is not silently saved with a wrong or empty scope, and it is not
  /// silently discarded either — the caller sees the exception (the
  /// `catch (e)` in `SessionSummaryScreen._saveSession`) and can tell the
  /// teacher the save failed, rather than reporting an unqualified success.
  /// This mirrors the posture `curriculumDataMissing` already enforces on
  /// the advance side: a graded session is never lost without a signal to
  /// someone.
  Future<SessionRecordModel?> completeSession() async {
    if (state == null) return null;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return null;

    // Save studentId before modifying state to avoid accessing stale state
    final studentId = state!.studentId;

    final studentAsync = await ref.read(studentProvider(studentId).future);
    if (studentAsync == null) return null;

    final student = studentAsync.student;
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);
    final curriculumRepo = ref.read(curriculumRepositoryProvider);

    // Compose the meeting from the student's LIVE pace: a fast student's
    // recitation may discharge several curriculum sessions at once, so the
    // meeting — not the student's own single current session — is what gets
    // graded and recorded.
    final levelSessions = await curriculumRepo.getSessionsForLevel(
      level: student.currentLevel,
    );
    final meeting = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: student.currentOrderInLevel,
      pace: student.pace,
    );
    state = state!.copyWith(meeting: meeting);

    // Create session record. One recitation, one record — however many
    // sessions the meeting batched together. Record and student progress are
    // STAGED into one WriteBatch so they land atomically: an offline save
    // must never sync the record without the advancement, or vice versa.
    final batch = sessionRepo.newWriteBatch();
    final record = await sessionRepo.createSessionRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      meeting: meeting,
      levelId: student.currentLevel,
      hizbNumber: student.currentHizb,
      attemptNumber: student.currentAttempt,
      newMemorizationErrors: state!.part1Errors,
      recentReviewErrors: state!.part2Errors,
      distantReviewErrors: state!.part3Errors,
      repetitionsWithTeacher: state!.repetitionsWithTeacher,
      homeRepetitionsRequired: state!.homeRepetitionsRequired,
      pace: student.pace,
      notes: state!.notes,
      startedAt: state!.startedAt,
      batch: batch,
    );

    // Update student progress
    StudentAdvanceOutcome? advanceOutcome;
    if (record.passed) {
      // Past the whole meeting — a 2x student who passes has discharged two
      // sessions and must not land back on the second of them.
      advanceOutcome = await studentRepo.advanceStudentSession(
        student.id,
        fromOrderInLevel: meeting.toOrderInLevel,
        batch: batch,
      );
    } else {
      // He repeats the MEETING, not half of it: his position is unchanged, so
      // the next composition rebuilds the same batch.
      await studentRepo.incrementStudentAttempt(student.id, batch: batch);
    }

    // Commit fire-and-forget: Firestore applies the batch to the local cache
    // immediately and queues it for sync. Awaiting would hang the save UI
    // forever offline — the commit Future only completes on server ack.
    unawaited(
      batch.commit().catchError((Object e, StackTrace s) {
        debugPrint('session save sync failed: $e');
      }),
    );

    // Clear state
    state = state!.copyWith(isComplete: true, advanceOutcome: advanceOutcome);

    // Invalidate providers — including the profile's cached سجل الحلقات, or
    // the new record won't appear until a manual refresh (al_rasikhoon-5ri).
    ref.invalidate(teacherStudentsProvider);
    ref.invalidate(studentProvider(studentId));
    ref.invalidate(teacherStudentSessionHistoryProvider(studentId));

    return record;
  }

  /// Completes a تلقين session: the teacher read the new passage to the student
  /// and repeated it with him.
  ///
  /// There is nothing to grade and nothing to fail, so the student ALWAYS
  /// advances — a تلقين has no attempts to exhaust.
  Future<SessionRecordModel?> completeTalqeenSession() async {
    if (state == null) return null;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return null;

    final studentId = state!.studentId;
    final studentAsync = await ref.read(studentProvider(studentId).future);
    if (studentAsync == null) return null;

    final student = studentAsync.student;
    final sessionRepo = ref.read(sessionRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);
    final curriculumRepo = ref.read(curriculumRepositoryProvider);

    // A تلقين always stands alone (`PacedSessionComposer` never batches one),
    // so this composition always spans exactly the student's own session —
    // but it goes through the same path as `completeSession` so the record
    // carries a span like every other one.
    final levelSessions = await curriculumRepo.getSessionsForLevel(
      level: student.currentLevel,
    );
    final meeting = PacedSessionComposer.compose(
      levelSessions: levelSessions,
      startOrderInLevel: student.currentOrderInLevel,
      pace: student.pace,
    );
    state = state!.copyWith(meeting: meeting);

    // Record and advancement staged into one batch, committed without
    // awaiting server ack — see completeSession for why.
    final batch = sessionRepo.newWriteBatch();
    final record = await sessionRepo.createTalqeenRecord(
      studentId: student.id,
      teacherId: currentUser.id,
      meeting: meeting,
      levelId: student.currentLevel,
      hizbNumber: student.currentHizb,
      repetitionsWithTeacher: state!.repetitionsWithTeacher,
      homeRepetitionsRequired: state!.homeRepetitionsRequired,
      pace: student.pace,
      notes: state!.notes,
      startedAt: state!.startedAt,
      batch: batch,
    );

    final advanceOutcome = await studentRepo.advanceStudentSession(
      student.id,
      fromOrderInLevel: meeting.toOrderInLevel,
      batch: batch,
    );

    unawaited(
      batch.commit().catchError((Object e, StackTrace s) {
        debugPrint('talqeen save sync failed: $e');
      }),
    );

    state = state!.copyWith(isComplete: true, advanceOutcome: advanceOutcome);

    // Including the profile's cached سجل الحلقات (al_rasikhoon-5ri).
    ref.invalidate(teacherStudentsProvider);
    ref.invalidate(studentProvider(studentId));
    ref.invalidate(teacherStudentSessionHistoryProvider(studentId));

    return record;
  }

  void endSession() {
    state = null;
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState?>(
      ActiveSessionNotifier.new,
    );

/// One student's recitation history, newest first — embedded in that student's
/// profile screen (al_rasikhoon-pb7). This replaced the teacher-wide "who did I
/// hear across all students" history tab: the teacher now sees a student's own
/// past sessions in context, on the same screen that shows their identity,
/// progress, pace, and current session.
///
/// Bounded the same way as the student-facing history: without a limit, a
/// student who has recorded a year of sessions re-downloads every one of them
/// on every profile open and pull-to-refresh.
final teacherStudentSessionHistoryProvider =
    FutureProvider.family<List<StudentHistoryEntry>, String>((
      ref,
      studentId,
    ) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getStudentHistory(studentId, limit: 50);
    });
