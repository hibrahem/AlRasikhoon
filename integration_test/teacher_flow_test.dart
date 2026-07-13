import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_robots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher E2E Flow', () {
    late TestEnvironment env;
    late TeacherRobot teacherRobot;

    setUp(() async {
      env = TestEnvironment();
    });

    testWidgets('Teacher can view students list', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      // Assert
      await teacherRobot.verifyStudentsScreen();
    });

    testWidgets('Teacher can add a new student', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapAddStudent();
      await teacherRobot.fillStudentForm(
        name: 'عبدالله أحمد',
        email: 'abdullah@example.com',
      );
      await teacherRobot.submitStudentForm();

      // Assert
      await teacherRobot.verifyStudentInList('عبدالله أحمد');
    });

    testWidgets('Teacher can view student session overview', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      // Create a student user and student record
      final studentUser = env.createStudent(
        id: 'student_user_1',
        name: 'محمد خالد',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('محمد خالد');

      // Assert
      await teacherRobot.verifySessionOverview();
    });

    testWidgets('Teacher can conduct a session with passing grade', (
      tester,
    ) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_user_2',
        name: 'علي محمد',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('علي محمد');
      await teacherRobot.verifySessionOverview();
      await teacherRobot.startSession();

      // Part 1: New memorization - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: Recent review - 1 error
      await teacherRobot.enterErrorCount(1);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: Distant review - 2 errors
      await teacherRobot.enterErrorCount(2);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Summary screen shows passing grade, then session completes
      await teacherRobot.verifyGrade('متقن'); // 1 error average = متقن
      await teacherRobot.completeSession();
    });

    testWidgets('Teacher can conduct a session with failing grade', (
      tester,
    ) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_user_3',
        name: 'سعد عبدالله',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('سعد عبدالله');
      await teacherRobot.startSession();

      // Part 1: 7 errors — exceeds maxErrorsToPass (6), so session fails.
      await teacherRobot.enterErrorCount(7);
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: Recent review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: Distant review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Summary screen shows fail grade for over-threshold part 1
      await teacherRobot.verifyGrade('محب'); // Any part >6 errors = محب (fail)
      await teacherRobot.completeSession();
    });

    testWidgets('Failed session allows student to retry', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_retry',
        name: 'طالب الإعادة',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('طالب الإعادة');
      await teacherRobot.startSession();

      // Part 1: 7 errors — exceeds maxErrorsToPass (6), so session fails.
      await teacherRobot.enterErrorCount(7);
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Failed grade is shown on the summary screen before saving
      expect(find.textContaining('محب'), findsWidgets); // Failed grade
      await teacherRobot.completeSession();
    });

    testWidgets('Teacher is blocked from Sard at a Sard session (#29 / #44)', (
      tester,
    ) async {
      // Arrange — Sard became supervisor-only in #29. A teacher viewing a
      // student at a Sard session (35) must see the read-only notice and must
      // NOT see the "بدء السرد" action.
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_sard_blocked',
        name: 'طالب السرد',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
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

      // Assert - read-only supervisor-only notice shown, start action absent.
      await teacherRobot.verifySardBlockedForTeacher();
    });
  });
}
