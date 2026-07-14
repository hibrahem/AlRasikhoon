import 'package:flutter/widgets.dart';
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
        // Standing on the juz-30 اختبار — session 70. The queue finds them by
        // their session's KIND, not by a magic number.
        sessionId: 'L1_J30_S70',
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
        sessionId: 'L1_J30_S70',
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
        sessionId: 'L1_J30_S70',
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
          sessionId: 'L1_J30_S70',
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
          // The juz-30 اختبار is session 70. The queue finds them because their
          // session's KIND is `exam` — the old `current_session == 36` filter
          // would have found nobody.
          sessionId: 'L1_J30_S70',
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
        expect(exam['curriculum_session_id'], 'L1_J30_S70');
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
        sessionId: 'L1_J30_S70',
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
        sessionId: 'L1_J30_S70',
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

    testWidgets(
      'a supervisor cannot conduct a Sard: tapping a student shows read-only '
      'progress, with no سرد action anywhere (al_rasikhoon-801)',
      (tester) async {
        // سرد is teacher-conducted (al_rasikhoon-801). The supervisor keeps its
        // institute-scoped roster (#28) but has NO Sard doorway: tapping a
        // student lands on the read-only progress screen, which never offers an
        // action that would start, advance, or end a session.
        const instituteId = 'sard_denied_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'sup_sard_denied_student',
          name: 'طالب المشرف',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          // The hizb-59 سرد — the exact session a supervisor used to be able to
          // conduct under #29.
          sessionId: 'L1_J30_S31',
        );

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب المشرف');
        await supervisorRobot.pumpAndSettle();

        // Assert — the read-only progress screen, and no Sard action at all.
        expect(find.text('تقدم الطالب'), findsOneWidget);
        expect(find.text('بدء السرد'), findsNothing);
        expect(find.text('بدء الحلقة'), findsNothing);
      },
    );

    testWidgets(
      'a supervisor who crafts/pushes a teacher Sard URL is redirected away '
      'and never sees the Sard session screen (guard regression, al_rasikhoon-801)',
      (tester) async {
        // The router redirect guard is the navigation-level backstop for Sard
        // being teacher-only. This pins that the guard still fires on a real
        // Sard route even after anchoring the match to a path segment (it
        // used to be a loose `.contains('/sard')`).
        final supervisor = env.createSupervisor();
        await env.setUp(authenticatedUser: supervisor);
        final instituteId = await env.addInstitute();
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);
        await supervisorRobot.verifyDashboard();

        // Craft the URL directly — no UI offers this path to a supervisor.
        await supervisorRobot.pushLocation(
          '/teacher/session/some_student/sard',
        );

        // Assert — bounced back to the supervisor dashboard, never the Sard
        // session screen (whose app bar title is exactly 'السرد').
        expect(find.text('السرد'), findsNothing);
        expect(find.text('الراسخون - المشرف'), findsOneWidget);
      },
    );

    testWidgets(
      'a supervisor taps an institute student whose doc id merely STARTS WITH '
      '"sard": the guard must not over-match and must still land on تقدم '
      'الطالب (al_rasikhoon-801)',
      (tester) async {
        // Regression for the false positive in the old `.contains('/sard')`
        // guard: `matchedLocation` carries substituted path params, so a
        // student doc id beginning with "sard" made
        // `/supervisor/students/sardOoPs123` contain "/sard" and the
        // supervisor was wrongly bounced to their dashboard before تقدم
        // الطالب ever rendered.
        const instituteId = 'sard_id_prefix_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final studentUser = env.createStudent(
          id: 'sardOoPs123_user',
          name: 'طالب معرفه يبدأ بسرد',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        await env.addStudent(
          id: 'sardOoPs123',
          userId: studentUser.id,
          instituteId: instituteId,
          sessionId: 'L1_J30_S31',
        );

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب معرفه يبدأ بسرد');
        await supervisorRobot.pumpAndSettle();

        // Assert — the guard must NOT fire: the supervisor lands on the
        // read-only progress screen exactly as for any other student.
        expect(find.text('تقدم الطالب'), findsOneWidget);
      },
    );

    testWidgets(
      'a supervisor assigns a teacher to a teacher-less student, and that '
      'student then APPEARS IN THAT TEACHER\'S الطلاب list (al_rasikhoon-6bw)',
      (tester) async {
        // Arrange — a student stranded exactly the way production already
        // has some: institute-scoped, but with no teacher_id at all. Nobody
        // could ever conduct their حلقة or their سرد until this is fixed.
        const instituteId = 'rescue_institute';
        final supervisor = env.createSupervisor().copyWith(
          instituteId: instituteId,
        );
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        final teacher = env.createTeacher(
          id: 'rescue_teacher',
          name: 'المعلم المنقذ',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(teacher.id)
            .set(teacher.toFirestore());
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        final studentUser = env.createStudent(
          id: 'orphan_student',
          name: 'الطالب المهجور',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        // teacherId omitted: null — the exact stranded state al_rasikhoon-6bw
        // fixes half (2) of.
        await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          sessionId: 'L1_J30_S1',
        );

        // Act (as the supervisor) — the teacher-less marker is visible, then
        // the supervisor rescues the student through the actions sheet.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        expect(find.text('بلا معلم'), findsOneWidget);

        await supervisorRobot.longPressStudent('الطالب المهجور');
        await supervisorRobot.tapAssignTeacherAction();
        await supervisorRobot.selectTeacherInAssignDialog('المعلم المنقذ');
        await supervisorRobot.confirmAssignTeacher();

        // The marker is gone from the supervisor's own list once assigned.
        await supervisorRobot.pumpAndSettle();
        expect(find.text('بلا معلم'), findsNothing);

        // Assert the end state that actually matters: switch identity to the
        // rescuing teacher (same fixture data, fresh remount — see
        // TestEnvironment.overridesForUser) and confirm the student is now
        // reachable in THEIR الطلاب list, not merely that a field changed.
        final teacherOverrides = await env.overridesForUser(teacher);
        await tester.pumpWidget(
          TestApp(key: UniqueKey(), overrides: teacherOverrides),
        );
        final teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.verifyStudentInList('الطالب المهجور');
      },
    );
  });
}
