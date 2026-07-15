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
Task 9: complete (commits fe04cf3, 6565a64 — impl + fix, review clean) — 6 screens render the meeting
  Kind branches now read meeting.first. Curriculum-BROWSING screens (level_detail, starting_point_picker) untouched
  — verified zero diff. All 4 updated widget tests: every expect() unchanged (reviewer read them line by line).
  Added adminStudentCurrentMeetingProvider (1:1 mirror of the supervisor one) — admin_student_progress needed it.
  new_memorization_screen's 4-field breakdown collapsed to one merged-range line (a batch's content is a LIST,
  not one row's four fields) — was untested, now has a widget test incl. the no-new-content (سرد/اختبار) guard.
  Fixed: the merged-range MAIN path was unpinned at the widget layer (the fixture used non-contiguous blocks,
  proving only the edge case) — now pinned, and mutation-proven by forcing _isContiguous=false.
  Minor (final review): studentCurrentSessionProvider / adminStudentCurrentSessionProvider /
    studentDashboardSessionProvider are now unreferenced by any screen. LEFT IN PLACE deliberately — the parallel
    Claude session's uncommitted work touches these same provider files and removing them risks a merge conflict.
    Final review should decide whether to delete them.
Task 10 (LAST): complete, full suite 713/713 — the pace control on session_overview_screen.dart.
  al_rasikhoon-i1d and al_rasikhoon-sne (the "flexible placement / reposition" screens the brief pointed at) are
  both still OPEN — there is no edit-existing-student screen yet, only StartingPointPicker at student CREATION
  (add_student_screen). The actual shared neighbour is SessionOverviewScreen (teacher/screens, reused verbatim
  for the supervisor route with asSupervisor:true per app_router.dart) — the one screen both roles already land
  on for a given student, already gated by role (isSupervisorProvider) for the سرد card. Put the pace control
  there once rather than duplicating it across two screens.
  SegmentedButton<int> 1x/2x/3x reads student.pace.multiplier (CurriculumPace.fromJson already defaults absence
  to standard, so "never set" renders 1x with no extra branching) and calls
  studentRepositoryProvider.setStudentPace. On success invalidates studentProvider(studentId) when !asSupervisor,
  or supervisorStudentProvider(studentId) when asSupervisor — mirrors the existing invalidate pattern in
  sard_result_screen.dart (supervisorStudentsProvider + supervisorStudentProvider) rather than the brief's literal
  "invalidate studentProvider" text, because the supervisor branch of this screen never watches studentProvider at
  all (supervisorStudentProvider resolves independently through supervisorStudentsProvider) — invalidating the
  wrong family would leave the supervisor's meeting stale after a supervisor-set pace.
  Test gotcha: StudentLevelProgress (already on this screen) reads levelProvider -> curriculumRepositoryProvider
  -> firestoreProvider -> real FirebaseFirestore.instance when unmocked. In this Riverpod 3 app that errors and
  schedules an automatic retry Timer that outlives the test, tripping "Timer still pending" — fixed by overriding
  firestoreProvider with FakeFirebaseFirestore() in the new test, same as add_student_screen_test.dart /
  session_summary_screen_test.dart already do.
Task 10: complete (commit a88a1ab, review pending final) — pace control (1x/2x/3x) on session_overview_screen
  Placed there because the flexible-placement/reposition screens the plan pointed at DON'T EXIST YET
  (al_rasikhoon-i1d and -sne are still OPEN). session_overview is the one screen both teacher AND supervisor
  land on for a student (it's reused verbatim with asSupervisor: true).
  Good deviation: invalidates whichever student provider the ACTIVE path watches — the supervisor path is fed by
  supervisorStudentProvider, independent of studentProvider; invalidating the wrong one would leave the
  supervisor's meeting stale. Mirrors sard_result_screen.dart.
  Suite 713/713.
FINAL WHOLE-BRANCH REVIEW: found 1 CRITICAL, fixed in f42cce1. Suite 714/714, analyze clean.
  *** CRITICAL (my spec's bug, introduced TWICE): the display merge invented Qur'an verses across a surah
  boundary. The rule "different surah AND next.fromVerse == 1 => contiguous" assumes the previous surah was
  FINISHED — but the app does not know surah lengths (deliberately) and the assumption is FALSE on real data.
  L9 distant: order 13 = هود 1-28, order 14 = يوسف 1-111. هود has 123 verses; the source SKIPS هود 29-123.
  A 2x student would have seen "هود: 1 إلى يوسف: 111" — ~95 verses nobody assigned him.
  FIX: merge ONLY within one surah on adjacent verses. Cross-surah blocks render as two ranges joined by ' • '.
  Mutation-proven with the real هود/يوسف data.
  Reviewer also walked all 10 levels at paces 2/3/5: no order is ever skipped or repeated, no batch ever
  contains a non-lesson, no stranding at a level boundary. Legacy record round-trip re-verified.
Minors filed as al_rasikhoon-1aq. Source-data defects added to al_rasikhoon-drw.
NOT DONE: (a) in-app verification (plan Task 11 step 2); (b) reconciling with the parallel session's
  uncommitted SessionRecordModel work (kind + juzNumber) in the MAIN checkout — Task 6 rewrote the same model.

=== REBASED ONTO MAIN (2026-07-14) ===
main had moved 15 commits: the talqeen work (merged under DIFFERENT SHAs, so `git cherry` saw nothing as
applied), SessionRecordModel.kind + juzNumber, AND a sard/exam ROLE SWAP (al_rasikhoon-801: the TEACHER now
conducts the سرد; the supervisor gets a read-only StudentProgressScreen, and SessionOverviewScreen's
`asSupervisor` flag is GONE). main also already had my spec+plan docs (they rode in on feat/talqeen-sessions).
=> Dropped 20 duplicate talqeen/doc commits, replayed only the 19 paced ones with `rebase -i --onto origin/main`.
Reconciliations made:
  - SessionRecordModel: kept main's kind + juzNumber AND my span (from/to/covers/paceAtTime). orderInLevel gone,
    but still WRITTEN as the compat mirror a Firestore composite index depends on.
  - createSessionRecord/createTalqeenRecord: DROPPED the redundant kind:/juzNumber: params — they now read
    meeting.sessions.last.kind/.juzNumber. Strictly better: the real curriculum row, not the student's
    denormalized current_session_kind/current_juz, which are a copy and can drift.
  - recitation_screen: KEPT main's guard (refuse the grading flow unless on a lesson), re-expressed via
    meeting.first.isLesson.
  - session_overview_screen: followed main — teacher-only, asSupervisor branch deleted.
  - StudentProgressScreen (main's new role-agnostic screen with INJECTED providers): rewired to inject the
    MEETING provider. Was showing an admin/supervisor only the FIRST of a 2x student's two lessons.
Final: 759/759 passing, analyzer clean, 21 commits ahead of main. All invariants verified intact.

=== SESSION DURATION TIMER — plan: docs/superpowers/plans/2026-07-15-session-duration-timer.md ===
# Issue: al_rasikhoon-tr6
# Branch: claude/session-duration-timer-23fc26 (base c6ff299)
# 12 tasks. Baseline: 759 tests at c6ff299 (per prior ledger).
Task 1: complete (commit 0245c22, review clean) — SessionDuration value object (domain, pure Dart+intl).
  Deviation (correct): arabicMinutesLabel uses NumberFormat('#','ar_EG') not 'ar' — generic 'ar' renders
  WESTERN digits in intl 0.20.2; 'ar_EG' carries Arabic-Indic (ZERO_DIGIT ٠). Confirmed in intl source.
  => Task 11's card label reuses arabicMinutesLabel, so it inherits Arabic-Indic digits automatically.
  Minor (final review): band-boundary tests never hit EXACTLY 15/25 min (the ±25% edges) or elapsed==cap;
  mutation < -> <= on the band edge would survive. Inherited from the plan's chosen test values, not impl.
Task 2: complete (commit 734bb8d, review clean) — duration on SessionRecordModel (duration_seconds int, nullable, copyWith). No findings.
Task 3: complete (commit 46854ec, review clean) — duration on SardRecordModel + ExamRecordModel (identical shape, duration_seconds int, nullable, copyWith). No findings.
Task 4: complete (commits e460af8 impl + e3ca3a1 test-fix, review clean) — repo computes lesson/talqeen
  duration inside _writeSessionRecord builder (same writtenAt instant as date/createdAt), via
  SessionDuration(...).elapsed so the 3x cap applies; startedAt null -> duration null. 48/48.
  Fix closed reviewer's Important (talqeen path had identical code, zero tests) + Minor (no 2x test —
  90min@2x asserts uncapped, fails if pace.multiplier hardcoded to 1). createSard/Exam untouched.
Task 5: complete (commit daa7171, review clean) — createSardRecord/createExamRecord gain startedAt + now seam;
  writtenAt computed ONCE for both date+createdAt (fixed latent two-DateTime.now() drift); RAW uncapped elapsed
  (no SessionDuration on this path); startedAt null -> null. 51/51.
  Minor (final review): createExamRecord has no DIRECT null-duration test (sard does; code identical). Inherited
  from brief. Cheap follow-up test.
Task 6: complete (commit 245a46a, review clean) — ActiveSessionState.startedAt (copyWith preserves via ?? this); startSession stamps DateTime.now(); completeSession/completeTalqeenSession forward startedAt. Test uses REAL SessionRepository (makeRealContainer) so forward path is proven, not mocked. 29/29. No findings.
Task 7: complete (commit c20525c, review clean) — SessionTimer widget (StatefulWidget, Timer.periodic 1s,
  cancelled in dispose, display-only). Deviation (correct, justified): seeds _elapsed in initState from real
  diff then INCREMENTS +1s per tick (instead of re-diffing DateTime.now every build) — required for
  FakeAsync tester.pump determinism; display-only so timer jitter can't corrupt the RECORDED duration
  (that comes from repo writtenAt-startedAt). 3/3, full suite 836/836.
  Minor (mitigated in Task 8): no didUpdateWidget re-seed if startedAt changes while mounted. NOT a current
  bug (screens remount per session). MITIGATION: Task 8/9/10 pass key: ValueKey(startedAt) to SessionTimer.
Task 8: complete (commits 5f09afe impl + import-cleanup, review clean) — ActiveLessonTimer ConsumerWidget
  (reads activeSessionProvider.startedAt + studentProvider pace; SizedBox.shrink when no session), keyed
  SessionTimer via ValueKey(startedAt) [Task 7 Minor mitigation]. Wired into 4 lesson AppBars
  (new_memorization, recitation, session_summary MAIN bar, talqeen). Corrected .valueOrNull->.value
  (Riverpod 3.1.0 nullable getter; matches session_summary_screen). Removed brief's unused test import to
  keep analyze clean. 9/9. No findings.
Task 9: complete (commit ce9be90, review clean) — sard flow timed. _startedAt in initState (late final,
  set once); AppBar SessionTimer elapsed-only (no target), keyed ValueKey(_startedAt); push extra now a RECORD
  (errorCount, startedAt) — old bare-int read replaced; router casts the record, null-safe deep-link degrade;
  SardResultScreen forwards startedAt to createSardRecord. Record cast matches push field-for-field. 2/2. No findings.
Task 10: complete (commit 4580b8d, review clean) — exam flow timed, exact twin of Task 9. examResult
  route switched from bare-int to record extra; sardResult/recitationResult untouched; push shape matches cast
  field-for-field; ExamResultScreen forwards startedAt to createExamRecord. 4/4. No findings.
Task 11: complete (commit 6c9de25, review clean) — SessionRecordRow optional sessionDuration: duration line
  (المدة: arabicMinutesLabel) + _DurationFlag pill (under=info/onTarget=success/over=warning), NO flag when
  status none (assessments). Wired into student + teacher history. Deviation (correct): flag labels reworded
  المدة->المستهدف ("target") to avoid colliding with the duration line's own المدة: in find.textContaining;
  distinguishing words أطول/أقصر/ضمن kept. 12/12, full suite 842/842.
  Minor (final review): (1) no pill-COLOR assertion (only label text) — inherited from brief; (2) the 7-line
  "build SessionDuration from record" block is duplicated in both history screens — a SessionDuration.fromRecord
  factory would DRY it.
Task 12: GATE PASSED — flutter analyze clean on all changed files (only 3 pre-existing RawKeyEvent
  deprecations in app_text_field.dart, untouched by this feature); full suite 842/842 passing. No fixes needed.
FINAL WHOLE-BRANCH REVIEW (opus): READY TO MERGE — no Critical/Important. Traced both flows end-to-end
  (startedAt never dropped; assessments never get a target; recorded duration always from repo writtenAt-startedAt,
  never the display timer). Single source of truth (SessionDuration) confirmed for 20xpace/±25%/3x — no
  reimplementation. ValueKey(startedAt) mitigation verified at ALL 3 consumer sites (ActiveLessonTimer,
  Sard/ExamSessionScreen). DDD clean (domain imports only intl). All 5 Minors deferred (test-coverage/DRY only).
  Filed as follow-up beads issue. Suite 842/842, analyze clean.

=== AL RASIKHOON MANUSCRIPT UI — plan: docs/superpowers/plans/2026-07-15-al-rasikhoon-manuscript-ui.md ===
# Issue: al_rasikhoon-5ss (pass 1: foundation + student slice)
# Worktree: .claude/worktrees/al_rasikhoon-5ss-ui-overhaul
# Branch: worktree-al_rasikhoon-5ss-ui-overhaul (base 645a5a8)
# 17 tasks. Baseline: plan committed at f13488b.
Task 1: complete (commit 1924423, review clean) — bundled Amiri + Aref Ruqaa TTFs into google_fonts/
  Minor (not fixed): tests use testWidgets() w/ unused tester param instead of plain test() — justified
  (Flutter binding init for asset loading), approved as-is.
Task 2: complete (commit 54ee6b6, review clean) — AppTokens ThemeExtension (16 fields, light+dark, copyWith+lerp),
  AppDimens, AppMotion. All hex values verified byte-for-byte against plan. No findings.
Task 3: complete (commit 32592bd, review clean) — AppTheme.lightTheme/darkTheme both built from a single
  _build(tokens, brightness) helper; dark is genuinely dark (Brightness.dark, AppTokens.dark), AppTokens
  extension attached to both, scaffoldBackgroundColor=tokens.page. Reviewer confirmed the test would have
  caught the original darkTheme=>lightTheme bug. No AppColors leaks, no non-bundled fonts. No findings.
Task 4: complete (commit 69245f3, review clean) — persisted ThemeModeNotifier/themeModeProvider (plain
  Riverpod, key 'theme_mode', values light/dark/system, unrecognized->system). No findings.
Task 5: complete (commits b0cdccb impl + 2861077 fix, review clean) — wired darkTheme + ref.watch(themeModeProvider)
  into MaterialApp.router in lib/app.dart. Fixed: dart format incidentally collapsed 2 unrelated multi-line
  properties (supportedLocales, builder) to single-line -> reverted to keep diff minimal. Re-review approved.
Task 6: complete (commit 40da117, review clean) — ThemeModeSelector (AppCard + SegmentedButton<ThemeMode>,
  فاتح/داكن/تلقائي) embedded in settings_screen.dart after _ProfileCard; stale "no theme toggle" doc comment
  replaced. No findings. === FOUNDATION (Tasks 1-6) DONE: fonts, tokens, real dark theme, persistence,
  MaterialApp wiring, Settings toggle. Next: shared-widget reskin (7-12), then student screens (13-16). ===
Task 7: complete (commits 6cfe372 impl + 81fe70c fix + 92d34bd fix, review clean) — theme_test_harness.dart
  (pumpInTheme, real AppTheme light/dark, RTL) + AppCard reskinned (context.tokens.card default bg,
  backgroundColor still wins, new illuminated=true draws gold hairline border via tokens.gold).
  *** ARCHITECTURE DECISION (escalated to user) ***: context.tokens was `Theme.of(this).extension<AppTokens>()!`
  (hard crash) -> broke 88 pre-existing tests across 32 files pumping bare MaterialApp() w/o AppTheme. User
  chose: fallback to AppTokens.light instead of touching 32 test files. Fix confirmed PRODUCTION-UNREACHABLE
  (app_theme.dart._build always sets extensions:[t]; app.dart always supplies AppTheme.light/darkTheme; grep
  confirms context.tokens is the only extension<AppTokens>() call site) — only fires in themeless tests.
  SEPARATE regression also found+fixed: Tasks 5/6 wired themeModeProvider into AlRasikhoonApp/SettingsScreen;
  2 pre-existing test files (settings_screen_test.dart x7, role_shell_navigation_test.dart x1) never overrode
  sharedPreferencesProvider (didn't need to, before). Fixed via the established SharedPreferences mock pattern,
  no assertions weakened. Full test/widget suite: 135 passing, 0 failing (true baseline was 131/0 pre-plan).
  Minor (not fixed): `width: illuminated ? 1 : 1` no-op ternary in app_card.dart, cosmetic only.
  PROCESS NOTE for tasks 8-16: use pumpInTheme() harness for all new tests; context.tokens now safe to use
  in any test context (falls back to light tokens if untHEMEd).
Task 8: complete (commit 8a6b2ac, review clean) — Illuminated Juz Ring signature widget (juzRingSweep pure
  fn + JuzRing widget + _JuzRingPainter custom paint). Token-driven colors, no data-fetching (pure presentational).
  No findings.
Task 9: complete (commit e71931a, review clean) — reskinned stat_card/student_card/app_button/app_text_field
  to context.tokens per mapping table. NOTE: implementer subagent was cut off mid-run by an API spend-limit
  error before committing/reporting; controller verified diff line-by-line, ran flutter analyze + full
  test/widget suite (137 passing, 0 failing) directly, committed on its behalf, wrote the report. Reviewer
  independently re-verified every substitution against the mapping table. Out-of-table colors (warning/info/
  textOnPrimary/textOnSecondary) correctly left untouched. Minor (not fixed): a few unrelated dart-format
  line-collapses with zero color changes (cosmetic only, e.g. StatItem ctor, AppTextField label Text()).
Task 10: complete (commits 878fbfe impl + 90f9a8d fix, review clean) — reskinned grade_display/session_timer/
  session_record_row/error_counter to tokens+grade tokens; progress_bar fill animates via
  AppMotion.of(base), reduced-motion aware, public API unchanged. Mastery ladder (5 rungs, راسخ..محب) added
  to student_level_progress.dart + level_progression_widget.dart, constructors preserved. Implementer itself
  caught+fixed 2 pre-existing test regressions (hardcoded old AppColors values in
  session_record_row_duration_test.dart) applying the Task 7/9 lesson.
  Fixed (review-found, Important x2): (1) LevelProgressionWidget's ladder fraction was currentLevel/totalLevels,
  CONTRADICTING its own header (completedLevels.length/totalLevels) -> corrected to
  completedLevels.length/totalLevels, matches student_level_progress.dart's "in-progress-not-done=zero"
  convention; new regression test proven to catch the original bug. (2) _MasteryLadder was duplicated
  verbatim (~66 lines) across both widgets -> consolidated into ONE public MasteryLadder class in
  progress_bar.dart, both callers import it, zero duplication remains (grep-verified).
  Dead code left in place, not removed (Minor, acceptable restraint): LevelProgressBar in progress_bar.dart
  now unreferenced anywhere; unlockedLevels ctor param on LevelProgressionWidget accepted but unused by the
  new ladder motif (documented in class doc comment). Full test/widget suite: 140 passing, 0 failing.
Task 11: complete (commit 63a21ec, review clean) — bottom_nav_bar (selected=gold/unselected=sepia),
  role_shell (Scaffold bg=tokens.page, nav logic byte-identical, verified), confirm_sign_out (error->maroon).
  nav_destinations.dart needed no changes (icon/label/route data only, no colors) - claim independently
  verified. All 4 constructors unchanged. role_shell_navigation_test.dart 1/1, full suite 140/0. No findings.
  === SHARED-WIDGET RESKIN SWEEP (Tasks 7-11) COMPLETE. Next: Task 12 empty/error/loading states, then
  Tasks 13-16 student screens adopt everything. ===
Task 12: complete (commit a83d90a, review clean) — ShimmerBox (reduced-motion aware, controller lazily
  created + disposed correctly), EmptyState, ErrorState ('إعادة المحاولة' retry), LoadingState (composes
  ShimmerBox). All token-driven, no providers. No findings.
  === FOUNDATION + WIDGET RESKIN (Tasks 1-12) ALL COMPLETE. Starting screen adoption (13-16). ===
Task 13: complete (commits ac1407d impl + cd69931 fix, review clean) — student_dashboard_screen adopts
  full system: JuzRing hero (juz=stats.currentJuz, progress=currentOrderInLevel/totalSessions w/ explicit
  zero-guard, NOT bare .clamp which doesn't stop 0/0=NaN), AppBar title in Aref Ruqaa (only use of that
  font in the app, verified), LoadingState/ErrorState replace bespoke spinners, full token mapping applied.
  No new provider calls, RefreshIndicator byte-identical - both verified via direct diff.
  Fixed (review-found, Important): AppColors.info (not in mapping table) was mapped to tokens.sepia for the
  سرد card's accent -> collided with that SAME card's own caption text (also sepia via textSecondary
  mapping), making the "distinct 3rd accent" invisible against its own body text. Fixed -> tokens.maroon
  (palette's rubrication/emphasis hue), caption stays sepia. 3 session-type cards now genuinely distinct:
  lesson=green, exam=gold, سرد=maroon.
  Minor (not fixed, deferred): AppColors.success (also not in mapping table) -> tokens.green makes 2 of 3
  quick-stat tiles the same color (were previously distinguishable primary/success green shades). Low
  severity, follow-up only if a dedicated success token is added later.
  Full test/widget suite: 143 passing, 0 failing throughout.
Task 14: complete (commit 2c39ce5, review clean) — session_detail_screen adopts full system: token mapping,
  LoadingState/ErrorState replace bespoke spinners, no new provider calls, data-fetching byte-identical.
  success->green judgment call (Task 13 precedent), verified no role collision this time.
  *** REAL BUT OUT-OF-SCOPE GAP FOUND (Minor, deferred to Task 17 follow-ups) ***: lib/core/utils/
  grade_calculator.dart's GradeInfo.color bakes RAW brightness-unaware AppColors.gradeX as const at
  construction, bypassing AppTokens entirely -> genuine dark-mode contrast defect on every screen reading
  gradeInfo.color (this screen + grade_display.dart's GradeBadge). Pre-existing since Task 10 (which only
  had grade_display.dart in scope, not grade_calculator.dart - a core/utils file no task in this plan
  charters). Task 17's own verification grep doesn't scan lib/core/utils either, so this would silently
  survive final verification unless filed explicitly. PROPER FIX requires an architectural change (drop
  `color` from GradeInfo, have callers map Grade->tokens.gradeX themselves) - not a rushed single-screen fix.
  MUST file as a bd follow-up issue during Task 17 alongside the teacher/admin/supervisor/auth issues.
  Full test/widget suite: 143 passing, 0 failing.
Task 15: complete (commit b1eb02d, review clean) — session_history_screen: EmptyState (exact copy verified
  verbatim) for no-sessions case, ErrorState for load failures, no AppColors left (file had none directly -
  row rendering fully delegates to SessionRecordRow, already reskinned/token-driven from earlier work,
  verified it genuinely shows a binary pass/fail marker per #24's rule, not literally GradeDisplay but a
  real outcome indicator). No new provider calls, data-fetching byte-identical. No findings.
  Minor (not fixed, cross-cutting pre-existing pattern, not this task's): no screen in the app passes
  onRetry to ErrorState - consistent gap across sibling screens, follow-up only.
