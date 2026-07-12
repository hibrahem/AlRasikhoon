import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

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

    testWidgets(
      'a student placed on a Sard is assessed with no prior sessions (#flexible-start)',
      (tester) async {
        // A student arrives having already memorized through level 1 and part of
        // level 2, and is placed directly on the Sard of hizb 53. The app taught
        // them none of it — they hold zero session records — and the supervisor
        // must still be able to assess them.
        const instituteId = 'placed_institute';
        final supervisor = env
            .createSupervisor()
            .copyWith(instituteId: instituteId);
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        // The curriculum session they are placed on: level 2, juz 27, hizb 53,
        // session 35 (the Sard).
        await env.fakeFirestore
            .collection('sessions')
            .doc('L2_J27_H53_S35')
            .set({
              'session_number': 35,
              'level_id': 2,
              'juz_number': 27,
              'hizb_number': 53,
              'session_type': 'sard',
              'current_level_content': {
                'from_surah': 'الزمر',
                'from_verse': 1,
                'to_surah': 'الزمر',
                'to_verse': 31,
              },
              'recent_review_content': {
                'from_surah': 'ص',
                'from_verse': 1,
                'to_surah': 'ص',
                'to_verse': 88,
              },
              'distant_review_content': {
                'from_surah': 'يس',
                'from_verse': 1,
                'to_surah': 'يس',
                'to_verse': 83,
              },
            });

        // Place the student through the production path, not a seeded document.
        final container = ProviderContainer(overrides: env.overrides.cast());
        addTearDown(container.dispose);
        final created = await container
            .read(studentRepositoryProvider)
            .createStudent(
              name: 'طالب حافظ',
              username: 'placed_student',
              password: 'secret123',
              instituteId: instituteId,
              // teacher_id stays null: an institute-scoped student (AgDR-0003).
              startingPosition: const CurriculumPosition(
                level: 2,
                hizb: 53,
                session: 35,
              ),
            );

        // The anchor and the credit it implies are persisted.
        final doc = await env.fakeFirestore
            .collection('students')
            .doc(created.student.id)
            .get();
        expect(doc.data()?['current_level'], 2);
        expect(doc.data()?['current_hizb'], 53);
        expect(doc.data()?['current_juz'], 27);
        expect(doc.data()?['current_session'], 35);
        expect(doc.data()?['completed_levels'], [1]);
        expect(doc.data()?['enrollment_position'], {
          'level': 2,
          'juz': 27,
          'hizb': 53,
          'session': 35,
        });

        // They hold no session records at all — nothing was taught in the app.
        final records = await env.fakeFirestore
            .collection('session_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(records.docs, isEmpty);

        // The supervisor conducts their Sard end-to-end regardless.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب حافظ');
        await supervisorRobot.verifySessionOverview();
        await supervisorRobot.verifySardAvailableForSupervisor();

        await supervisorRobot.startSard();
        await supervisorRobot.verifySardSession();
        await supervisorRobot.enterSardErrors(2);
        await supervisorRobot.finishSard();
        await supervisorRobot.verifySardResult();
        await supervisorRobot.saveSardResult();

        await supervisorRobot.verifySardSaved();
      },
    );

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
