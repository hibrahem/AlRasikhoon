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

    testWidgets('Supervisor sees students ready for exam in queue', (
      tester,
    ) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      // Create a student standing on an اختبار.
      final studentUser = env.createStudent(
        id: 'exam_student_1',
        name: 'طالب الاختبار',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        // Standing on the juz-30 اختبار — session 68. The queue finds them by
        // their session's KIND, not by a magic number.
        sessionId: 'L1_J30_S68',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      supervisorRobot = SupervisorRobot(tester);

      await supervisorRobot.verifyDashboard();
      await supervisorRobot.goToExamQueue();

      // Assert
      await supervisorRobot.verifyStudentInQueue('طالب الاختبار');
    });

    testWidgets('Supervisor can conduct exam with passing result', (
      tester,
    ) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      final studentUser = env.createStudent(
        id: 'exam_student_2',
        name: 'أحمد الاختبار',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        sessionId: 'L1_J30_S68',
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

    testWidgets('Supervisor can conduct exam with failing result', (
      tester,
    ) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);
      final instituteId = await env.addInstitute();
      await env.assignSupervisorToInstitute(supervisor.id, instituteId);

      final studentUser = env.createStudent(
        id: 'exam_student_3',
        name: 'محمد الاختبار',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        sessionId: 'L1_J30_S68',
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

      // Create students standing on an اختبار.
      for (int i = 0; i < 3; i++) {
        final studentUser = env.createStudent(
          id: 'stats_student_$i',
          name: 'طالب $i',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          sessionId: 'L1_J30_S68',
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
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'sup_sard_student',
          name: 'طالب سرد المشرف',
        );
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
          // The hizb-59 سرد — session 30 in the real curriculum.
          sessionId: 'L1_J30_S30',
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
      },
    );

    testWidgets(
      'a student placed on a JUZ-tier Sard is assessed with no prior sessions '
      '(#flexible-start)',
      (tester) async {
        // A student arrives having already memorized juz 30, and is placed
        // directly on its juz-tier سرد — an assessment that belongs to NO hizb
        // and that the old model (hizb → 36 sessions, 35 = سرد) could not even
        // name. The app taught them none of it — they hold zero session records
        // — and the supervisor must still be able to assess them.
        const instituteId = 'placed_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        // Place the student through the production path, not a seeded document.
        // The session they are placed on — L1_J30_S67, the juz-30 سرد — is one
        // the seeded curriculum really contains.
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
                level: 1,
                juz: 30,
                session: 67,
              ),
            );

        // The anchor, and the facts copied from the curriculum, are persisted.
        final doc = await env.fakeFirestore
            .collection('students')
            .doc(created.student.id)
            .get();
        expect(doc.data()?['current_level'], 1);
        expect(doc.data()?['current_juz'], 30);
        expect(doc.data()?['current_session'], 67);
        expect(doc.data()?['current_session_id'], 'L1_J30_S67');
        expect(doc.data()?['current_session_kind'], 'sard');
        // A juz-tier سرد has no hizb at all — and the student's label is null,
        // not a fabricated 59.
        expect(doc.data()?['current_session_tier'], 'juz');
        expect(doc.data()?['current_hizb'], isNull);
        expect(doc.data()?['enrollment_position'], {
          'level': 1,
          'juz': 30,
          'session': 67,
        });

        // They hold no session records at all — nothing was taught in the app.
        final records = await env.fakeFirestore
            .collection('session_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(records.docs, isEmpty);

        // The supervisor conducts their سرد end-to-end regardless.
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

        // The supervisor can SEE what is being assessed: the curriculum's own
        // words for it — a whole juz, not "the hizb".
        expect(
          find.text('سرد الجزء رقم 30 كاملًا على المحفظ المتابع'),
          findsWidgets,
        );

        await supervisorRobot.enterSardErrors(2);
        await supervisorRobot.finishSard();
        await supervisorRobot.verifySardResult();
        await supervisorRobot.saveSardResult();

        await supervisorRobot.verifySardSaved();

        // And the record carries the assessment's SCOPE — the thing a
        // hizb-keyed record could never represent.
        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J30_S67');
        expect(sard['tier'], 'juz');
        expect(sard['juz_numbers'], [30]);
        expect(sard['hizb_number'], isNull);
        expect(
          sard['scope_label_ar'],
          'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
        );
      },
    );

    testWidgets(
      'a supervisor conducts a CUMULATIVE (level-tier) Sard: the label names '
      'all three juz, and the record persists them',
      (tester) async {
        // The last سرد of level 1 covers juz 28, 29 AND 30 — the level entire.
        // Nothing about it can be expressed as "the hizb".
        const instituteId = 'cumulative_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'cumulative_student',
          name: 'طالب السرد التراكمي',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        final studentId = await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          sessionId: 'L1_J28_S66', // the level's cumulative سرد
        );

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب السرد التراكمي');
        await supervisorRobot.verifySessionOverview();
        await supervisorRobot.verifySardAvailableForSupervisor();

        await supervisorRobot.startSard();
        await supervisorRobot.verifySardSession();

        // The scope is stated verbatim, and the instruction is worded for the
        // TIER — the whole level, not a hizb.
        expect(
          find.text(
            'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
          ),
          findsWidgets,
        );
        expect(find.textContaining('الأجزاء 28 و 29 و 30'), findsWidgets);

        await supervisorRobot.enterSardErrors(1);
        await supervisorRobot.finishSard();
        await supervisorRobot.verifySardResult();
        await supervisorRobot.saveSardResult();
        await supervisorRobot.verifySardSaved();

        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J28_S66');
        expect(sard['tier'], 'cumulative');
        expect(sard['juz_numbers'], [28, 29, 30]);
        expect(
          sard['scope_label_ar'],
          'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
        );
      },
    );

    testWidgets(
      'a supervisor conducts a JUZ-tier اختبار from the queue: the label names '
      'the juz, and the record persists its scope',
      (tester) async {
        const instituteId = 'juz_exam_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'juz_exam_student',
          name: 'طالب اختبار الجزء',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        final studentId = await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          // The juz-30 اختبار is session 68. The queue finds them because their
          // session's KIND is `exam` — the old `current_session == 36` filter
          // would have found nobody.
          sessionId: 'L1_J30_S68',
        );

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToExamQueue();
        await supervisorRobot.verifyExamQueueScreen();
        await supervisorRobot.verifyStudentInQueue('طالب اختبار الجزء');
        await supervisorRobot.tapStudentForExam('طالب اختبار الجزء');
        await supervisorRobot.verifyExamSession();

        // What is being examined, in the curriculum's own words.
        expect(
          find.text('اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات'),
          findsWidgets,
        );

        await supervisorRobot.enterExamErrors(2);
        await supervisorRobot.submitExamResult();
        await supervisorRobot.verifyExamResult();
        await supervisorRobot.saveExamResult();

        final examRecords = await env.fakeFirestore
            .collection('exam_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(examRecords.docs, hasLength(1));
        final exam = examRecords.docs.first.data();
        expect(exam['curriculum_session_id'], 'L1_J30_S68');
        expect(exam['tier'], 'juz');
        expect(exam['juz_numbers'], [30]);
        expect(exam['hizb_number'], isNull);
        expect(
          exam['scope_label_ar'],
          'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
        );
      },
    );

    testWidgets('Supervisor only sees students from assigned institutes', (
      tester,
    ) async {
      // Arrange
      final supervisor = env.createSupervisor();
      await env.setUp(authenticatedUser: supervisor);

      // Create two institutes
      final assignedInstitute = await env.addInstitute(name: 'معهد مخصص');
      final otherInstitute = await env.addInstitute(name: 'معهد آخر');

      // Only assign supervisor to one institute
      await env.assignSupervisorToInstitute(supervisor.id, assignedInstitute);

      // Create student in assigned institute
      final assignedStudent = env.createStudent(
        id: 'assigned_student',
        name: 'طالب المعهد المخصص',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(assignedStudent.id)
          .set(assignedStudent.toFirestore());
      await env.addStudent(
        userId: assignedStudent.id,
        instituteId: assignedInstitute,
        sessionId: 'L1_J30_S68',
      );

      // Create student in other institute
      final otherStudent = env.createStudent(
        id: 'other_student',
        name: 'طالب معهد آخر',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(otherStudent.id)
          .set(otherStudent.toFirestore());
      await env.addStudent(
        userId: otherStudent.id,
        instituteId: otherInstitute,
        sessionId: 'L1_J30_S68',
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
