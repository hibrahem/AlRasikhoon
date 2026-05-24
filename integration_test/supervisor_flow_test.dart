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

    testWidgets(
        'Supervisor conducts a Sard end-to-end: start → conduct → save (#29 / #45)',
        (tester) async {
      // Arrange — full supervisor Sard E2E (regression coverage for #45).
      //
      // Sard became supervisor-only in #29, which relocated the Sard routes
      // into the supervisor shell. #45 fixed two coupled bugs that made the
      // flow non-functional at runtime despite correct gating:
      //   1. Cross-shell crash: SupervisorStudentsScreen used to push the
      //      TEACHER-shell sessionOverview, then "بدء السرد" pushed the
      //      SUPERVISOR-shell Sard route — a teacher-shell page sandwiched
      //      between supervisor-shell branches tripped go_router 17's
      //      duplicate-page-key assertion. It now pushes the supervisor-shell
      //      session-overview (/supervisor/students/:studentId), so the whole
      //      flow is ONE shell.
      //   2. Teacher-scoped student lookup: the screens resolved the student
      //      via getStudentsForTeacher; supervisor-created students carry
      //      teacher_id: null (AgDR-0003), so the supervisor got "Student not
      //      found". The supervisor path now resolves institute-scoped.
      //
      // This test drives the previously-crashing path to completion. The
      // student carries teacher_id: null on purpose — the exact AgDR-0003
      // shape that used to fail the lookup — proving institute-scoped
      // resolution works.
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
        // teacher_id: null — a supervisor-created, institute-scoped student
        // (AgDR-0003). The institute scope matches the supervisor's Students
        // tab; the institute-scoped lookup (not getStudentsForTeacher) resolves
        // it. Passing no teacherId leaves it null.
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

      // The supervisor gets the Sard start action; teacher-only notice absent.
      await supervisorRobot.verifySardAvailableForSupervisor();

      // Drive the full Sard to completion — this is the path that used to
      // crash (cross-shell push) before #45. No "Student not found", no crash.
      await supervisorRobot.startSard();
      await supervisorRobot.verifySardSession();
      await supervisorRobot.enterSardErrors(2);
      await supervisorRobot.finishSard();
      await supervisorRobot.verifySardResult();
      await supervisorRobot.saveSardResult();

      // Assert — the Sard saved successfully end-to-end.
      await supervisorRobot.verifySardSaved();
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
