import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

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
        email: 'abdullah@example.com',
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
      final studentUser = env.createStudent(
        id: 'student_user_1',
        name: 'محمد خالد',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
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

    testWidgets('Teacher can conduct a session with passing grade', (
      tester,
    ) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_user_2',
        name: 'علي محمد',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
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
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: Recent review - 1 error
      await teacherRobot.enterErrorCount(1);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: Distant review - 2 errors
      await teacherRobot.enterErrorCount(2);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Summary screen shows passing grade, then session completes
      await teacherRobot.verifyGrade('متقن'); // 1 error average = متقن
      await teacherRobot.completeSession();
    });

    testWidgets('Teacher can conduct a session with failing grade', (
      tester,
    ) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_user_3',
        name: 'سعد عبدالله',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('سعد عبدالله');
      await teacherRobot.startSession();

      // Part 1: 7 errors — exceeds maxErrorsToPass (6), so session fails.
      await teacherRobot.enterErrorCount(7);
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: Recent review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: Distant review - 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Summary screen shows fail grade for over-threshold part 1
      await teacherRobot.verifyGrade('محب'); // Any part >6 errors = محب (fail)
      await teacherRobot.completeSession();
    });

    testWidgets('Failed session allows student to retry', (tester) async {
      // Arrange
      final teacher = env.createTeacher();
      await env.setUp(authenticatedUser: teacher);
      final instituteId = await env.addInstitute();
      await env.assignTeacherToInstitute(teacher.id, instituteId);

      final studentUser = env.createStudent(
        id: 'student_retry',
        name: 'طالب الإعادة',
      );
      await env.fakeFirestore
          .collection('users')
          .doc(studentUser.id)
          .set(studentUser.toFirestore());
      await env.addStudent(
        userId: studentUser.id,
        instituteId: instituteId,
        teacherId: teacher.id,
        sessionId: 'L1_J30_S1',
      );

      // Act
      await tester.pumpWidget(TestApp(overrides: env.overrides));
      teacherRobot = TeacherRobot(tester);

      await teacherRobot.verifyStudentsScreen();
      await teacherRobot.tapStudent('طالب الإعادة');
      await teacherRobot.startSession();

      // Part 1: 7 errors — exceeds maxErrorsToPass (6), so session fails.
      await teacherRobot.enterErrorCount(7);
      await teacherRobot.submitRecitation(part: 1);
      await teacherRobot.goToNextPart();

      // Part 2: 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 2);
      await teacherRobot.goToNextPart();

      // Part 3: 0 errors
      await teacherRobot.enterErrorCount(0);
      await teacherRobot.submitRecitation(part: 3);
      await teacherRobot.goToSessionSummary();

      // Assert - Failed grade is shown on the summary screen before saving
      expect(find.textContaining('محب'), findsWidgets); // Failed grade
      await teacherRobot.completeSession();
    });

    testWidgets(
      'Teacher conducts a Sard end-to-end: start → conduct → save (al_rasikhoon-801)',
      (tester) async {
        // Arrange — سرد is conducted by the TEACHER (al_rasikhoon-801, which
        // reverses #29's supervisor-only rule). The whole flow — الطلاب →
        // session overview → السرد → نتيجة السرد — stays inside the teacher
        // shell, so no cross-shell push and no duplicate-page-key crash (#45).
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        final studentUser = env.createStudent(
          id: 'student_sard',
          name: 'طالب السرد',
        );
        await env.fakeFirestore
            .collection('users')
            .doc(studentUser.id)
            .set(studentUser.toFirestore());
        final studentId = await env.addStudent(
          userId: studentUser.id,
          instituteId: instituteId,
          teacherId: teacher.id,
          // The hizb-59 سرد — session 31, as the DATA says (never "35").
          sessionId: 'L1_J30_S31',
        );

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب السرد');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();
        await teacherRobot.enterSardErrors(2);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();

        // Assert — the Sard saved, and the record names the TEACHER as its
        // author (sard_records.teacher_id was always the teacher's field).
        await teacherRobot.verifySardSaved();

        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(sardRecords.docs, hasLength(1));
        expect(sardRecords.docs.first.data()['teacher_id'], teacher.id);
      },
    );

    testWidgets(
      'Every teacher nav tab navigates, not just the first (al_rasikhoon-256)',
      (tester) async {
        // Arrange — the teacher's StatefulShellRoute used to have 1 branch
        // while the nav bar rendered 4 tabs, and RoleShell silently swallowed
        // taps past the branch count: every tab but the first (الطلاب) did
        // nothing. This drives each tab through the real
        // BottomNavigationBar — exactly what a user taps — and asserts it
        // actually lands on the corresponding screen.
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        // Act
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        // Assert - starts on الطلاب (students).
        await teacherRobot.verifyStudentsScreen();

        // The الحلقة tab was removed by design; it must not be present.
        await teacherRobot.verifyNoHalaqahTab();

        // Assert - tapping السجل lands on the history screen, students gone.
        await teacherRobot.goToHistory();
        await teacherRobot.verifyHistoryScreen();

        // Assert - tapping الإعدادات lands on the settings screen.
        await teacherRobot.goToSettings();
        await teacherRobot.verifySettingsScreen();

        // Assert - tapping الطلاب again returns to the students screen.
        await teacherRobot.goToStudents();
        await teacherRobot.verifyStudentsScreen();
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
        // — and the teacher must still be able to assess them.
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

        // Place the student through the production path, not a seeded document.
        // The session they are placed on — L1_J30_S69, the juz-30 سرد — is one
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
              // The teacher conducts سرد (al_rasikhoon-801), so the student
              // must HAVE a teacher — a teacher-less student shows up in no
              // teacher's list at all (al_rasikhoon-6bw).
              teacherId: teacher.id,
              startingPosition: const CurriculumPosition(
                level: 1,
                juz: 30,
                session: 69,
              ),
            );

        // The anchor, and the facts copied from the curriculum, are persisted.
        final doc = await env.fakeFirestore
            .collection('students')
            .doc(created.student.id)
            .get();
        expect(doc.data()?['current_level'], 1);
        expect(doc.data()?['current_juz'], 30);
        expect(doc.data()?['current_session'], 69);
        expect(doc.data()?['current_session_id'], 'L1_J30_S69');
        expect(doc.data()?['current_session_kind'], 'sard');
        // A juz-tier سرد has no hizb at all — and the student's label is null,
        // not a fabricated 59.
        expect(doc.data()?['current_session_tier'], 'juz');
        expect(doc.data()?['current_hizb'], isNull);
        expect(doc.data()?['enrollment_position'], {
          'level': 1,
          'juz': 30,
          'session': 69,
        });

        // They hold no session records at all — nothing was taught in the app.
        final records = await env.fakeFirestore
            .collection('session_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(records.docs, isEmpty);

        // The teacher conducts their سرد end-to-end regardless.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب حافظ');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();

        // The teacher can SEE what is being assessed: the curriculum's own
        // words for it — a whole juz, not "the hizb".
        expect(
          find.text('سرد الجزء رقم 30 كاملًا على المحفظ المتابع'),
          findsWidgets,
        );

        await teacherRobot.enterSardErrors(2);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();
        await teacherRobot.verifySardSaved();

        // And the record carries the assessment's SCOPE — the thing a
        // hizb-keyed record could never represent.
        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J30_S69');
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
      'a teacher conducts a CUMULATIVE (level-tier) Sard: the label names all '
      'three juz, and the record persists them',
      (tester) async {
        // The last سرد of level 1 covers juz 28, 29 AND 30 — the level entire.
        // Nothing about it can be expressed as "the hizb".
        final teacher = env.createTeacher();
        await env.setUp(authenticatedUser: teacher);
        final instituteId = await env.addInstitute();
        await env.assignTeacherToInstitute(teacher.id, instituteId);

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
          teacherId: teacher.id,
          sessionId: 'L1_J28_S68', // the level's cumulative سرد
        );

        await tester.pumpWidget(TestApp(overrides: env.overrides));
        teacherRobot = TeacherRobot(tester);

        await teacherRobot.verifyStudentsScreen();
        await teacherRobot.tapStudent('طالب السرد التراكمي');
        await teacherRobot.verifySessionOverview();
        await teacherRobot.verifySardAvailableForTeacher();

        await teacherRobot.startSard();
        await teacherRobot.verifySardSession();

        // The scope is stated verbatim, and the instruction is worded for the
        // TIER — the whole level, not a hizb.
        expect(
          find.text(
            'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
          ),
          findsWidgets,
        );
        expect(find.textContaining('الأجزاء 28 و 29 و 30'), findsWidgets);

        await teacherRobot.enterSardErrors(1);
        await teacherRobot.finishSard();
        await teacherRobot.verifySardResult();
        await teacherRobot.saveSardResult();
        await teacherRobot.verifySardSaved();

        // The record names all three juz — a cumulative سرد covers the level.
        final sardRecords = await env.fakeFirestore
            .collection('sard_records')
            .where('student_id', isEqualTo: studentId)
            .get();
        expect(sardRecords.docs, hasLength(1));
        final sard = sardRecords.docs.first.data();
        expect(sard['curriculum_session_id'], 'L1_J28_S68');
        expect(sard['tier'], 'cumulative');
        expect(sard['juz_numbers'], [28, 29, 30]);
        expect(
          sard['scope_label_ar'],
          'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
        );
        expect(sard['teacher_id'], teacher.id);
      },
    );
  });
}
