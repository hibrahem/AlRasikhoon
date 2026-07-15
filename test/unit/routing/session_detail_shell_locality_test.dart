import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/core/constants/app_constants.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';
import 'package:al_rasikhoon/routing/app_router.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

List<StatefulShellRoute> _shellRoutes(GoRouter router) {
  return router.configuration.routes.whereType<StatefulShellRoute>().toList();
}

/// Every GoRoute path reachable inside a shell, across all its branches
/// (recursing through nested sub-routes).
Set<String> _pathsIn(StatefulShellRoute shell) {
  final paths = <String>{};
  void collect(List<RouteBase> routes) {
    for (final route in routes) {
      if (route is GoRoute) {
        paths.add(route.path);
        collect(route.routes);
      }
    }
  }

  for (final branch in shell.branches) {
    collect(branch.routes);
  }
  return paths;
}

/// The shell that owns [rootPath] as the entry path of its first branch.
StatefulShellRoute _shellStartingAt(GoRouter router, String rootPath) {
  return _shellRoutes(router).firstWhere(
    (s) => (s.branches.first.routes.first as GoRoute).path == rootPath,
    orElse: () => throw StateError('no shell starting at $rootPath'),
  );
}

void main() {
  late ProviderContainer container;
  late GoRouter router;
  late Directory tempDir;
  late Box sessionBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'session_detail_shell_locality_test',
    );
    Hive.init(tempDir.path);
    sessionBox = await Hive.openBox(AppConstants.boxSession);

    final mockFirebaseService = _MockFirebaseService();
    when(
      () => mockFirebaseService.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        userRepositoryProvider.overrideWithValue(_MockUserRepository()),
        localStorageServiceProvider.overrideWithValue(
          _MockLocalStorageService(),
        ),
        sessionBoxProvider.overrideWithValue(sessionBox),
      ],
    );
    router = container.read(routerProvider);
  });

  tearDown(() async {
    container.dispose();
    await sessionBox.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // Regression for al_rasikhoon-3hn: opening a session record from a student's
  // progress view must stay inside the shell that showed the progress view.
  // The shared StudentProgressScreen is reused by both admin and supervisor,
  // so each shell needs its OWN session-detail route — pushing the student
  // shell's route from another shell crosses shells and dumps the user into
  // the student UI.

  test('admin shell owns its student session-detail route', () {
    final adminShell = _shellStartingAt(router, AppRoutes.adminDashboard);

    expect(
      _pathsIn(adminShell),
      contains(AppRoutes.adminStudentSessionDetail),
      reason:
          'admin must reach a session record without leaving the admin shell '
          '(al_rasikhoon-3hn)',
    );
  });

  test('supervisor shell owns its student session-detail route', () {
    final supervisorShell = _shellStartingAt(
      router,
      AppRoutes.supervisorDashboard,
    );

    expect(
      _pathsIn(supervisorShell),
      contains(AppRoutes.supervisorStudentSessionDetail),
      reason:
          'supervisor must reach a session record without leaving the '
          'supervisor shell (al_rasikhoon-3hn)',
    );
  });

  test('the student session-detail route lives only in the student shell', () {
    for (final shell in _shellRoutes(router)) {
      final startsStudentShell =
          (shell.branches.first.routes.first as GoRoute).path ==
          AppRoutes.studentDashboard;
      final hasStudentDetail = _pathsIn(
        shell,
      ).contains(AppRoutes.sessionDetail);

      expect(
        hasStudentDetail,
        startsStudentShell,
        reason:
            'AppRoutes.sessionDetail is the STUDENT shell route; no other '
            'shell may register or push it (al_rasikhoon-3hn)',
      );
    }
  });
}
