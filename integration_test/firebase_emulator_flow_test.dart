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

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/firebase_emulator_app.dart';
import 'helpers/test_robots.dart';

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
          currentLevel: 1,
          currentSession: 5,
        );

        // Act — boot the app against the emulator-backed providers.
        await tester.pumpWidget(EmulatorTestApp(overrides: env.overrides));
        studentRobot = StudentRobot(tester);

        // Assert — dashboard renders the values we wrote to the emulator.
        await studentRobot.verifyDashboard();
        await studentRobot.verifyCurrentLevel(1);
      },
    );
  });
}
