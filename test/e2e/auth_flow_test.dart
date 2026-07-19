import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_robots.dart';

void main() {
  // Headless on the Dart VM (`flutter test`) — no device/simulator.
  // Safe because helpers/test_app.dart never touches Firebase.initializeApp
  // (fake_cloud_firestore + provider overrides stand in for it) and stubs
  // the one platform channel the app needs on the host (path_provider, for
  // google_fonts' cache dir) — see stubHeadlessPlatformChannels there.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth E2E Flow', () {
    late TestEnvironment env;
    late AuthRobot authRobot;

    setUp(() async {
      env = TestEnvironment();
    });

    testWidgets('Login screen renders with username + password fields', (
      tester,
    ) async {
      // Arrange - no authenticated user
      await env.setUp();

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      authRobot = AuthRobot(tester);

      // Assert
      await authRobot.verifyLoginScreen();
      // The brand is the official logo image (its wordmark is part of the
      // asset); the semantics label keeps it announced to screen readers.
      expect(find.bySemanticsLabel('الراسخون'), findsOneWidget);
      expect(find.text('اسم المستخدم'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('يجب أن يكون لديك حساب مسجل مسبقاً'), findsOneWidget);
    });

    testWidgets('Authenticated admin redirects to admin dashboard', (
      tester,
    ) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));

      // Assert - should redirect to admin dashboard, not login
      await tester.pumpAndSettle();
      expect(
        find.text('إدارة المعاهد والمعلمين والمشرفين والطلاب'),
        findsOneWidget,
      );
    });

    testWidgets('Authenticated teacher redirects to students screen', (
      tester,
    ) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('طلابي'), findsOneWidget);
    });

    testWidgets('Authenticated student redirects to student dashboard', (
      tester,
    ) async {
      // Arrange
      final student = env.createStudent(name: 'أحمد');
      await env.setUp(authenticatedUser: student);
      final instituteId = await env.addInstitute();
      await env.addStudent(userId: student.id, instituteId: instituteId);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));

      // Assert
      await tester.pumpAndSettle();
      expect(find.textContaining('السلام عليكم'), findsOneWidget);
    });

    testWidgets('Authenticated supervisor redirects to supervisor dashboard', (
      tester,
    ) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));

      // Assert
      await tester.pumpAndSettle();
      expect(find.text('إدارة اختبارات الطلاب'), findsOneWidget);
    });
  });
}
