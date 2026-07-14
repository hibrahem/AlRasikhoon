# Paced curriculum (NX) — plan: docs/superpowers/plans/2026-07-14-paced-curriculum-nx.md
# Issue: al_rasikhoon-g63
# Worktree: .claude/worktrees/paced-curriculum-nx
# Branch: feat/paced-curriculum-nx (base ad03308, off feat/talqeen-sessions)
# NOTE: a parallel Claude session holds uncommitted SessionRecordModel work
#       (kind + juzNumber) in the MAIN checkout. This worktree does not have it.
#       Task 6 rewrites the same model -> expect a merge reconciliation at the end.
# Baseline: 615 tests passing at ad03308.
Task 1: complete (commit 6f52bff, review clean) — CurriculumPace value object; validating ctor (not const/assert), fromJson(null)=standard
  Minor (final review): fromJson rejects a double (e.g. 3.0); correct per spec, but note if a write path ever serializes pace as double
Task 2: complete (commits 72b70e8, d1581eb — impl + fix, review clean) — PacedSession + PacedSessionComposer
  Reviewer mutation-tested the composer and simulated it over the real 952 rows. pace-1 verbatim early return
  is intact and PROVEN load-bearing (deleting it fails a test). Fixed: vacuous سرد test (asserted nothing),
  no اختبار coverage, _unitStart clamp now stops at an assessment (latent trap for a future curriculum re-import).
  Minor (final review): F3 levelId!=start.levelId guard in _batch is unreachable (byOrder keyed on order alone);
    F4 recent-window loop bound `order < start` protected only by rule 3, not pinned directly;
    F6 taught-today exclusion is exact-equality only (safe today: all 59 تلقين duplicate their lesson exactly);
    at a unit start the composed recent lists the تلقين block TWICE (per brief's own expected output) —
    PRESENTATION (Task 9) should de-duplicate before showing a student.
  NEW SOURCE-DATA DEFECT found by reviewer: L4 order 6 authored recent is `السجدة 21-11` — INVERTED
    (from_verse 21 > to_verse 11). Add to al_rasikhoon-drw.
Task 3: complete (commit dedb615, review clean) — 952 real sessions walked; pace-1 verbatim PASSES on all 10 levels
  Reviewer MUTATION-PROVED the test has teeth: deleting the pace-1 early return fails group 1 on ALL 10 levels;
  deleting the !isLesson batch guard fails group 3 on all 10.
  *** MAJOR FINDING: the early return protects far MORE than the ~8 anomalous rows. Composition represents
  recent review as DISCRETE ADJACENT BLOCKS [لقمان 20-28, لقمان 29-34] while the curriculum authors the same
  span as ONE MERGED RANGE [لقمان 20-34]. So at pace 1 composition would differ on NEARLY EVERY row.
  => Open design question for pace>1 presentation: composed recent is fragmented, and at a unit start it also
     lists the تلقين block TWICE. A 2x student would see "النبأ 1-11 • النبأ 1-11 • النبأ 12-20 • النبأ 21-30"
     instead of the curriculum's own idiom "النبأ 1-30". ESCALATED TO USER before Task 4.
  RESOLVED by user: de-dupe + merge contiguous blocks, ALL THREE streams (new too: 2x new = "النبأ 31 - 40").
  Controller decision: do it in the DISPLAY getters (Task 8), NOT in the composer. Rationale: the composer's
  discrete lists are what give Task 2/3's mutation-proven tests their teeth (the "recent never intersects
  today's new" assertion compares discrete blocks; merging inside the composer would make it never match and
  silently go toothless). Domain keeps truth; presentation merges. Merge rule = the curriculum's own:
  span(first.from -> last.to) per contiguous run, after de-dupe. No verse number is ever computed.
Task 4: complete (commit 214fb91, review clean) — StudentModel.pace + StudentRepository.setStudentPace
  Extracted StudentModel.fromJson from fromFirestore (mirrors SessionModel); dropped `const` from the ctor
  (no call sites used it — grep-verified). Legacy safety MUTATION-PROVEN: defaulting a missing pace to 2
  fails 'a student created before paced curricula runs at the standard pace'. Full suite 672/672.
Task 5: complete (commit 12acd2d, review clean) — CurriculumRepository.getSessionsForLevel, ordered by order_in_level
  Ordering MUTATION-PROVEN: switching to orderBy('juz_number') fails both tests.
Task 6: complete (commits a0b71de, 5e04f95 — impl + fix, review clean) — SessionRecordModel spans the meeting
  BACKWARD COMPAT PROVEN BY EXECUTION: legacy docs (order_in_level, no span) read back as single-session pace-1.
  toFirestore keeps writing order_in_level = toOrderInLevel (the compat mirror a composite Firestore index
  depends on); reviewer proved writing `from` instead would corrupt getLatestSessionRecord.
  Fixed: batching had NO repo test (mutations survived all 313); paceAtTime recorded sessions.length (redundant,
  and LIED when a batch truncates at a boundary) -> now takes an explicit CurriculumPace and records
  pace.multiplier; coversSessionIds `const []` ctor default (a latent trap that bypassed the legacy fallback).
  NOTE for Task 7 — createSessionRecord/createTalqeenRecord now BOTH require `required CurriculumPace pace`.
Task 7: complete (commit TBD, full suite 682/682) — teacher_provider composes the meeting, restores compilation
  StudentRepository.advanceStudentSession(studentId, {fromOrderInLevel}) — defaults to student.currentOrderInLevel
  (unchanged behaviour); threaded into _nextSession's two currentOrderInLevel reads. completeSession/
  completeTalqeenSession both: read curriculumRepo.getSessionsForLevel, compose via PacedSessionComposer from the
  student's LIVE pace, pass `meeting` + `pace: student.pace` to the record factory, advance with
  `fromOrderInLevel: meeting.toOrderInLevel` on pass, leave position untouched (repeat the whole meeting) on fail.
  ActiveSessionState carries `meeting` for Task 8/9's screens.
  PINNED (test/unit/providers/teacher_provider_test.dart, new group "paced meetings"): 2x discharges two sessions
  in ONE record and lands on order 7; 2x FAIL repeats the whole meeting (position unchanged, attempt+1); 1x
  student unaffected (one session, one record, +1); 2x still meets the سرد ALONE (batch stops before it, lands ON
  it). All four use REAL CurriculumRepository/SessionRepository/StudentRepository against one FakeFirebaseFirestore
  (mocking StudentRepository can't prove a real position write).
  Also fixed (Task 6 left broken, not explicitly listed but required for the suite to compile):
  test/unit/providers/home_practice_notifier_test.dart, test/widget/session_history_listing_test.dart,
  test/widget/session_summary_screen_test.dart (all constructed SessionRecordModel/called the record factories
  with the removed orderInLevel/curriculumSessionId/sessionNumber params, or never overrode
  curriculumRepositoryProvider now that completeSession reads it).
Task 7: complete (commits e2f543b, d12b122 — impl + fix, review clean) — teacher provider teaches a paced meeting
  advanceStudentSession(id, {fromOrderInLevel}); pass advances past the WHOLE meeting, fail repeats it whole.
  Fixed: the level-boundary rollover had NO test (reverting the threaded data-hole check left all 682 green,
  yet would STRAND every paced student at the end of every level — now mutation-proven); ActiveSessionState.meeting
  was set when the meeting ENDED (must be at START — after a pass the student has advanced, so the summary screen
  would show the NEXT meeting); compose-throws-before-write now explicit + tested. Suite 686/686.
  Note: completeSession RE-composes from the live pace at completion (start-time meeting is display-only) —
  correct: a pace change mid-session uses the live pace for grading/advance.
  Minor (final review): stale doc comment on ActiveSessionState.meeting still says "Null until completeSession".
Task 8: complete (suite 702/702) — the meeting exposed to the UI: display getters + three providers.
  PacedSession gains newContentAr/recentReviewAr/distantReviewAr (de-duplicate, then merge contiguous runs —
  display-only, PacedSessionComposer's discrete lists are untouched) and hasNewContent/hasRecentReview/
  hasDistantReview. Shared composeMeetingFor(Ref, StudentModel) in teacher_provider.dart backs three three-line
  twins of the existing "current session" providers: studentCurrentMeetingProvider (teacher),
  supervisorStudentCurrentMeetingProvider (institute-scoped, AgDR-0003), studentDashboardMeetingProvider (the
  student). Session providers kept — curriculum-browsing screens still want the authored row.
  Note: a provider test asserting studentProvider('missing-id').future rejects (Riverpod's firstWhere-throws-in-
  orElse pattern reading through .future) hangs rather than rejecting — pre-existing behavior, untested before
  this task, out of scope; dropped that assertion rather than debug an unrelated Riverpod interaction.
Task 8: complete (commits ce6150f, 38ad744 — impl + fix, review clean) — meeting providers + de-dupe/merge display
  Three meeting providers (teacher / institute-scoped supervisor / student dashboard) sharing ONE composeMeetingFor,
  hoisted to lib/shared/providers/meeting_provider.dart. Session providers KEPT (curriculum-browsing screens need
  the authored row). Composer untouched — merge is DISPLAY-ONLY, so the Task 2/3 gate tests keep their teeth.
  *** CRITICAL BUG FIXED (my spec's error, not the implementer's): the contiguity rule was
  `next.fromSurah == prev.toSurah || next.fromVerse == prev.toVerse + 1` — same-surah alone counted as contiguous,
  so النبأ 1-11 + النبأ 30-40 merged to النبأ 1-40, INVENTING verses 12-29 nobody assigned. Correct rule:
  same surah AND adjacent verses, OR different surah AND next starts at verse 1. Mutation-proven.
  Note: reviewer agent was killed by a session limit mid-run; I completed the critical checks directly
  (no tests deleted — the "dropped test" was the implementer's own scratch, never committed; composer untouched;
  session providers intact) and removed a stray scratch test the killed agent left behind.
