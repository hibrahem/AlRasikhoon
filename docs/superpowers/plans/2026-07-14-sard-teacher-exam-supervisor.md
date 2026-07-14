# Sard → Teacher, Exam → Supervisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** السرد (Sard) becomes teacher-conducted and الاختبار (Exam) stays supervisor-conducted, reversing the Sard half of #29.

**Architecture:** Three independent slices. (1) Firestore rules: `sard_records` writes move from supervisor to teacher. (2) App: the Sard screens and routes move from the supervisor shell into the teacher shell and swap to teacher-scoped Riverpod providers; the teacher's session-overview gains the **بدء السرد** action. (3) Supervisor: its session-overview twin is replaced by a shared read-only progress screen, so the supervisor keeps its institute-scoped الطلاب roster (#28) but has no Sard doorway at all.

**Tech Stack:** Flutter, Riverpod (`FutureProvider.family`), go_router (`StatefulShellRoute.indexedStack`), Firestore security rules, `@firebase/rules-unit-testing` + mocha, `fake_cloud_firestore` + `integration_test`.

**Spec:** `docs/superpowers/specs/2026-07-14-sard-teacher-exam-supervisor-design.md`
**Issue:** `al_rasikhoon-801`

## Global Constraints

- **Ubiquitous language:** سرد = Sard = teacher-conducted. اختبار = Exam = supervisor-conducted. Never introduce a third term.
- **Exclusivity:** A supervisor MUST NOT be able to start a Sard from any surface. A teacher MUST NOT be able to start an Exam. Enforced at three layers: UI (no entry point), router redirect (backstop), Firestore rules (true backstop).
- **Exam flow is untouched.** Do not modify `exam_queue_screen.dart`, `exam_session_screen.dart`, `exam_result_screen.dart`, the `exam_records` rule, `examQueueProvider`, `examStudentProvider`, or `examSessionProvider`.
- **Arabic copy is verbatim.** Button: `بدء السرد`. Screen titles: `السرد`, `نتيجة السرد`, `تقدم الطالب`. Never invent or translate copy.
- **`SardRecordModel.teacherId` keeps its name** — it was always named for the teacher. No model change, no migration.
- **Teacher record writes stay unscoped** (`allow ...: if isTeacher()`), matching `session_records` exactly. Tightening both is `al_rasikhoon-ob7`, NOT this plan.
- **Commit after every task**, using `al_rasikhoon-801` in the commit scope.
- Integration tests need a booted device: `flutter test integration_test/<file> -d <device-id>` (get the id from `flutter devices`; prefer the iOS simulator — Android 9 hangs, `al_rasikhoon-1fg`). Unit and widget tests run headless with plain `flutter test`.

---

### Task 1: Firestore rules — `sard_records` becomes teacher-writable

Independent of the app slices; do it first so the true backstop is right before any UI can exercise it.

**Files:**
- Modify: `firestore.rules:141-152` (the `sard_records` match block)
- Test: `test/rules/firestore.rules.test.js` (the `#29 — Sard is SUPERVISOR-ONLY` block at the end, plus the two sard cases inside `Finding #2`)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: nothing later tasks import. The rule `allow create, update: if isTeacher()` on `sard_records` is what Task 2's teacher Sard write depends on in production (not in tests, which use `fake_cloud_firestore` and do not evaluate rules).

- [ ] **Step 1: Write the failing tests**

In `test/rules/firestore.rules.test.js`, **delete** these two tests inside the `Finding #2` section (a supervisor can no longer update a sard_record at all, so "can't repoint it" and "can update it in-institute" are both testing a rule that no longer exists):

```js
  it("DENIES a supervisor repointing a sard_record's student_id to another institute", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { student_id: "stu_b" })
    );
  });
```

```js
  it("ALLOWS a supervisor updating an in-institute sard_record (no repoint)", async () => {
    const db = asUser("sup_a");
    await assertSucceeds(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 7 })
    );
  });
```

Then **replace the entire `// === #29 — Sard is SUPERVISOR-ONLY (teacher write removed) ====` section** (every `it(...)` in it, through the end of the file's last sard test) with this inverted block:

```js
  // === al_rasikhoon-801 — Sard is TEACHER-ONLY (reverses #29) ===============
  // سرد is conducted by the TEACHER; the supervisor conducts الاختبار. Teacher
  // writes are unscoped here, exactly as session_records already is — scoping
  // BOTH to the teacher's own students is al_rasikhoon-ob7.

  it("ALLOWS a teacher creating a sard_record (Sard is teacher-conducted, al_rasikhoon-801)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      setDoc(doc(db, "sard_records", "sard_new_teacher"), {
        student_id: "stu_a",
        pages: 3,
      })
    );
  });

  it("ALLOWS a teacher updating an existing sard_record (al_rasikhoon-801)", async () => {
    const db = asUser("teacher_a");
    await assertSucceeds(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 9 })
    );
  });

  it("DENIES a supervisor creating a sard_record, even for an in-institute student (al_rasikhoon-801)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_new_sup"), {
        student_id: "stu_a",
        pages: 5,
      })
    );
  });

  it("DENIES a supervisor updating a sard_record, even for an in-institute student (al_rasikhoon-801)", async () => {
    const db = asUser("sup_a");
    await assertFails(
      updateDoc(doc(db, "sard_records", "sard_a"), { pages: 6 })
    );
  });

  it("DENIES an unauthenticated client writing a sard_record", async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, "sard_records", "sard_anon"), {
        student_id: "stu_a",
        pages: 1,
      })
    );
  });
});
```

(The trailing `});` above closes the file's outer `describe` — the block you deleted ended the file, so keep exactly one.)

Finally, fix the now-stale seed comment near the top of `beforeEach`:

```js
    // Teacher (no institute scoping on records — al_rasikhoon-ob7; used to
    // assert Sard is teacher-conducted, al_rasikhoon-801).
    await seed("users", "teacher_a", { role: "teacher", name: "Teacher A" });
```

- [ ] **Step 2: Run the rules tests to verify they fail**

```bash
cd test/rules && npm install && npm test
```

Expected: the two new `ALLOWS a teacher …` tests FAIL (the current rule denies teacher writes) and the two new `DENIES a supervisor …` tests FAIL (the current rule allows in-institute supervisor writes). The unauthenticated test passes already.

- [ ] **Step 3: Change the rule**

In `firestore.rules`, replace the whole `sard_records` match block (and its preceding comment) with:

```
    // Sard records — TEACHER-ONLY (al_rasikhoon-801). سرد is conducted by the
    // TEACHER; the supervisor conducts الاختبار (see exam_records below). This
    // REVERSES #29, which had made Sard supervisor-only: the supervisor write
    // is removed and the teacher write restored. SardRecordModel always named
    // its author `teacher_id` — model and rule now agree again.
    //
    // Teacher writes are unscoped, identical to session_records above: any
    // teacher may write any student's sard record. That is a real gap, tracked
    // in al_rasikhoon-ob7 (which tightens session_records and sard_records
    // together); it is NOT new here. Reads stay open (authenticated).
    match /sard_records/{sardId} {
      allow read: if isAuthenticated();
      allow create: if isTeacher();
      allow update: if isTeacher();
    }
```

- [ ] **Step 4: Run the rules tests to verify they pass**

```bash
cd test/rules && npm test
```

Expected: PASS — all tests green, including the untouched `session_records`, `exam_records`, students, and users cases.

- [ ] **Step 5: Update the README coverage list**

In `test/rules/README.md`, under `## Coverage`, replace the sard bullets so the doc matches the rule:

```markdown
- Supervisor repointing a `session_records` `student_id` to another institute → DENIED
- Teacher creating / updating a `sard_records` doc → ALLOWED (سرد is teacher-conducted, al_rasikhoon-801)
- Supervisor creating / updating a `sard_records` doc → DENIED, even in-institute
```

- [ ] **Step 6: Commit**

```bash
git add firestore.rules test/rules/firestore.rules.test.js test/rules/README.md
git commit -m "fix(al_rasikhoon-801): sard_records is teacher-written, not supervisor-written"
```

---

### Task 2: The teacher conducts Sard

Moves the two Sard screens into the teacher feature, re-homes their routes in the teacher shell, swaps them onto teacher-scoped providers, and gives the teacher the **بدء السرد** action.

After this task the supervisor's session-overview twin still exists but shows a *notice* instead of a Sard action — a correct interim state. Task 3 removes the twin entirely.

**Files:**
- Move: `lib/features/supervisor/screens/sard_session_screen.dart` → `lib/features/teacher/screens/sard_session_screen.dart`
- Move: `lib/features/supervisor/screens/sard_result_screen.dart` → `lib/features/teacher/screens/sard_result_screen.dart`
- Modify: `lib/routing/app_router.dart` (route constants, redirect guard, both shells' branches, imports)
- Modify: `lib/features/teacher/screens/session_overview_screen.dart` (Sard card action + notice)
- Test: `integration_test/helpers/test_robots.dart` (Sard methods move `SupervisorRobot` → `TeacherRobot`)
- Test: `integration_test/teacher_flow_test.dart` (blocked-from-Sard test becomes a full teacher Sard E2E)
- Test: `integration_test/supervisor_flow_test.dart` (three supervisor Sard tests migrate to the teacher)
- Test: `test/widget/result_grade_loading_test.dart`, `test/widget/sard_result_advance_warning_test.dart` (import path + provider overrides)

**Interfaces:**
- Consumes: teacher-scoped providers that already exist in `lib/features/teacher/providers/teacher_provider.dart`:
  - `studentProvider` — `FutureProvider.family<StudentWithUser?, String>`
  - `studentCurrentSessionProvider` — `FutureProvider.family<SessionModel?, String>`
  - `teacherStudentsProvider` — `FutureProvider<List<StudentWithUser>>`
- Produces, for Task 3:
  - `AppRoutes.sardSession == '/teacher/session/:studentId/sard'`
  - `AppRoutes.sardResult == '/teacher/session/:studentId/sard/result'`
  - `SessionOverviewScreen` still exposes `asSupervisor` (Task 3 deletes it)
  - `TeacherRobot.startSard()`, `.verifySardSession()`, `.enterSardErrors(int)`, `.finishSard()`, `.verifySardResult()`, `.saveSardResult()`, `.verifySardSaved()`

- [ ] **Step 1: Write the failing test — the teacher conducts a Sard end-to-end**

First move the Sard robot methods. In `integration_test/helpers/test_robots.dart`, **delete** from `SupervisorRobot` the entire block from the comment `// --- Sard (السرد) flow — supervisor-only since #29 …` through `verifySardSaved()`, EXCEPT keep `goToStudents()`, `verifyStudentsScreen()`, and `tapStudent(String)` — Task 3 still needs those for the supervisor's roster. Concretely, delete these `SupervisorRobot` methods: `verifySessionOverview`, `verifySardAvailableForSupervisor`, `startSard`, `verifySardSession`, `enterSardErrors`, `finishSard`, `verifySardResult`, `saveSardResult`, `verifySardSaved`.

Then in `TeacherRobot`, **replace** `verifySardBlockedForTeacher()` with the Sard flow:

```dart
  /// Verify the teacher is offered the Sard entry point (al_rasikhoon-801).
  ///
  /// سرد is conducted by the TEACHER. The "بدء السرد" action can sit below the
  /// fold on smaller screens, so scroll it into view before asserting.
  Future<void> verifySardAvailableForTeacher() async {
    await pumpAndSettle();
    final startButton = find.text('بدء السرد');
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpAndSettle();
    expect(startButton, findsOneWidget);
  }

  /// Start the Sard session from the session overview. Stays entirely inside
  /// the teacher shell.
  Future<void> startSard() async {
    final startButton = find.text('بدء السرد');
    await tester.scrollUntilVisible(
      startButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpAndSettle();
    await tester.tap(startButton);
    await pumpAndSettle();
  }

  /// Verify the Sard session screen is showing.
  Future<void> verifySardSession() async {
    await pumpAndSettle();
    expect(find.text('السرد'), findsWidgets);
  }

  /// Enter Sard errors by tapping the ErrorCounter add button N times.
  Future<void> enterSardErrors(int errors) async {
    for (int i = 0; i < errors; i++) {
      final addButtons = find.byIcon(Icons.add);
      await tester.tap(addButtons.last);
      await pumpAndSettle();
    }
  }

  /// Finish the Sard and navigate to the result screen.
  Future<void> finishSard() async {
    await tapByText('إنهاء السرد');
  }

  /// Verify the Sard result screen is showing.
  Future<void> verifySardResult() async {
    await pumpAndSettle();
    expect(find.text('نتيجة السرد'), findsOneWidget);
  }

  /// Save the Sard result. Stops one pump short of settling so the success
  /// snackbar is still on-screen for the assertion (it auto-dismisses).
  Future<void> saveSardResult() async {
    final finder = find.text('حفظ النتيجة');
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Verify the Sard was saved (success snackbar — passing or failing).
  Future<void> verifySardSaved() async {
    expect(find.textContaining('تم حفظ السرد'), findsOneWidget);
  }
```

Now in `integration_test/teacher_flow_test.dart`, **replace** the whole `'Teacher is blocked from Sard at a Sard session (#29 / #44)'` test with:

```dart
    testWidgets(
      'Teacher conducts a Sard end-to-end: start → conduct → save (al_rasikhoon-801)',
      (tester) async {
        // Arrange — سرد is conducted by the TEACHER (al_rasikhoon-801, which
        // reverses #29's supervisor-only rule). The whole flow — الطلاب →
        // session overview → السرد → نتيجة السرد — stays inside the teacher
        // shell, so no cross-shell push and no duplicate-page-key crash (#45).
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        final studentUser = env.createStudent(
          id: 'student_sard',
          name: 'طالب السرد',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        final studentId = await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          teacherId: teacher.id,
          // The hizb-59 سرد — session 30, as the DATA says (never "35").
          sessionId: 'L1_J30_S30',
        );

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب السرد');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();
        await teacherRobot.enterSardErrors(2);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();

        // Assert — the Sard saved, and the record names the TEACHER as its
        // author (sard_records.teacher_id was always the teacher's field).
        await teacherRobot.verifySardSaved();

        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(sardRecords.docs, hasLength(1));
        expect(sardRecords.docs.first.data()['teacher_id'], teacher.id);
      },
    );
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter devices   # copy the iOS simulator's id
flutter test integration_test/teacher_flow_test.dart -d <device-id>
```

Expected: FAIL — `verifySardAvailableForTeacher` finds no `بدء السرد` (the teacher still gets the supervisor-only notice).

- [ ] **Step 3: Move the Sard screens into the teacher feature**

```bash
git mv lib/features/supervisor/screens/sard_session_screen.dart lib/features/teacher/screens/sard_session_screen.dart
git mv lib/features/supervisor/screens/sard_result_screen.dart lib/features/teacher/screens/sard_result_screen.dart
```

In `lib/features/teacher/screens/sard_session_screen.dart`, swap the provider import and the session lookup. Replace the import line:

```dart
import '../providers/supervisor_provider.dart';
```

with:

```dart
import '../providers/teacher_provider.dart';
```

and replace the `sessionAsync` block at the top of `build` (comment included):

```dart
    // سرد is conducted by the TEACHER (al_rasikhoon-801). The student resolves
    // through the teacher-scoped studentProvider, the same lookup the rest of
    // the teacher's session flow uses.
    //
    // WHAT is being recited comes from the curriculum session the student
    // stands on: its verbatim label and its tier. A juz-tier سرد covers a whole
    // juz and a cumulative one the whole level, so neither can be called "the
    // hizb".
    final sessionAsync = ref.watch(
      studentCurrentSessionProvider(widget.studentId),
    );
```

In `lib/features/teacher/screens/sard_result_screen.dart`, make four edits. Swap the import:

```dart
import '../providers/teacher_provider.dart';
```

Replace the student lookup inside `_saveSard` (comment included):

```dart
      // سرد is conducted by the TEACHER (al_rasikhoon-801) — resolve the
      // student through the teacher-scoped lookup, like every other teacher
      // session flow.
      final studentAsync = await ref.read(
        studentProvider(widget.studentId).future,
      );
      if (studentAsync == null) throw Exception('Student not found');
```

Replace the invalidation + comment (`ref.invalidate(supervisorStudentsProvider); ref.invalidate(supervisorStudentProvider(...))`) with:

```dart
      // Invalidate the teacher's providers so the students list and the
      // resolved student reflect the advanced/incremented state.
      ref.invalidate(teacherStudentsProvider);
      ref.invalidate(studentProvider(widget.studentId));
```

Replace the post-save navigation (comment included):

```dart
        // Back to the teacher's students list — سرد is a teacher activity
        // (al_rasikhoon-801), so we always return to the teacher surface.
        context.go(AppRoutes.teacherStudents);
```

And in `build`, the watched provider:

```dart
    final studentAsync = ref.watch(studentProvider(widget.studentId));
```

Also fix the stale comment above `_saveSard`'s snackbar block: it says "the supervisor is told which" — change the word `supervisor` to `teacher`.

- [ ] **Step 4: Re-home the routes in the teacher shell**

In `lib/routing/app_router.dart`, delete the two Sard constants from the Supervisor block (lines 80-83) and their comment, so the Supervisor block ends at `supervisorSessionOverview` + `supervisorSettings`. Then in the Teacher block, add the two Sard routes after `sessionSummary`:

```dart
  // Sard (السرد) — TEACHER-conducted (al_rasikhoon-801, reversing #29). Lives
  // in the teacher shell alongside the rest of the session flow, so the whole
  // الطلاب → session-overview → السرد path is ONE shell (no #45 cross-shell
  // duplicate-page-key crash). The router redirect guards it; Firestore rules
  // are the true backstop.
  static const String sardSession = '/teacher/session/:studentId/sard';
  static const String sardResult = '/teacher/session/:studentId/sard/result';
```

Flip the redirect guard (currently lines 129-136):

```dart
      // Sard (السرد) is teacher-only (al_rasikhoon-801). Block any non-teacher
      // that reaches a teacher Sard path (e.g. a supervisor crafting the URL):
      // bounce them to their own dashboard. UI hides the entry point; this is
      // the navigation-level backstop. Firestore rules are the true backstop.
      if (state.matchedLocation.contains('/sard') &&
          userRole != UserRole.teacher) {
        return _getDashboardRoute(userRole);
      }
```

Delete the two `GoRoute`s for `AppRoutes.sardSession` and `AppRoutes.sardResult` from the **supervisor** shell's Branch 2 (leaving `supervisorStudents`, `supervisorAddStudent`, and `supervisorSessionOverview`), and add them to the **teacher** shell's Branch 0, after the `sessionSummary` route:

```dart
              // Sard (السرد) — teacher-conducted (al_rasikhoon-801). Registered
              // in the teacher shell's Students branch, so the push from the
              // session overview never crosses a shell boundary.
              GoRoute(
                path: AppRoutes.sardSession,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return SardSessionScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.sardResult,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final errorCount = state.extra as int? ?? 0;
                  return SardResultScreen(
                    studentId: studentId,
                    errorCount: errorCount,
                  );
                },
              ),
```

Finally fix the two imports — replace:

```dart
import '../features/supervisor/screens/sard_session_screen.dart';
import '../features/supervisor/screens/sard_result_screen.dart';
```

with:

```dart
import '../features/teacher/screens/sard_session_screen.dart';
import '../features/teacher/screens/sard_result_screen.dart';
```

- [ ] **Step 5: Give the teacher the بدء السرد action**

In `lib/features/teacher/screens/session_overview_screen.dart`, replace the `session.isSard` branch inside `build` (lines 142-155) with:

```dart
                    if (session.isSard) {
                      // سرد is conducted by the TEACHER (al_rasikhoon-801).
                      // This screen is still reachable by a supervisor via the
                      // institute-scoped students list, so the entry point is
                      // gated: the teacher gets the "بدء السرد" action, the
                      // supervisor a read-only notice.
                      return _buildSardCard(
                        context,
                        session,
                        studentId,
                        !asSupervisor,
                      );
                    }
```

Rename the fourth parameter of `_buildSardCard` from `bool isSupervisor` to `bool canConductSard`, and replace its action block:

```dart
          // سرد is teacher-conducted (al_rasikhoon-801). A supervisor viewing
          // this student sees a read-only notice — no action, no navigation.
          // Assessments have UNLIMITED retries, so there is no attempt cap to
          // gate on here — a student who cannot yet recite a juz keeps at it.
          if (!canConductSard)
            _buildSardTeacherOnlyMessage(context)
          else
            AppButton(
              text: 'بدء السرد',
              onPressed: () {
                context.push(
                  AppRoutes.sardSession.replaceFirst(':studentId', studentId),
                );
              },
              isFullWidth: true,
              backgroundColor: AppColors.info,
              icon: Icons.play_arrow,
            ),
```

Rename `_buildSardSupervisorOnlyMessage` to `_buildSardTeacherOnlyMessage` and change its one string:

```dart
              'السرد يُجرى مع المعلم',
```

Delete the now-unused `isSupervisorProvider` usage (`final isSupervisor = ref.watch(isSupervisorProvider);`). Leave the `user_provider.dart` import — `isSupervisorProvider` itself stays defined (other code may use it); only this screen stops watching it. If `flutter analyze` reports the import as unused, remove it.

- [ ] **Step 6: Migrate the supervisor's three Sard integration tests to the teacher**

In `integration_test/supervisor_flow_test.dart`, delete these three tests entirely:
- `'Supervisor conducts a Sard end-to-end: start → conduct → save (#29 / #45)'`
- `'a student placed on a JUZ-tier Sard is assessed with no prior sessions (#flexible-start)'`
- `'a supervisor conducts a CUMULATIVE (level-tier) Sard: the label names all three juz, and the record persists them'`

Keep every exam test, including `'a supervisor conducts a JUZ-tier اختبار from the queue…'`.

Now append the two curriculum-scope tests to `integration_test/teacher_flow_test.dart`, driven by the teacher. Note both students are created **with a `teacherId`** — a teacher-less student appears in no teacher's list at all (`al_rasikhoon-6bw`).

```dart
    testWidgets(
      'a student placed on a JUZ-tier Sard is assessed with no prior sessions '
      '(#flexible-start)',
      (tester) async {
        // A student arrives having already memorized juz 30, and is placed
        // directly on its juz-tier سرد — an assessment that belongs to NO hizb
        // and that the old model (hizb → 36 sessions, 35 = سرد) could not even
        // name. The app taught them none of it — they hold zero session records
        // — and the teacher must still be able to assess them.
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        // Place the student through the production path, not a seeded document.
        // The session they are placed on — L1_J30_S67, the juz-30 سرد — is one
        // the seeded curriculum really contains.
        final container = ProviderContainer(overrides: env.overrides.cast());
        addTearDown(container.dispose);
        final created = await container
            .read(studentRepositoryProvider)
            .createStudent(
              name: 'طالب حافظ',
              username: 'placed_student',
              password: 'secret123',
              instituteId: instituteId,
              // The teacher conducts سرد (al_rasikhoon-801), so the student
              // must HAVE a teacher — a teacher-less student shows up in no
              // teacher's list at all (al_rasikhoon-6bw).
              teacherId: teacher.id,
              startingPosition: const CurriculumPosition(
                level: 1,
                juz: 30,
                session: 67,
              ),
            );

        // The anchor, and the facts copied from the curriculum, are persisted.
        final doc = await env.fakeFirestore
            .collection('students')
            .doc(created.student.id)
            .get();
        expect(doc.data()?['current_level'], 1);
        expect(doc.data()?['current_juz'], 30);
        expect(doc.data()?['current_session'], 67);
        expect(doc.data()?['current_session_id'], 'L1_J30_S67');
        expect(doc.data()?['current_session_kind'], 'sard');
        // A juz-tier سرد has no hizb at all — and the student's label is null,
        // not a fabricated 59.
        expect(doc.data()?['current_session_tier'], 'juz');
        expect(doc.data()?['current_hizb'], isNull);
        expect(doc.data()?['enrollment_position'], {
          'level': 1,
          'juz': 30,
          'session': 67,
        });

        // They hold no session records at all — nothing was taught in the app.
        final records = await env.fakeFirestore
            .collection('session_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(records.docs, isEmpty);

        // The teacher conducts their سرد end-to-end regardless.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب حافظ');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();

        // The teacher can SEE what is being assessed: the curriculum's own
        // words for it — a whole juz, not "the hizb".
        expect(
          find.text('سرد الجزء رقم 30 كاملًا على المحفظ المتابع'),
          findsWidgets,
        );

        await teacherRobot.enterSardErrors(2);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();
        await teacherRobot.verifySardSaved();

        // And the record carries the assessment's SCOPE — the thing a
        // hizb-keyed record could never represent.
        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J30_S67');
        expect(sard['tier'], 'juz');
        expect(sard['juz_numbers'], [30]);
        expect(sard['hizb_number'], isNull);
        expect(
          sard['scope_label_ar'],
          'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
        );
      },
    );

    testWidgets(
      'a teacher conducts a CUMULATIVE (level-tier) Sard: the label names all '
      'three juz, and the record persists them',
      (tester) async {
        // The last سرد of level 1 covers juz 28, 29 AND 30 — the level entire.
        // Nothing about it can be expressed as "the hizb".
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        final studentUser = env.createStudent(
          id: 'cumulative_student',
          name: 'طالب السرد التراكمي',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        final studentId = await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          teacherId: teacher.id,
          sessionId: 'L1_J28_S66', // the level's cumulative سرد
        );

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب السرد التراكمي');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();

        // The scope is stated verbatim, and the instruction is worded for the
        // TIER — the whole level, not a hizb.
        expect(
          find.text(
            'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
          ),
          findsWidgets,
        );
        expect(find.textContaining('الأجزاء 28 و 29 و 30'), findsWidgets);

        await teacherRobot.enterSardErrors(1);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();
        await teacherRobot.verifySardSaved();

        // The record names all three juz — a cumulative سرد covers the level.
        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J28_S66');
        expect(sard['tier'], 'cumulative');
        expect(sard['juz_numbers'], [28, 29, 30]);
        expect(
          sard['scope_label_ar'],
          'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
        );
        expect(sard['teacher_id'], teacher.id);
      },
    );
```

The juz-tier test above places its student through `studentRepository.createStudent` (the production placement path), so copy these imports from `integration_test/supervisor_flow_test.dart` into `integration_test/teacher_flow_test.dart` if they are not already there: `flutter_riverpod`, `studentRepositoryProvider`, and `CurriculumPosition`. The cumulative test needs none of them — it seeds through `env.addStudent`.

- [ ] **Step 7: Re-point the two widget tests**

In `test/widget/result_grade_loading_test.dart` and `test/widget/sard_result_advance_warning_test.dart`, change the import:

```dart
import 'package:al_rasikhoon/features/teacher/screens/sard_result_screen.dart';
```

In `result_grade_loading_test.dart`, the Sard case overrides `supervisorStudentProvider`; swap it for the teacher-scoped provider and fix the comment:

```dart
            // SardResultScreen resolves its student through the teacher-scoped
            // studentProvider (سرد is teacher-conducted, al_rasikhoon-801).
            studentProvider.overrideWith((ref, id) => pending.future),
```

Leave the `examStudentProvider` override in the exam case untouched. Add `import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';` if absent, and drop the supervisor-provider import if nothing else in the file uses it.

In `sard_result_advance_warning_test.dart`, replace the two supervisor overrides:

```dart
          studentProvider.overrideWith(
            (ref, id) async => studentWithUser,
          ),
          teacherStudentsProvider.overrideWith((ref) async => []),
```

matching the existing override's argument shape, and change `currentUserProvider.overrideWithValue(supervisor)` to a teacher user (rename the local from `supervisor` to `teacher` and build it with the teacher role — mirror how `env.createTeacher()`/the file's existing `UserModel` construction sets `role`).

- [ ] **Step 8: Run all the tests to verify they pass**

```bash
flutter analyze
flutter test test/widget/result_grade_loading_test.dart test/widget/sard_result_advance_warning_test.dart
flutter test integration_test/teacher_flow_test.dart -d <device-id>
flutter test integration_test/supervisor_flow_test.dart -d <device-id>
```

Expected: `flutter analyze` clean; all four suites PASS. The teacher now drives Sard end-to-end and the supervisor suite has no Sard tests left.

- [ ] **Step 9: Commit**

```bash
git add lib/routing/app_router.dart lib/features/teacher lib/features/supervisor integration_test test/widget
git commit -m "feat(al_rasikhoon-801): the teacher conducts السرد, in the teacher shell"
```

---

### Task 3: The supervisor's student detail becomes a read-only progress screen

Removes the supervisor's last Sard doorway. The supervisor keeps its institute-scoped الطلاب roster (#28) and gains a read-only progress view; the session-overview twin is deleted.

**Files:**
- Create: `lib/shared/screens/student_progress_screen.dart` (moved out of admin, providers injected)
- Delete: `lib/features/admin/screens/admin_student_progress_screen.dart`
- Modify: `lib/features/supervisor/providers/supervisor_provider.dart` (add the session-history provider)
- Modify: `lib/routing/app_router.dart` (wire both progress routes; delete `supervisorSessionOverview`)
- Modify: `lib/features/supervisor/screens/supervisor_students_screen.dart` (tap → progress route)
- Modify: `lib/features/teacher/screens/session_overview_screen.dart` (drop `asSupervisor` and the notice)
- Test: `integration_test/supervisor_flow_test.dart` (add: supervisor cannot conduct a Sard)

**Interfaces:**
- Consumes from Task 2: `SessionOverviewScreen` still has an `asSupervisor` field — this task deletes it. `AppRoutes.sardSession` / `sardResult` are teacher-shell paths.
- Produces:
  - `StudentProgressScreen({required String studentId, required FutureProvider<StudentWithUser?> Function(String) ...})` — see the exact signature in Step 3.
  - `supervisorStudentSessionHistoryProvider` — `FutureProvider.family<List<SessionRecordModel>, String>`

- [ ] **Step 1: Write the failing test**

In `integration_test/supervisor_flow_test.dart`, add:

```dart
    testWidgets(
      'a supervisor cannot conduct a Sard: tapping a student shows read-only '
      'progress, with no سرد action anywhere (al_rasikhoon-801)',
      (tester) async {
        // سرد is teacher-conducted (al_rasikhoon-801). The supervisor keeps its
        // institute-scoped roster (#28) but has NO Sard doorway: tapping a
        // student lands on the read-only progress screen, which never offers an
        // action that would start, advance, or end a session.
        const instituteId = 'sard_denied_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'sup_sard_denied_student',
          name: 'طالب المشرف',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          // The hizb-59 سرد — the exact session a supervisor used to be able to
          // conduct under #29.
          sessionId: 'L1_J30_S30',
        );

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب المشرف');
        await supervisorRobot.pumpAndSettle();

        // Assert — the read-only progress screen, and no Sard action at all.
        expect(find.text('تقدم الطالب'), findsOneWidget);
        expect(find.text('بدء السرد'), findsNothing);
        expect(find.text('بدء الحلقة'), findsNothing);
      },
    );
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test integration_test/supervisor_flow_test.dart -d <device-id>
```

Expected: FAIL — tapping the student still opens the session-overview twin (`الحلقة`), so `تقدم الطالب` is not found.

- [ ] **Step 3: Promote the admin progress screen to a shared, provider-injected screen**

```bash
git mv lib/features/admin/screens/admin_student_progress_screen.dart lib/shared/screens/student_progress_screen.dart
```

In the moved file, fix the relative imports (one level shallower: `../../data/...`, `../curriculum/assessment_copy.dart`, `../widgets/app_card.dart`, `../widgets/student_level_progress.dart`, `../../routing/app_router.dart`) and **delete** `import '../providers/admin_provider.dart';` — the screen no longer knows any feature's providers.

Replace the `AdminStudentProgressScreen` class and the `_ProgressBody` class with:

```dart
/// Read-only student progress view. Mirrors what a teacher sees for their own
/// student in `SessionOverviewScreen`, but never offers any action that would
/// start, advance, or end a session.
///
/// Role-agnostic by construction: the three providers it reads are INJECTED by
/// the router (the composition root), so the admin gets its unscoped providers
/// and the supervisor its institute-scoped ones (AgDR-0003) without this screen
/// importing either feature.
class StudentProgressScreen extends ConsumerWidget {
  final String studentId;
  final FutureProviderFamily<StudentWithUser?, String> studentProvider;
  final FutureProviderFamily<SessionModel?, String> currentSessionProvider;
  final FutureProviderFamily<List<SessionRecordModel>, String>
  sessionHistoryProvider;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.studentProvider,
    required this.currentSessionProvider,
    required this.sessionHistoryProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentAsync = ref.watch(studentProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('تقدم الطالب')),
      body: studentAsync.when(
        data: (studentWithUser) {
          if (studentWithUser == null) {
            return const Center(child: Text('الطالب غير موجود'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(studentId));
              ref.invalidate(currentSessionProvider(studentId));
              ref.invalidate(sessionHistoryProvider(studentId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _ProgressBody(
                studentWithUser: studentWithUser,
                currentSessionProvider: currentSessionProvider,
                sessionHistoryProvider: sessionHistoryProvider,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  final StudentWithUser studentWithUser;
  final FutureProviderFamily<SessionModel?, String> currentSessionProvider;
  final FutureProviderFamily<List<SessionRecordModel>, String>
  sessionHistoryProvider;

  const _ProgressBody({
    required this.studentWithUser,
    required this.currentSessionProvider,
    required this.sessionHistoryProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = studentWithUser.student;
    final user = studentWithUser.user;
    final sessionAsync = ref.watch(currentSessionProvider(student.id));
    final historyAsync = ref.watch(sessionHistoryProvider(student.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudentHeaderCard(user: user, student: student),
        const SizedBox(height: 24),

        Text('الحلقة الحالية', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        sessionAsync.when(
          data: (session) => _CurrentSessionCard(session: session),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),

        const SizedBox(height: 24),

        Text(
          'التقدم في المستوى',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AppCard(
          child: StudentLevelProgress(
            level: student.currentLevel,
            orderInLevel: student.currentOrderInLevel,
          ),
        ),

        const SizedBox(height: 24),

        Text('سجل الحلقات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        historyAsync.when(
          data: (records) => _SessionHistoryList(records: records),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}
```

Leave `_StudentHeaderCard`, `_CurrentSessionCard`, `_SimpleSessionCard`, `_PartTile`, and `_SessionHistoryList` exactly as they are — but in `_CurrentSessionCard`, the سرد subtitle is now the teacher's job, so leave `session.assessmentInstructionAr` (already role-neutral) untouched, and leave the اختبار subtitle `'في انتظار المشرف لإجراء الاختبار'` untouched — that one is still true.

`FutureProviderFamily<T, Arg>` is the type of a `FutureProvider.family<T, Arg>`; calling it with the arg yields the provider to watch.

- [ ] **Step 4: Add the supervisor's session-history provider**

In `lib/features/supervisor/providers/supervisor_provider.dart`, add after `supervisorStudentCurrentSessionProvider`:

```dart
/// Recent session records for a student in the supervisor's institute — the
/// history half of the supervisor's read-only progress view (al_rasikhoon-801).
/// Reads are not institute-scoped at the repository level (al_rasikhoon-bpk);
/// the SCREEN only ever asks for a student the institute-scoped
/// [supervisorStudentProvider] already resolved.
final supervisorStudentSessionHistoryProvider =
    FutureProvider.family<List<SessionRecordModel>, String>((
      ref,
      studentId,
    ) async {
      final repo = ref.watch(sessionRepositoryProvider);
      return repo.getSessionRecordsForStudent(studentId, limit: 50);
    });
```

Add the import `import '../../../data/models/session_record_model.dart';` at the top.

- [ ] **Step 5: Wire both progress routes and delete the supervisor twin**

In `lib/routing/app_router.dart`:

Replace the imports:

```dart
import '../features/admin/screens/admin_student_progress_screen.dart';
```

with:

```dart
import '../shared/screens/student_progress_screen.dart';
```

and add the two provider imports the router now wires:

```dart
import '../features/admin/providers/admin_provider.dart';
import '../features/supervisor/providers/supervisor_provider.dart';
```

Delete the `supervisorSessionOverview` constant and its comment, and add in its place:

```dart
  // Supervisor student detail — READ-ONLY progress (al_rasikhoon-801). The
  // session-overview twin that used to live here existed only as the doorway
  // into Sard; سرد is teacher-conducted now, so the supervisor gets progress,
  // never an action.
  static const String supervisorStudentProgress =
      '/supervisor/students/:studentId';
```

In the **admin** shell's Branch 0, replace the `adminStudentProgress` builder:

```dart
              GoRoute(
                path: AppRoutes.adminStudentProgress,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StudentProgressScreen(
                    studentId: id,
                    studentProvider: adminStudentProvider,
                    currentSessionProvider: adminStudentCurrentSessionProvider,
                    sessionHistoryProvider: adminStudentSessionHistoryProvider,
                  );
                },
              ),
```

In the **supervisor** shell's Branch 2, replace the `supervisorSessionOverview` `GoRoute` with:

```dart
              // Read-only progress — registered AFTER the literal `add` route so
              // `/supervisor/students/add` still matches AddStudentScreen.
              GoRoute(
                path: AppRoutes.supervisorStudentProgress,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return StudentProgressScreen(
                    studentId: studentId,
                    studentProvider: supervisorStudentProvider,
                    currentSessionProvider:
                        supervisorStudentCurrentSessionProvider,
                    sessionHistoryProvider:
                        supervisorStudentSessionHistoryProvider,
                  );
                },
              ),
```

Delete the now-unused `import '../features/teacher/screens/session_overview_screen.dart';`? **No** — the teacher shell still uses `SessionOverviewScreen`. Keep it.

- [ ] **Step 6: Point the supervisor's student card at the progress route**

In `lib/features/supervisor/screens/supervisor_students_screen.dart`, replace the `onTap` body:

```dart
                      onTap: () {
                        // Read-only progress (al_rasikhoon-801). The supervisor
                        // conducts الاختبار, never سرد, so a student tap leads
                        // to progress — not to a screen with session actions.
                        context.push(
                          AppRoutes.supervisorStudentProgress.replaceFirst(
                            ':studentId',
                            studentWithUser.student.id,
                          ),
                        );
                      },
```

- [ ] **Step 7: Drop `asSupervisor` from the session overview**

The supervisor can no longer reach `SessionOverviewScreen`, so its role branch is dead code. In `lib/features/teacher/screens/session_overview_screen.dart`:

- Delete the `asSupervisor` field, its doc comment, and its constructor entry.
- Replace the two ternaries in `build` with the teacher-scoped providers only:

```dart
    final studentAsync = ref.watch(studentProvider(studentId));
    final sessionAsync = ref.watch(studentCurrentSessionProvider(studentId));
```

- Simplify the `session.isSard` branch to:

```dart
                    if (session.isSard) {
                      // سرد is conducted by the TEACHER (al_rasikhoon-801), and
                      // only a teacher reaches this screen.
                      return _buildSardCard(context, session, studentId);
                    }
```

- Drop `_buildSardCard`'s `canConductSard` parameter and its `if (!canConductSard) … else` — the `AppButton` is now unconditional. Delete `_buildSardTeacherOnlyMessage` entirely.
- Delete the `import '../../supervisor/providers/supervisor_provider.dart';` line — nothing in the screen resolves through the supervisor scope any more.

Leave `_buildExamCard` and its `'يرجى توجيه الطالب للمشرف لإجراء الاختبار'` notice exactly as they are: a teacher who reaches an اختبار still hands the student to the supervisor.

- [ ] **Step 8: Run the tests to verify they pass**

```bash
flutter analyze
flutter test
flutter test integration_test/supervisor_flow_test.dart -d <device-id>
flutter test integration_test/teacher_flow_test.dart -d <device-id>
flutter test integration_test/student_flow_test.dart -d <device-id>
```

Expected: `flutter analyze` clean (no unused imports, no dead `asSupervisor` references); every suite PASS. If a widget test referenced `AdminStudentProgressScreen` by name, update it to `StudentProgressScreen` with the three admin providers passed in.

- [ ] **Step 9: Commit**

```bash
git add lib integration_test test
git commit -m "feat(al_rasikhoon-801): the supervisor gets read-only student progress, not a Sard doorway"
```

---

### Task 4: Verify end-to-end and close out

**Files:**
- Modify: `docs/superpowers/specs/2026-07-14-sard-teacher-exam-supervisor-design.md` (status line only)

- [ ] **Step 1: Full verification sweep**

```bash
flutter analyze
flutter test
cd test/rules && npm test && cd ../..
flutter test integration_test/teacher_flow_test.dart -d <device-id>
flutter test integration_test/supervisor_flow_test.dart -d <device-id>
flutter test integration_test/student_flow_test.dart -d <device-id>
```

Expected: all green.

- [ ] **Step 2: Grep for stragglers**

```bash
grep -rn "supervisor-only\|supervisorSessionOverview\|verifySardBlockedForTeacher\|verifySardAvailableForSupervisor\|AdminStudentProgressScreen\|_buildSardSupervisorOnlyMessage" lib test integration_test
```

Expected: no hits. Any hit is a stale comment or a dead symbol — fix it.

```bash
grep -rn "السرد يُجرى مع المشرف فقط" lib test integration_test
```

Expected: no hits — the supervisor-only Sard notice is gone from the app entirely.

- [ ] **Step 3: Drive the real app (do not skip)**

Use the `verify` skill: sign in as a teacher whose student sits on `L1_J30_S30`, confirm **بدء السرد** appears and the whole سرد → نتيجة السرد → save path works; then sign in as a supervisor, confirm tapping a student shows **تقدم الطالب** with no session action, and that the الاختبارات queue still conducts an exam end-to-end.

- [ ] **Step 4: Mark the spec implemented and close the issue**

Change the spec's status line to:

```markdown
**Status:** Implemented — al_rasikhoon-801
```

```bash
git add docs/superpowers/specs/2026-07-14-sard-teacher-exam-supervisor-design.md
git commit -m "docs(al_rasikhoon-801): mark the sard/exam role swap implemented"
bd close al_rasikhoon-801
git pull --rebase && bd dolt push && git push && git status
```

`al_rasikhoon-6bw` (teacher-less students) and `al_rasikhoon-ob7` (unscoped teacher record writes) stay OPEN — they are deliberately out of scope.
