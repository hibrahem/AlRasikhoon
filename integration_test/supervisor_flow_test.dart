import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_robots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Supervisor E2E Flow', () {
    late TestEnvironment env;
    late SupervisorRobot supervisorRobot;

    setUp(() async {
      env = TestEnvironment();
    });

    testWidgets('Supervisor can view dashboard', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      // Assert
      await supervisorRobot.verifyDashboard();
    });

    testWidgets('Supervisor can view exam queue', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();

      // Assert
      await supervisorRobot.verifyExamQueueScreen();
    });

    testWidgets('Supervisor sees students ready for exam in queue', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      // Create a student at session 36 (exam)
      final studentUser = env.createStudent(id: 'exam_student_1', name: 'طالب الاختبار');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 36, // Ready for exam
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();

      // Assert
      await supervisorRobot.verifyStudentInQueue('طالب الاختبار');
    });

    testWidgets('Supervisor can conduct exam with passing result', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      final studentUser = env.createStudent(id: 'exam_student_2', name: 'أحمد الاختبار');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 36,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();
      await supervisorRobot.tapStudentForExam('أحمد الاختبار');
      await supervisorRobot.verifyExamSession();

      // Enter passing grade (0-3 errors)
      await supervisorRobot.enterExamErrors(2);
      await supervisorRobot.submitExamResult();

      // Assert
      await supervisorRobot.verifyExamResult();
      await supervisorRobot.verifyPassResult();
    });

    testWidgets('Supervisor can conduct exam with failing result', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      final studentUser = env.createStudent(id: 'exam_student_3', name: 'محمد الاختبار');
      await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        currentSession: 36,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();
      await supervisorRobot.tapStudentForExam('محمد الاختبار');
      await supervisorRobot.verifyExamSession();

      // Enter failing grade — must exceed maxErrorsToPass (6) for محب/راسب
      await supervisorRobot.enterExamErrors(7);
      await supervisorRobot.submitExamResult();

      // Assert
      await supervisorRobot.verifyExamResult();
      await supervisorRobot.verifyFailResult();
    });

    testWidgets('Supervisor dashboard shows exam statistics', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      // Create students at session 36
      for (int i = 0; i < 3; i++) {
        final studentUser = env.createStudent(id: 'stats_student_$i', name: 'طالب $i');
        await env.fakeFirestore.collection('users').doc(studentUser.id).set(studentUser.toFirestore());
        await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          currentSession: 36,
        );
      }

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      // Assert
      await supervisorRobot.verifyDashboard();
      // Should show pending exam count
      await supervisorRobot.pumpAndSettle();
      expect(find.text('3'), findsWidgets); // 3 pending exams
    });

    testWidgets('Supervisor is offered the Sard entry point at a Sard session (#29 / #44)',
        (tester) async {
      // Arrange — Sard became supervisor-only in #29. This is the supervisor
      // mirror of the teacher-blocked test: a supervisor opening a student
      // (from their institute-scoped Students tab, #28) at a Sard session (35)
      // MUST see the "بدء السرد" action and MUST NOT see the teacher-only
      // read-only notice.
      //
      // The supervisor's student list is scoped to users/{uid}.institute_id
      // (AgDR-0003), so the supervisor carries that institute id; it is fixed
      // up front so it can be stamped on the supervisor user before setUp
      // persists the authenticated user.
      //
      // NOTE (out of #44 scope): the session-overview screen is reached via the
      // teacher-shell route (/teacher/session/:studentId — that is how
      // SupervisorStudentsScreen pushes it), and the "بدء السرد" button then
      // pushes the supervisor-shell route /supervisor/sard/:studentId. Driving
      // that second cross-shell push to completion (start → end → save) trips a
      // go_router 17 "duplicate page key" Navigator assertion. That is a real
      // navigation bug in the supervisor→Sard path introduced when #29
      // relocated the Sard routes into the supervisor shell, and it is filed
      // separately — it is NOT test staleness. This test therefore asserts the
      // supervisor-side gating (the inverse of the teacher block), which is the
      // meaningful #29 behaviour and is stable on-device.
      const instituteId = 'sard_institute_1';
      final supervisor =
          env.createSupervisor().copyWith(instituteId: instituteId);
      await env.setUp(authenticatedUser: supervisor);
      await env.addInstitute(id: instituteId);
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      final studentUser =
          env.createStudent(id: 'sup_sard_student', name: 'طالب سرد المشرف');
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        // The session-overview screen resolves the student through the
        // teacher-scoped studentProvider (getStudentsForTeacher == the
        // logged-in user's id). A supervisor evaluating a student is the
        // "teacher" for that lookup, so the student carries the supervisor's
        // id here. The institute scope (above) still matches the supervisor's
        // students tab.
        teacherId: supervisor.id,
        currentSession: 35, // Sard session
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToStudents();
      await supervisorRobot.verifyStudentsScreen();
      await supervisorRobot.tapStudent('طالب سرد المشرف');
      await supervisorRobot.verifySessionOverview();

      // Assert - supervisor gets the Sard start action; teacher-only notice absent.
      await supervisorRobot.verifySardAvailableForSupervisor();
    });

    testWidgets('Supervisor only sees students from assigned institutes', (tester) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);

      // Create two institutes
      final assignedInstitute = await env.addInstitute(name: 'معهد مخصص');
      final otherInstitute = await env.addInstitute(name: 'معهد آخر');

      // Only assign supervisor to one institute
      await env.assignSupervisorToInstitute(supervisor.id, assignedInstitute);

      // Create student in assigned institute
      final assignedStudent = env.createStudent(id: 'assigned_student', name: 'طالب المعهد المخصص');
      await env.fakeFirestore.collection('users').doc(assignedStudent.id).set(assignedStudent.toFirestore());
      await env.addStudent(
        userId: assignedStudent.id,
        instituteId: assignedInstitute,
        currentSession: 36,
      );

      // Create student in other institute
      final otherStudent = env.createStudent(id: 'other_student', name: 'طالب معهد آخر');
      await env.fakeFirestore.collection('users').doc(otherStudent.id).set(otherStudent.toFirestore());
      await env.addStudent(
        userId: otherStudent.id,
        instituteId: otherInstitute,
        currentSession: 36,
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();
      await supervisorRobot.verifyExamQueueScreen();

      // Assert - Only assigned institute's student should appear
      expect(find.text('طالب المعهد المخصص'), findsOneWidget);
      expect(find.text('طالب معهد آخر'), findsNothing);
    });
  });
}
