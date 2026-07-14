/// Single E2E flow that exercises the app against the real `cloud_firestore`
/// SDK pointed at the local Firestore emulator (instead of `fake_cloud_firestore`).
///
/// Goal: catch issues that the fake-Firestore tests can't — serialization,
/// query semantics, index behavior — for the most common student journey.
///
/// How to run (iOS simulator):
///   1. firebase emulators:start --only firestore,auth
///   2. flutter test integration_test/firebase_emulator_flow_test.dart \
///        -d IOS_SIM_ID
///
/// On Android emulator add `--dart-define=EMULATOR_HOST=10.0.2.2`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/firebase_emulator_app.dart';
import '../test/e2e/helpers/test_robots.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Emulator E2E — Student dashboard', () {
    late EmulatorTestEnvironment env;
    late StudentRobot studentRobot;

    setUpAll(() async {
      await initEmulatorFirebase();
      final reachable = await isEmulatorReachable();
      if (!reachable) {
        fail(
          'Firestore emulator not reachable. Start it with:\n'
          '  firebase emulators:start --only firestore,auth',
        );
      }
    });

    setUp(() {
      env = EmulatorTestEnvironment();
    });

    testWidgets(
      'student logs in and dashboard reflects seeded progress from emulator Firestore',
      (tester) async {
        // Arrange — seed the same shape of data a real student would have:
        // user doc, institute, student record at level 1 / session 5.
        final studentUser = env.createStudent(name: 'سعد الإمام');
        await env.setUp(authenticatedUser: studentUser);
        final instituteId = await env.addInstitute();
        await env.addStudentRecord(
          userId: studentUser.id,
          instituteId: instituteId,
          sessionId: 'L1_J30_S5',
        );

        // Act — boot the app against the emulator-backed providers.
        await tester.pumpWidget(EmulatorTestApp(overrides: env.overrides));
        studentRobot = StudentRobot(tester);

        // Assert — dashboard renders the values we wrote to the emulator.
        await studentRobot.verifyDashboard();
        await studentRobot.verifyCurrentLevel(1);
      },
    );

    // al_rasikhoon-5mc. Seeding a student used to flip the seed account's role
    // to `teacher` (the `students` create rule requires isTeacher(), and a
    // super_admin is NOT a teacher) and flip it back afterwards. Against the
    // current rules that is a ONE-WAY DOOR: only a super_admin may change a
    // role, so once the account demoted itself it could never promote itself
    // back, and the restore died with `permission-denied` — taking every
    // emulator test that seeds a student down with it.
    //
    // Seeding now goes through the emulator's admin endpoint and touches no
    // role at all. These two assertions are what would have caught it.
    testWidgets('seeding a student neither fails nor disturbs the seed account', (
      tester,
    ) async {
      final studentUser = env.createStudent(name: 'طالب البذر');
      await env.setUp(authenticatedUser: studentUser);
      final instituteId = await env.addInstitute();

      // 1. It must not throw. (It used to throw permission-denied.)
      await env.addStudentRecord(
        userId: studentUser.id,
        instituteId: instituteId,
        sessionId: 'L1_J30_S5',
        teacherId: 'teacher-1',
      );

      // 2. The seed account must still be super_admin. The old code left it
      //    demoted to `teacher` whenever the restore failed, so every LATER
      //    super_admin seed write in the same test would fail too.
      final seedUid = FirebaseAuth.instance.currentUser!.uid;
      final seedDoc = await env.firestore
          .collection('users')
          .doc(seedUid)
          .get();
      expect(
        seedDoc.data()!['role'],
        'super_admin',
        reason: 'seeding must never re-role the seed account',
      );

      // 3. A super_admin write AFTER seeding a student still works — the proof
      //    that the account was not left demoted.
      await env.addInstitute(id: 'institute_after_seed');

      // 4. The hand-rolled REST encoding must round-trip through the real SDK
      //    with the right TYPES — an int must come back an int, not a string.
      final student = await env.firestore
          .collection('students')
          .doc('student_record_emu')
          .get();
      final data = student.data()!;
      expect(data['current_level'], 1);
      expect(data['current_order_in_level'], isA<int>());
      expect(data['teacher_id'], 'teacher-1');
      expect(data['is_active'], isTrue);
      expect(data['unlocked_levels'], [1]);
      expect(data['created_at'], isA<Timestamp>());
    });
  });
}
