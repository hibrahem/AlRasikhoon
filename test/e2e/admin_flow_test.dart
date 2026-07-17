import 'package:flutter/material.dart';
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
      await env.addInstitute(name: 'معهد النور', location: 'الرياض');

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
      await adminRobot.submitTeacherForm();

      // Assert
      await adminRobot.verifyTeacherInList('أحمد محمد');
    });

    testWidgets('Admin can assign teacher to institute', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);
      await env.addInstitute(name: 'معهد الفرقان');
      final teacher = env.createTeacher(name: 'محمد علي');
      await env.fakeFirestore
          .collection('users')
          .doc(teacher.id)
          .set(teacher.toFirestore());

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

    testWidgets('Admin can edit an existing institute', (tester) async {
      // Arrange
      final admin = env.createSuperAdmin();
      await env.setUp(authenticatedUser: admin);
      await env.addInstitute(
        id: 'edit_institute',
        name: 'معهد القديم',
        location: 'الرياض',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      adminRobot = AdminRobot(tester);

      await adminRobot.verifyDashboard();
      await adminRobot.goToInstitutes();
      await adminRobot.tapInstitute('معهد القديم');
      await adminRobot.verifyInstituteDetail('معهد القديم');

      // Tap edit button and modify
      await adminRobot.tapEditInstitute();
      await adminRobot.fillEditInstituteForm(
        name: 'معهد الجديد',
        location: 'جدة',
      );
      await adminRobot.saveChanges();

      // Assert - should navigate back and show updated name
      await adminRobot.pumpAndSettle();
      expect(find.text('تم تحديث المعهد بنجاح'), findsOneWidget);
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

      // Assert - Curriculum screen should show its overview header.
      // ('المنهج' is also the bottom-nav label, so use a screen-unique string.)
      await adminRobot.pumpAndSettle();
      expect(find.text('منهج الراسخون'), findsOneWidget);
    });

    testWidgets(
      'Admin can edit a supervisor profile end-to-end (al_rasikhoon-1nw)',
      (tester) async {
        // Arrange: an admin, plus a supervisor profile in Firestore.
        final admin = env.createSuperAdmin();
        await env.setUp(authenticatedUser: admin);
        final supervisor = env.createSupervisor();
        await env.fakeFirestore
            .collection('users')
            .doc(supervisor.id)
            .set(supervisor.toFirestore());

        // Act: dashboard → المشرفون → supervisor detail → edit → save.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        adminRobot = AdminRobot(tester);

        await adminRobot.verifyDashboard();
        await adminRobot.tapByText('المشرفون');
        await adminRobot.tapByText('مشرف تجريبي');
        await adminRobot.pumpUntilFound(find.byTooltip('تعديل الملف الشخصي'));
        await tester.tap(find.byTooltip('تعديل الملف الشخصي'));
        await adminRobot.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'مشرف تجريبي'),
          'مشرف تجريبي المحدث',
        );
        await tester.tap(find.text('حفظ'));

        // Assert: the write landed and the detail header refetched the new
        // name from Firestore (provider invalidation round-trip).
        final renamed = await adminRobot.pumpUntilFound(
          find.text('مشرف تجريبي المحدث'),
        );
        expect(renamed, isTrue);
        final doc = await env.fakeFirestore
            .collection('users')
            .doc(supervisor.id)
            .get();
        expect(doc.data()?['name'], 'مشرف تجريبي المحدث');
      },
    );

    testWidgets(
      'Admin detail screen offers a supervisor password reset (al_rasikhoon-1nw)',
      (tester) async {
        final admin = env.createSuperAdmin();
        await env.setUp(authenticatedUser: admin);
        final supervisor = env.createSupervisor();
        await env.fakeFirestore
            .collection('users')
            .doc(supervisor.id)
            .set(supervisor.toFirestore());

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        adminRobot = AdminRobot(tester);

        await adminRobot.verifyDashboard();
        await adminRobot.tapByText('المشرفون');
        await adminRobot.tapByText('مشرف تجريبي');
        await adminRobot.pumpUntilFound(
          find.byTooltip('إعادة تعيين كلمة المرور'),
        );
        await tester.tap(find.byTooltip('إعادة تعيين كلمة المرور'));
        await adminRobot.pumpAndSettle();

        // The reset dialog is up, addressed to THIS supervisor. (The actual
        // reset calls the setUserPassword Cloud Function — no backend here.)
        expect(find.text('إعادة تعيين كلمة مرور مشرف تجريبي'), findsOneWidget);
      },
    );
  });
}
