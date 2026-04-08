import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_robots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin E2E Flow', () {
    late TestEnvironment env;
    late AdminRobot adminRobot;

    setUp(() async {
      env = TestEnvironment();
    });

    testWidgets('Admin can view dashboard after login', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      // Assert
      await adminRobot.verifyDashboard();
    });

    testWidgets('Admin can create a new institute', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToInstitutes();
      await adminRobot.tapCreateInstitute();
      await adminRobot.fillInstituteForm(
        name: 'معهد الراسخون الجديد',
        location: 'جدة',
      );
      await adminRobot.submitForm();

      // Assert
      await adminRobot.verifyInstituteInList('معهد الراسخون الجديد');
    });

    testWidgets('Admin can view institute details', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);
      await env.addInstitute(
        name: 'معهد النور',
        location: 'الرياض',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToInstitutes();
      await adminRobot.tapInstitute('معهد النور');

      // Assert
      await adminRobot.verifyInstituteDetail('معهد النور');
    });

    testWidgets('Admin can add a new teacher', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToTeachers();
      await adminRobot.tapAddTeacher();
      await adminRobot.fillTeacherForm(
        name: 'أحمد محمد',
        email: 'ahmed@example.com',
      );
      await adminRobot.submitForm();

      // Assert
      await adminRobot.verifyTeacherInList('أحمد محمد');
    });

    testWidgets('Admin can assign teacher to institute', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);
      await env.addInstitute(name: 'معهد الفرقان');
      final teacher = env.createTeacher(name: 'محمد علي');
      await env.fakeFirestore.collection('users').doc(teacher.id).set(teacher.toFirestore());

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToInstitutes();
      await adminRobot.tapInstitute('معهد الفرقان');
      await adminRobot.tapAssignTeacher();

      // Assert - Teacher should be assignable
      expect(adminRobot.isTextDisplayed('محمد علي'), true);
    });

    testWidgets('Admin can view curriculum', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToCurriculum();

      // Assert - Curriculum screen should show levels
      await adminRobot.pumpAndSettle();
      expect(find.text('المنهج'), findsOneWidget);
    });
  });
}
