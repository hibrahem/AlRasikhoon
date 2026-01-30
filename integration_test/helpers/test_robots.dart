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

/// Robot for authentication flows
class AuthRobot extends TestRobot {
  AuthRobot(super.tester);

  /// Verify we're on the login screen
  Future<void> verifyLoginScreen() async {
    await pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  }

  /// Enter phone number
  Future<void> enterPhoneNumber(String phone) async {
    final phoneField = find.byType(TextField).first;
    await tester.enterText(phoneField, phone);
    await pumpAndSettle();
  }

  /// Tap continue/send OTP button
  Future<void> tapContinue() async {
    await tapByText('متابعة');
  }

  /// Verify OTP screen
  Future<void> verifyOtpScreen() async {
    await pumpAndSettle();
    expect(find.text('رمز التحقق'), findsOneWidget);
  }

  /// Enter OTP code
  Future<void> enterOtp(String otp) async {
    for (int i = 0; i < otp.length; i++) {
      final otpField = find.byType(TextField).at(i);
      if (otpField.evaluate().isNotEmpty) {
        await tester.enterText(otpField, otp[i]);
      }
    }
    await pumpAndSettle();
  }

  /// Verify account not found screen
  Future<void> verifyAccountNotFoundScreen() async {
    await pumpAndSettle();
    expect(find.textContaining('غير مسجل'), findsOneWidget);
  }
}

/// Robot for admin flows
class AdminRobot extends TestRobot {
  AdminRobot(super.tester);

  /// Verify admin dashboard
  Future<void> verifyDashboard() async {
    await pumpAndSettle();
    expect(find.text('لوحة التحكم'), findsOneWidget);
  }

  /// Navigate to institutes
  Future<void> goToInstitutes() async {
    await tapByText('المعاهد');
  }

  /// Navigate to teachers
  Future<void> goToTeachers() async {
    await tapByText('المعلمين');
  }

  /// Navigate to curriculum
  Future<void> goToCurriculum() async {
    await tapByText('المنهج');
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

  /// Submit create form
  Future<void> submitForm() async {
    await tapByText('إنشاء');
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

  /// Fill teacher form
  Future<void> fillTeacherForm({
    required String name,
    required String phone,
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), phone);
    await pumpAndSettle();
  }

  /// Verify teacher in list
  Future<void> verifyTeacherInList(String name) async {
    await pumpAndSettle();
    expect(find.text(name), findsOneWidget);
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
    await tapByIcon(Icons.add);
  }

  /// Fill student form
  Future<void> fillStudentForm({
    required String name,
    required String phone,
    String? guardianPhone,
  }) async {
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    await tester.enterText(textFields.at(1), phone);
    if (guardianPhone != null && textFields.evaluate().length > 2) {
      await tester.enterText(textFields.at(2), guardianPhone);
    }
    await pumpAndSettle();
  }

  /// Submit student form
  Future<void> submitStudentForm() async {
    await tapByText('إضافة');
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

  /// Enter error count
  Future<void> enterErrorCount(int errors) async {
    final errorField = find.byType(TextField).first;
    await tester.enterText(errorField, errors.toString());
    await pumpAndSettle();
  }

  /// Submit part result
  Future<void> submitPartResult() async {
    await tapByText('التالي');
  }

  /// Verify grade displayed
  Future<void> verifyGrade(String gradeAr) async {
    await pumpAndSettle();
    expect(find.text(gradeAr), findsOneWidget);
  }

  /// Complete session
  Future<void> completeSession() async {
    await tapByText('إنهاء الحلقة');
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
    await tapByIcon(Icons.history);
  }

  /// Verify session history screen
  Future<void> verifyHistoryScreen() async {
    await pumpAndSettle();
    expect(find.text('سجل الحلقات'), findsOneWidget);
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
    expect(find.text('المستويات'), findsOneWidget);
  }
}

/// Robot for supervisor flows
class SupervisorRobot extends TestRobot {
  SupervisorRobot(super.tester);

  /// Verify supervisor dashboard
  Future<void> verifyDashboard() async {
    await pumpAndSettle();
    expect(find.text('لوحة المشرف'), findsOneWidget);
  }

  /// Navigate to exam queue
  Future<void> goToExamQueue() async {
    await tapByText('قائمة الاختبارات');
  }

  /// Verify exam queue screen
  Future<void> verifyExamQueueScreen() async {
    await pumpAndSettle();
    expect(find.text('الاختبارات'), findsOneWidget);
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
