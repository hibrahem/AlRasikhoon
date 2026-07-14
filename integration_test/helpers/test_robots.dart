import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_students_screen.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_history_screen.dart';
import 'package:al_rasikhoon/features/settings/screens/settings_screen.dart';

/// Base robot class for E2E testing
abstract class TestRobot {
  final WidgetTester tester;

  TestRobot(this.tester);

  /// Wait for widgets to settle
  Future<void> pumpAndSettle() async {
    await tester.pumpAndSettle();
  }

  /// Tap a widget by key
  Future<void> tapByKey(String key) async {
    await tester.tap(find.byKey(Key(key)));
    await pumpAndSettle();
  }

  /// Tap a widget by text
  Future<void> tapByText(String text) async {
    await tester.tap(find.text(text));
    await pumpAndSettle();
  }

  /// Scroll the nearest Scrollable until [text] is visible, then tap it.
  Future<void> scrollAndTapByText(String text) async {
    final finder = find.text(text);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
    await pumpAndSettle();
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Tap a widget by icon
  Future<void> tapByIcon(IconData icon) async {
    await tester.tap(find.byIcon(icon));
    await pumpAndSettle();
  }

  /// Push a raw location onto the router, as if the caller had crafted the
  /// URL directly (bypassing any in-app navigation UI). Used to exercise the
  /// router's redirect guard directly. Any on-screen widget works as the
  /// BuildContext, since it is a descendant of the app's Router and can walk
  /// up to find the GoRouter it belongs to; Scaffold is present on every
  /// screen.
  Future<void> pushLocation(String location) async {
    final context = tester.element(find.byType(Scaffold).first);
    GoRouter.of(context).push(location);
    await pumpAndSettle();
  }

  /// Enter text in a field by key
  Future<void> enterTextByKey(String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await pumpAndSettle();
  }

  /// Enter text in the first TextField
  Future<void> enterTextInFirstField(String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await pumpAndSettle();
  }

  /// Check if text is displayed
  bool isTextDisplayed(String text) {
    return find.text(text).evaluate().isNotEmpty;
  }

  /// Check if widget with key exists
  bool isKeyDisplayed(String key) {
    return find.byKey(Key(key)).evaluate().isNotEmpty;
  }

  /// Scroll until widget is visible
  Future<void> scrollUntilVisible(Finder finder, {double delta = 100}) async {
    await tester.scrollUntilVisible(finder, delta);
    await pumpAndSettle();
  }
}

/// Robot for authentication flows (username + password)
class AuthRobot extends TestRobot {
  AuthRobot(super.tester);

  /// Bounded settle: pump a fixed number of frames at a fixed interval
  /// instead of `pumpAndSettle()`, which loops until the binding reports
  /// no scheduled frames. On the Galaxy Note 8 (Android 9 / API 28) a
  /// long-lived auth-listener subscription keeps the frame ticker from
  /// ever idling, so `pumpAndSettle()` never returns (issue #5). The
  /// auth listener stream is now finite (see `_TestFirebaseService` in
  /// test_app.dart) AND the wait here is explicitly bounded so a future
  /// regression of the same shape cannot reintroduce an infinite hang.
  /// 30 × 100ms = 3s of settle budget — comfortably longer than the
  /// login screen's first-frame layout + localisation resolution, with
  /// no upper-bound dependency on scheduler idleness.
  Future<void> _settleBounded({
    int frames = 30,
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(interval);
    }
  }

  /// Wait until [finder] resolves to at least one widget, pumping a
  /// bounded number of frames. Throws via the final `expect` if the
  /// widget never appears within the budget — keeps the assertion
  /// strength identical to the previous `pumpAndSettle()` + `expect`.
  Future<void> _pumpUntilFound(
    Finder finder, {
    int frames = 30,
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(interval);
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  /// Verify we're on the login screen.
  ///
  /// Uses bounded pumps + an explicit wait for the login title instead of
  /// `pumpAndSettle()` (see [_settleBounded]). Assertions are unchanged —
  /// both texts must resolve to exactly one widget.
  Future<void> verifyLoginScreen() async {
    await _pumpUntilFound(find.text('الراسخون'));
    await _settleBounded();
    expect(find.text('الراسخون'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  }

  /// Enter username (first text field)
  Future<void> enterUsername(String username) async {
    final usernameField = find.byType(TextFormField).first;
    await tester.enterText(usernameField, username);
    await pumpAndSettle();
  }

  /// Enter password (second text field)
  Future<void> enterPassword(String password) async {
    final passwordField = find.byType(TextFormField).at(1);
    await tester.enterText(passwordField, password);
    await pumpAndSettle();
  }

  /// Tap login button
  Future<void> tapLogin() async {
    await tapByText('تسجيل الدخول');
  }

  /// Verify account not found screen.
  /// Bounded wait for the target text (see [_settleBounded]); assertion
  /// unchanged.
  Future<void> verifyAccountNotFoundScreen() async {
    await _pumpUntilFound(find.textContaining('غير مسجل'));
    await _settleBounded();
    expect(find.textContaining('غير مسجل'), findsOneWidget);
  }

  /// Verify error message displayed.
  /// Bounded wait for the target text (see [_settleBounded]); assertion
  /// unchanged.
  Future<void> verifyErrorMessage(String message) async {
    await _pumpUntilFound(find.text(message));
    await _settleBounded();
    expect(find.text(message), findsOneWidget);
  }
}

/// Robot for admin flows
class AdminRobot extends TestRobot {
  AdminRobot(super.tester);

  /// Verify admin dashboard
  Future<void> verifyDashboard() async {
    await pumpAndSettle();
    expect(find.text('مرحباً، مدير النظام'), findsOneWidget);
  }

  /// Navigate to institutes via bottom nav
  Future<void> goToInstitutes() async {
    final navBar = find.byType(BottomNavigationBar);
    final instituteIcon = find.descendant(
      of: navBar,
      matching: find.text('المعاهد'),
    );
    await tester.tap(instituteIcon);
    await pumpAndSettle();
  }

  /// Navigate to teachers via bottom nav
  Future<void> goToTeachers() async {
    final navBar = find.byType(BottomNavigationBar);
    final teacherIcon = find.descendant(
      of: navBar,
      matching: find.text('المعلمون'),
    );
    await tester.tap(teacherIcon);
    await pumpAndSettle();
  }

  /// Navigate to curriculum via bottom nav
  Future<void> goToCurriculum() async {
    final navBar = find.byType(BottomNavigationBar);
    final curriculumIcon = find.descendant(
      of: navBar,
      matching: find.text('المنهج'),
    );
    await tester.tap(curriculumIcon);
    await pumpAndSettle();
  }

  /// Tap create institute FAB
  Future<void> tapCreateInstitute() async {
    await tapByIcon(Icons.add);
  }

  /// Fill institute form
  Future<void> fillInstituteForm({
    required String name,
    required String location,
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), location);
    await pumpAndSettle();
  }

  /// Submit create institute form
  Future<void> submitForm() async {
    await tapByText('إنشاء المعهد');
  }

  /// Submit add teacher form
  Future<void> submitTeacherForm() async {
    await tapByText('إضافة المعلم');
  }

  /// Verify institute in list
  Future<void> verifyInstituteInList(String name) async {
    await pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  }

  /// Tap on institute
  Future<void> tapInstitute(String name) async {
    await tapByText(name);
  }

  /// Verify institute detail screen
  Future<void> verifyInstituteDetail(String name) async {
    await pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  }

  /// Tap assign teacher
  Future<void> tapAssignTeacher() async {
    await tapByText('إضافة معلم');
  }

  /// Tap add teacher FAB
  Future<void> tapAddTeacher() async {
    await tapByIcon(Icons.add);
  }

  /// Fill the add-teacher form.
  ///
  /// The form (see `AddTeacherScreen`) has four *required*, validated fields in
  /// this order — name, username, password, confirm-password — followed by an
  /// optional phone field. Earlier this robot filled only fields 0 and 1 and
  /// passed an email into field 1; field 1 is the **username** (which rejects
  /// `@`), and the password / confirm-password fields were left empty. Form
  /// validation therefore always failed, `_handleCreate` returned early, the
  /// account was never provisioned and the screen never popped — which is why
  /// "Admin can add a new teacher" failed at `verifyTeacherInList` (issue #46).
  ///
  /// We now fill all four required fields with values that satisfy the
  /// validators ([Validators.validateUsername] requires `^[a-z0-9_.]+$`,
  /// [Validators.validatePassword] requires ≥ 6 chars, confirm must match).
  /// [email] is kept as the public parameter name for call-site stability but
  /// is no longer entered into the username field; a deterministic username is
  /// derived from it instead.
  Future<void> fillTeacherForm({
    required String name,
    required String email,
    String? phone,
    String username = 'teacher1',
    String password = 'password123',
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name); // name
    await tester.enterText(textFields.at(1), username); // username
    await tester.enterText(textFields.at(2), password); // password
    await tester.enterText(textFields.at(3), password); // confirm password
    if (phone != null && textFields.evaluate().length > 4) {
      await tester.enterText(textFields.at(4), phone);
    }
    await pumpAndSettle();
  }

  /// Verify the newly added teacher appears in the teachers list.
  ///
  /// After a successful add, `AddTeacherScreen` runs a bounded server-side
  /// read-after-write confirmation (`getTeachersConfirmingUid`, ~5 × 300ms of
  /// real `Future.delayed`) *before* invalidating `allTeachersProvider`,
  /// popping back to the list, and the list re-fetching asynchronously (#21).
  /// A single `pumpAndSettle()` cannot drive that real-time async chain
  /// (`pumpAndSettle` does not advance wall-clock timers, and the work runs
  /// outside the fake-async zone), so the assertion raced the refresh and
  /// flaked/failed.
  ///
  /// Instead we pump in a bounded loop, advancing real time via
  /// `tester.runAsync` so the `Future.delayed`-based confirmation poll and the
  /// provider re-fetch can actually complete, checking for the teacher name on
  /// each iteration. The budget (~5s) comfortably exceeds the confirmation
  /// poll's worst case; the final `expect` keeps the assertion strength
  /// identical to the previous `pumpAndSettle()` + `expect`.
  Future<void> verifyTeacherInList(
    String name, {
    int attempts = 25,
    Duration interval = const Duration(milliseconds: 200),
  }) async {
    await pumpAndSettle();
    for (var i = 0; i < attempts; i++) {
      if (find.text(name).evaluate().isNotEmpty) break;
      await tester.runAsync(() => Future<void>.delayed(interval));
      await pumpAndSettle();
    }
    expect(find.text(name), findsOneWidget);
  }

  /// Tap edit institute button (icon in AppBar)
  Future<void> tapEditInstitute() async {
    await tapByIcon(Icons.edit);
  }

  /// Fill edit institute form
  Future<void> fillEditInstituteForm({
    required String name,
    required String location,
  }) async {
    final textFields = find.byType(TextField);
    // Clear and enter new values
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), location);
    await pumpAndSettle();
  }

  /// Save edit changes
  Future<void> saveChanges() async {
    await tapByText('حفظ التغييرات');
  }
}

/// Robot for teacher flows
class TeacherRobot extends TestRobot {
  TeacherRobot(super.tester);

  /// Verify teacher students screen
  Future<void> verifyStudentsScreen() async {
    await pumpAndSettle();
    expect(find.text('طلابي'), findsOneWidget);
    expect(find.byType(TeacherStudentsScreen), findsOneWidget);
  }

  /// Tap add student FAB
  Future<void> tapAddStudent() async {
    await tapByIcon(Icons.person_add);
  }

  /// Fill student form (name + email + optional phone/guardian)
  Future<void> fillStudentForm({
    required String name,
    required String email,
    String? phone,
    String? guardianEmail,
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), email);
    if (phone != null && textFields.evaluate().length > 2) {
      await tester.enterText(textFields.at(2), phone);
    }
    await pumpAndSettle();
  }

  /// Submit student form
  Future<void> submitStudentForm() async {
    await tapByText('إضافة الطالب');
  }

  /// Verify student in list
  Future<void> verifyStudentInList(String name) async {
    await pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  }

  /// Tap on student
  Future<void> tapStudent(String name) async {
    await tapByText(name);
  }

  /// Verify session overview screen
  Future<void> verifySessionOverview() async {
    await pumpAndSettle();
    expect(find.textContaining('الحلقة'), findsWidgets);
  }

  /// Start session
  Future<void> startSession() async {
    await tapByText('بدء الحلقة');
  }

  /// Set error count by tapping the add button N times
  Future<void> enterErrorCount(int errors) async {
    // The ErrorCounter uses an InkWell with Icons.add to increment
    // Find the add button within the ErrorCounter
    for (int i = 0; i < errors; i++) {
      final addButtons = find.byIcon(Icons.add);
      // The last Icons.add is usually the error counter's add button
      // (not the FAB)
      await tester.tap(addButtons.last);
      await pumpAndSettle();
    }
  }

  /// Submit recitation and go to result (parts 1-2: "التالي", part 3: "إنهاء التسميع")
  Future<void> submitRecitation({required int part}) async {
    if (part < 3) {
      await tapByText('التالي');
    } else {
      await tapByText('إنهاء التسميع');
    }
  }

  /// Go to next part from the result screen (parts 1-2)
  Future<void> goToNextPart() async {
    // The button text is "التالي: [part title]", find by prefix
    final nextButton = find.textContaining('التالي:');
    await tester.tap(nextButton.first);
    await pumpAndSettle();
  }

  /// Go to session summary from part 3 result screen
  Future<void> goToSessionSummary() async {
    await tapByText('عرض ملخص الحلقة');
  }

  /// Verify grade displayed
  Future<void> verifyGrade(String gradeAr) async {
    await pumpAndSettle();
    expect(find.textContaining(gradeAr), findsWidgets);
  }

  /// Save and complete session from summary screen.
  /// The button can be below the fold; scroll into view first.
  Future<void> completeSession() async {
    await scrollAndTapByText('حفظ وإنهاء الحلقة');
  }

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

  // --- Bottom nav (al_rasikhoon-256) ---------------------------------------
  // The teacher shell has exactly three tabs — الطلاب / السجل / الإعدادات —
  // each backed by its own StatefulShellBranch. Tap them the way a user
  // actually would: through the BottomNavigationBar, mirroring the
  // Admin/SupervisorRobot nav helpers above.

  /// Navigate to the students tab via bottom nav.
  Future<void> goToStudents() async {
    final navBar = find.byType(BottomNavigationBar);
    final studentsTab = find.descendant(
      of: navBar,
      matching: find.text('الطلاب'),
    );
    await tester.tap(studentsTab);
    await pumpAndSettle();
  }

  /// Navigate to the history tab via bottom nav.
  Future<void> goToHistory() async {
    final navBar = find.byType(BottomNavigationBar);
    final historyTab = find.descendant(
      of: navBar,
      matching: find.text('السجل'),
    );
    await tester.tap(historyTab);
    await pumpAndSettle();
  }

  /// Navigate to the settings tab via bottom nav.
  Future<void> goToSettings() async {
    final navBar = find.byType(BottomNavigationBar);
    final settingsTab = find.descendant(
      of: navBar,
      matching: find.text('الإعدادات'),
    );
    await tester.tap(settingsTab);
    await pumpAndSettle();
  }

  /// Verify the history screen (TeacherHistoryScreen) is showing and the
  /// students screen is gone.
  ///
  /// 'السجل' is both the nav tab's own label AND the screen's AppBar title,
  /// so a bare `find.text('السجل')` would match both and never resolve to
  /// exactly one widget — assert on the screen widget type instead, which is
  /// unambiguous.
  Future<void> verifyHistoryScreen() async {
    await pumpAndSettle();
    expect(find.byType(TeacherHistoryScreen), findsOneWidget);
    expect(find.byType(TeacherStudentsScreen), findsNothing);
  }

  /// Verify the settings screen (SettingsScreen) is showing and the students
  /// screen is gone. See [verifyHistoryScreen] for why this asserts on the
  /// widget type rather than the ('الإعدادات') label text, which is shared
  /// with the nav tab.
  Future<void> verifySettingsScreen() async {
    await pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(TeacherStudentsScreen), findsNothing);
  }

  /// Verify there is no الحلقة tab in the bottom nav — it was removed by
  /// design (see nav_destinations.dart).
  Future<void> verifyNoHalaqahTab() async {
    final navBar = find.byType(BottomNavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.text('الحلقة')),
      findsNothing,
    );
  }
}

/// Robot for student flows
class StudentRobot extends TestRobot {
  StudentRobot(super.tester);

  /// Verify student dashboard
  Future<void> verifyDashboard() async {
    await pumpAndSettle();
    expect(find.textContaining('مرحباً'), findsOneWidget);
  }

  /// Verify current level displayed
  Future<void> verifyCurrentLevel(int level) async {
    await pumpAndSettle();
    expect(find.textContaining('المستوى $level'), findsOneWidget);
  }

  /// Navigate to session history
  Future<void> goToHistory() async {
    await tapByText('السجل');
  }

  /// Verify session history screen
  Future<void> verifyHistoryScreen() async {
    await pumpAndSettle();
    expect(find.textContaining('سجل'), findsWidgets);
  }

  /// Tap on session record. The history screen uses AppCard with onTap,
  /// not Material's Card.
  Future<void> tapSessionRecord(int index) async {
    final cards = find.byType(AppCard);
    await tester.tap(cards.at(index));
    await pumpAndSettle();
  }

  /// Verify session detail
  Future<void> verifySessionDetail() async {
    await pumpAndSettle();
    expect(find.textContaining('تفاصيل'), findsWidgets);
  }

  /// Verify level progression widget
  Future<void> verifyLevelProgression() async {
    await pumpAndSettle();
    expect(find.text('المستويات'), findsWidgets);
  }

  /// Navigate to home practice screen
  Future<void> goToHomePractice() async {
    await tapByText('التكرار');
  }

  /// Verify home practice screen
  Future<void> verifyHomePracticeScreen() async {
    await pumpAndSettle();
    expect(find.text('التكرار في المنزل'), findsOneWidget);
  }

  /// Submit a practice record with given repetitions.
  /// Stops at one pump so the success snackbar is still visible to the assertion.
  Future<void> submitPractice({int repetitions = 1}) async {
    if (repetitions != 1) {
      final repField = find.byType(TextField).first;
      await tester.enterText(repField, repetitions.toString());
      await pumpAndSettle();
    }
    // Submit button can be below the fold on smaller emulator screens.
    final finder = find.text('تسجيل التكرار');
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpAndSettle();
    await tester.tap(finder);
    // Pump enough for the async write to complete and the snackbar to appear,
    // but don't pumpAndSettle (which would wait the snackbar's full duration
    // and risk it being gone by the time the assertion runs).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Verify practice submitted successfully
  Future<void> verifyPracticeSuccess() async {
    await pumpAndSettle();
    expect(find.text('تم تسجيل التكرار بنجاح'), findsOneWidget);
  }
}

/// Robot for supervisor flows
class SupervisorRobot extends TestRobot {
  SupervisorRobot(super.tester);

  /// Verify supervisor dashboard.
  /// Stats are loaded via a chain of FutureProviders, so allow extra pumps
  /// for the supervisorStatsProvider future to resolve.
  Future<void> verifyDashboard() async {
    await pumpAndSettle();
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(
        () async =>
            await Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await pumpAndSettle();
    }
    await pumpAndSettle();
    expect(find.text('الراسخون - المشرف'), findsOneWidget);
  }

  /// Navigate to exam queue via bottom nav
  Future<void> goToExamQueue() async {
    final navBar = find.byType(BottomNavigationBar);
    final examIcon = find.descendant(
      of: navBar,
      matching: find.text('الاختبارات'),
    );
    await tester.tap(examIcon);
    await pumpAndSettle();
  }

  /// Verify exam queue screen.
  /// The queue is populated via a FutureProvider chain that needs an extra
  /// async tick beyond what pumpAndSettle pumps through.
  Future<void> verifyExamQueueScreen() async {
    await pumpAndSettle();
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(
        () async =>
            await Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await pumpAndSettle();
    }
    await pumpAndSettle();
    expect(find.textContaining('اختبار'), findsWidgets);
  }

  /// Verify student in queue
  Future<void> verifyStudentInQueue(String name) async {
    await pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  }

  /// Tap on student for exam
  Future<void> tapStudentForExam(String name) async {
    await tapByText(name);
  }

  /// Verify exam session screen
  Future<void> verifyExamSession() async {
    await pumpAndSettle();
    expect(find.textContaining('اختبار'), findsWidgets);
  }

  /// Enter exam errors by tapping the ErrorCounter add button N times.
  /// The exam session screen uses an ErrorCounter widget, not a TextField.
  Future<void> enterExamErrors(int errors) async {
    for (int i = 0; i < errors; i++) {
      final addButtons = find.byIcon(Icons.add);
      await tester.tap(addButtons.last);
      await pumpAndSettle();
    }
  }

  /// Submit exam result.
  ///
  /// The exam session screen scrolls (#59), so "إنهاء الاختبار" can sit below
  /// the fold on a phone. A bare tap then FINDS the button but misses it — the
  /// hit test lands outside the viewport, the tap does nothing, and the failure
  /// surfaces later and misleadingly as "the result screen never appeared".
  /// Scroll it into view first, exactly as [saveExamResult] does.
  Future<void> submitExamResult() async {
    final finder = find.text('إنهاء الاختبار');
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await pumpAndSettle();
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Verify exam result screen
  Future<void> verifyExamResult() async {
    await pumpAndSettle();
    expect(find.textContaining('نتيجة'), findsWidgets);
  }

  /// Save the exam result on the result screen. Stops one pump short of
  /// settling so the success snackbar is still on-screen for the assertion.
  Future<void> saveExamResult() async {
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

  /// Verify pass result
  Future<void> verifyPassResult() async {
    await pumpAndSettle();
    expect(find.textContaining('ناجح'), findsOneWidget);
  }

  /// Verify fail result
  Future<void> verifyFailResult() async {
    await pumpAndSettle();
    expect(find.textContaining('راسب'), findsOneWidget);
  }

  // Sard (السرد) is now conducted from the TEACHER's Students tab
  // (al_rasikhoon-801, reversing #29). See TeacherRobot for the Sard flow.
  // The supervisor has NO Sard flow of its own, so it keeps only the roster
  // helpers below — for viewing its own institute-scoped students list.

  /// Navigate to the supervisor's institute-scoped Students tab via bottom nav.
  Future<void> goToStudents() async {
    final navBar = find.byType(BottomNavigationBar);
    final studentsIcon = find.descendant(
      of: navBar,
      matching: find.text('الطلاب'),
    );
    await tester.tap(studentsIcon);
    await pumpAndSettle();
  }

  /// Verify the supervisor's students screen.
  /// The list is populated via a FutureProvider chain (institute-scoped, #28),
  /// so allow extra async ticks for it to resolve.
  Future<void> verifyStudentsScreen() async {
    await pumpAndSettle();
    for (int i = 0; i < 5; i++) {
      await tester.runAsync(
        () async =>
            await Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await pumpAndSettle();
    }
    await pumpAndSettle();
    expect(find.text('طلاب المعهد'), findsOneWidget);
  }

  /// Tap on a student to open their session overview.
  Future<void> tapStudent(String name) async {
    await tapByText(name);
  }

  // --- Assign a teacher to a teacher-less student (al_rasikhoon-6bw) -------

  /// Long-press a student card to open its actions sheet.
  Future<void> longPressStudent(String name) async {
    await tester.longPress(find.text(name));
    await pumpAndSettle();
  }

  /// Tap the "تعيين معلم" action in the (already open) actions sheet — only
  /// offered for a teacher-less student.
  Future<void> tapAssignTeacherAction() async {
    await tapByText('تعيين معلم');
  }

  /// Open the assign-teacher dialog's teacher dropdown and pick [teacherName].
  Future<void> selectTeacherInAssignDialog(String teacherName) async {
    await tester.tap(find.byType(DropdownButton<UserModel>));
    await pumpAndSettle();
    await tester.tap(find.text(teacherName).last);
    await pumpAndSettle();
  }

  /// Confirm the assign-teacher dialog with its "تعيين معلم" button (the
  /// sheet's ListTile of the same name is already closed by this point).
  Future<void> confirmAssignTeacher() async {
    await tapByText('تعيين معلم');
  }
}
