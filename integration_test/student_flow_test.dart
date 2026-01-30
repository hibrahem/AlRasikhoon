import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'helpers/test_app.dart';
import 'helpers/test_robots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Student E2E Flow', () {
    late TestEnvironment env;
    late StudentRobot studentRobot;

    setUp(() async {
      env = TestEnvironment();
    });

    testWidgets('Student can view dashboard with progress', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'أحمد محمد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 5,
        currentLevel: 1,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.verifyCurrentLevel(1);
    });

    testWidgets('Student can see level progression widget', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'محمد علي');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.verifyLevelProgression();
    });

    testWidgets('Student can view session history', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'عبدالله سعد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      final studentId = await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
      );

      // Add some session records
      await env.fakeFirestore.collection('session_records').add({
        'student_id': studentId,
        'teacher_id': 'teacher_1',
        'level_id': 1,
        'juz_number': 30,
        'hizb_number': 59,
        'session_number': 1,
        'attempt_number': 1,
        'part1_errors': 0,
        'part2_errors': 1,
        'part3_errors': 2,
        'total_errors': 3,
        'passed': true,
        'grade': 'mutqin',
        'created_at': Timestamp.now(),
      });

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      await studentRobot.verifyDashboard();
      await studentRobot.goToHistory();

      // Assert
      await studentRobot.verifyHistoryScreen();
    });

    testWidgets('Student can view session detail', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'فهد خالد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      final studentId = await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
      );

      // Add a session record
      await env.fakeFirestore.collection('session_records').add({
        'student_id': studentId,
        'teacher_id': 'teacher_1',
        'level_id': 1,
        'juz_number': 30,
        'hizb_number': 59,
        'session_number': 1,
        'attempt_number': 1,
        'part1_errors': 0,
        'part2_errors': 0,
        'part3_errors': 0,
        'total_errors': 0,
        'passed': true,
        'grade': 'rasikh',
        'created_at': Timestamp.now(),
      });

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      await studentRobot.verifyDashboard();
      await studentRobot.goToHistory();
      await studentRobot.verifyHistoryScreen();
      await studentRobot.tapSessionRecord(0);

      // Assert
      await studentRobot.verifySessionDetail();
    });

    testWidgets('Student sees current session info on dashboard', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'سعد محمد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 10,
        currentLevel: 1,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.pumpAndSettle();
      expect(find.textContaining('الحلقة 10'), findsOneWidget);
    });

    testWidgets('Student at session 35 sees Sard info', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'خالد عبدالله');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 35, // Sard session
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.pumpAndSettle();
      expect(find.textContaining('سرد'), findsWidgets);
    });

    testWidgets('Student at session 36 sees Exam info', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'علي فهد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 36, // Exam session
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.pumpAndSettle();
      expect(find.textContaining('اختبار'), findsWidgets);
    });

    testWidgets('Student with completed level 1 sees level 2 unlocked', (tester) async {
      // Arrange
      final studentUser = env.createStudent(name: 'محمد سعد');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();

      // Student has completed level 1
      await env.fakeFirestore.collection('students').add({
        'user_id': studentUser.id,
        'institute_id': instituteId,
        'current_level': 2,
        'current_juz': 29,
        'current_hizb': 57,
        'current_session': 1,
        'current_attempt': 1,
        'unlocked_levels': [1, 2],
        'completed_levels': [1],
        'is_active': true,
        'created_at': Timestamp.now(),
      });

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      studentRobot = StudentRobot(tester);

      // Assert
      await studentRobot.verifyDashboard();
      await studentRobot.verifyCurrentLevel(2);
      // Level progression should show level 1 completed and level 2 current
      await studentRobot.verifyLevelProgression();
    });
  });
}
