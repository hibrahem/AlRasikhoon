import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  /// Tap a widget by icon
  Future<void> tapByIcon(IconData icon) async {
    await tester.tap(find.byIcon(icon));
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

/// Robot for authentication flows (email link + Google Sign-In)
class AuthRobot extends TestRobot {
  AuthRobot(super.tester);

  /// Verify we're on the login screen
  Future<void> verifyLoginScreen() async {
    await pumpAndSettle();
    expect(find.text('الراسخون'), findsOneWidget);
    expect(find.text('إرسال رابط الدخول'), findsOneWidget);
  }

  /// Enter email address
  Future<void> enterEmail(String email) async {
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, email);
    await pumpAndSettle();
  }

  /// Tap send login link button
  Future<void> tapSendLink() async {
    await tapByText('إرسال رابط الدخول');
  }

  /// Verify link sent success screen
  Future<void> verifyLinkSentScreen() async {
    await pumpAndSettle();
    expect(find.text('تم إرسال رابط الدخول'), findsOneWidget);
  }

  /// Tap Google Sign-In button
  Future<void> tapGoogleSignIn() async {
    await tapByText('تسجيل الدخول بواسطة Google');
  }

  /// Tap resend link button
  Future<void> tapResendLink() async {
    await tapByText('إرسال رابط جديد');
  }

  /// Tap change email button
  Future<void> tapChangeEmail() async {
    await tapByText('تغيير البريد الإلكتروني');
  }

  /// Verify account not found screen
  Future<void> verifyAccountNotFoundScreen() async {
    await pumpAndSettle();
    expect(find.textContaining('غير مسجل'), findsOneWidget);
  }

  /// Verify error message displayed
  Future<void> verifyErrorMessage(String message) async {
    await pumpAndSettle();
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

  /// Fill teacher form (name + email + optional phone)
  Future<void> fillTeacherForm({
    required String name,
    required String email,
    String? phone,
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), email);
    if (phone != null && textFields.evaluate().length > 2) {
      await tester.enterText(textFields.at(2), phone);
    }
    await pumpAndSettle();
  }

  /// Verify teacher in list
  Future<void> verifyTeacherInList(String name) async {
    await pumpAndSettle();
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

  /// Save and complete session from summary screen
  Future<void> completeSession() async {
    await tapByText('حفظ وإنهاء الحلقة');
  }

  /// Start sard session
  Future<void> startSardSession() async {
    await tapByText('بدء السرد');
  }

  /// Verify sard session screen
  Future<void> verifySardScreen() async {
    await pumpAndSettle();
    expect(find.text('السرد'), findsOneWidget);
  }

  /// Tap end sard button
  Future<void> tapEndSard() async {
    await tapByText('إنهاء السرد');
  }

  /// Verify sard result screen
  Future<void> verifySardResult() async {
    await pumpAndSettle();
    expect(find.text('نتيجة السرد'), findsOneWidget);
  }

  /// Save sard result
  Future<void> saveSardResult() async {
    await tapByText('حفظ النتيجة');
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

  /// Tap on session record
  Future<void> tapSessionRecord(int index) async {
    final cards = find.byType(Card);
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

  /// Submit a practice record with given repetitions
  Future<void> submitPractice({int repetitions = 1}) async {
    // The repetitions field has a default value of 1
    // If we need a different value, enter it
    if (repetitions != 1) {
      final repField = find.byType(TextField).first;
      await tester.enterText(repField, repetitions.toString());
      await pumpAndSettle();
    }
    await tapByText('تسجيل التكرار');
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

  /// Verify supervisor dashboard
  Future<void> verifyDashboard() async {
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

  /// Verify exam queue screen
  Future<void> verifyExamQueueScreen() async {
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

  /// Enter exam errors
  Future<void> enterExamErrors(int errors) async {
    final errorField = find.byType(TextField).first;
    await tester.enterText(errorField, errors.toString());
    await pumpAndSettle();
  }

  /// Submit exam result
  Future<void> submitExamResult() async {
    await tapByText('إنهاء الاختبار');
  }

  /// Verify exam result screen
  Future<void> verifyExamResult() async {
    await pumpAndSettle();
    expect(find.textContaining('نتيجة'), findsWidgets);
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
}
