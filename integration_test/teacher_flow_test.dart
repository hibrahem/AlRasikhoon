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
        phone: '512345682',
        guardianPhone: '512345683',
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
      final studentUser = env.createStudent(id: 'student_user_1', name: 'محمد خالد');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
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

    testWidgets('Teacher can conduct a session with passing grade', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(id: 'student_user_2', name: 'علي محمد');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        currentSession: 1,
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
      await teacherRobot.submitPartResult();

      // Part 2: Recent review - 1 error
      await teacherRobot.enterErrorCount(1);
      await teacherRobot.submitPartResult();

      // Part 3: Distant review - 2 errors
      await teacherRobot.enterErrorCount(2);
      await teacherRobot.submitPartResult();

      // Assert - Session completed with passing grade
      await teacherRobot.completeSession();
      await teacherRobot.verifyGrade('متقن'); // 1 error average = متقن
    });

    testWidgets('Teacher can conduct a session with failing grade', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(id: 'student_user_3', name: 'سعد عبدالله');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        currentSession: 1,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('سعد عبدالله');
      await teacherRobot.startSession();

      // Part 1: New memorization - 5 errors (FAIL)
      await teacherRobot.enterErrorCount(5);
      await teacherRobot.submitPartResult();

      // Part 2: Recent review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitPartResult();

      // Part 3: Distant review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitPartResult();

      // Assert - Session failed due to Part 1
      await teacherRobot.completeSession();
      await teacherRobot.verifyGrade('محب'); // Failed = محب
    });

    testWidgets('Teacher can conduct Sard session at session 35', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(id: 'student_user_4', name: 'خالد فهد');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        currentSession: 35, // Sard session
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('خالد فهد');

      // Assert - Sard option should be available
      await teacherRobot.pumpAndSettle();
      expect(find.textContaining('سرد'), findsWidgets);
    });
  });
}
