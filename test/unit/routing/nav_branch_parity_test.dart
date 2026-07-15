import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/widgets/nav_destinations.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

class _MockSessionCache extends Mock implements SessionCache {}

/// Every StatefulShellRoute in the app, keyed by the root path of its first
/// branch — which is also the first destination of the role that owns it.
List<StatefulShellRoute> _shellRoutes(GoRouter router) {
  return router.configuration.routes.whereType<StatefulShellRoute>().toList();
}

String _firstPathOf(StatefulShellBranch branch) {
  final route = branch.routes.first as GoRoute;
  return route.path;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    final mockFirebaseService = _MockFirebaseService();
    when(
      () => mockFirebaseService.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());

    final mockSessionCache = _MockSessionCache();
    when(() => mockSessionCache.readUser()).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        userRepositoryProvider.overrideWithValue(_MockUserRepository()),
        localStorageServiceProvider.overrideWithValue(
          _MockLocalStorageService(),
        ),
        sessionCacheProvider.overrideWithValue(mockSessionCache),
      ],
    );
    router = container.read(routerProvider);
  });

  tearDown(() => container.dispose());

  test('every role shell has one branch per nav destination', () {
    final shells = _shellRoutes(router);

    // Each role's shell is identified by the root path of its first branch.
    for (final role in UserRole.values) {
      final destinations = destinationsFor(role);
      final shell = shells.firstWhere(
        (s) => _firstPathOf(s.branches.first) == destinations.first.rootPath,
        orElse: () => throw StateError('no shell route for $role'),
      );

      expect(
        shell.branches.length,
        destinations.length,
        reason:
            '$role renders ${destinations.length} nav tabs but its shell has '
            '${shell.branches.length} branches — tabs beyond the branch count '
            'are silently dead (al_rasikhoon-256)',
      );

      // Order matters: the Nth tab must select the Nth branch.
      expect(
        shell.branches.map(_firstPathOf).toList(),
        destinations.map((d) => d.rootPath).toList(),
        reason: '$role nav order does not match its branch order',
      );
    }
  });
}
