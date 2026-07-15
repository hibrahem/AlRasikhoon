import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSessionCache extends Mock implements SessionCache {}

class MockUser extends Mock implements User {}

UserModel _user({
  String id = 'u1',
  UserRole role = UserRole.teacher,
  bool isActive = true,
}) {
  return UserModel(
    id: id,
    username: 'ustadh',
    email: 'u@x.local',
    name: 'الأستاذ',
    role: role,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  late MockFirebaseService firebaseService;
  late MockUserRepository userRepository;
  late MockSessionCache sessionCache;
  late StreamController<User?> authStateController;

  setUpAll(() {
    registerFallbackValue(_user());
  });

  setUp(() {
    firebaseService = MockFirebaseService();
    userRepository = MockUserRepository();
    sessionCache = MockSessionCache();
    authStateController = StreamController<User?>.broadcast();

    when(
      () => firebaseService.authStateChanges,
    ).thenAnswer((_) => authStateController.stream);
    when(() => firebaseService.signOut()).thenAnswer((_) async {});
    when(() => sessionCache.cacheUser(any())).thenAnswer((_) async {});
    when(() => sessionCache.clear()).thenAnswer((_) async {});
  });

  tearDown(() => authStateController.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(firebaseService),
        userRepositoryProvider.overrideWithValue(userRepository),
        sessionCacheProvider.overrideWithValue(sessionCache),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build seeds appUser from the cache (optimistic, no network)', () {
    when(
      () => sessionCache.readUser(),
    ).thenReturn(_user(role: UserRole.teacher));

    final container = makeContainer();
    final state = container.read(authRepositoryProvider);

    expect(state.appUser, isNotNull);
    expect(state.appUser!.role, UserRole.teacher);
    verifyNever(() => userRepository.getUserById(any()));
  });

  test('authStateChanges(null) clears the cache and resets state', () async {
    when(() => sessionCache.readUser()).thenReturn(_user());
    final container = makeContainer();
    container.read(authRepositoryProvider); // instantiate

    authStateController.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authRepositoryProvider).appUser, isNull);
    verify(() => sessionCache.clear()).called(1);
  });

  test('background refresh reconciles a changed role and re-caches', () async {
    when(
      () => sessionCache.readUser(),
    ).thenReturn(_user(role: UserRole.teacher));
    when(
      () => userRepository.getUserById('u1'),
    ).thenAnswer((_) async => _user(role: UserRole.supervisor));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authRepositoryProvider).appUser!.role,
      UserRole.supervisor,
    );
    verify(() => sessionCache.cacheUser(any())).called(1);
  });

  test('refresh finding a disabled account signs out', () async {
    when(() => sessionCache.readUser()).thenReturn(_user());
    when(
      () => userRepository.getUserById('u1'),
    ).thenAnswer((_) async => _user(isActive: false));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    verify(() => firebaseService.signOut()).called(1);
    expect(container.read(authRepositoryProvider).appUser, isNull);
  });

  test('refresh failure keeps the cached optimistic state', () async {
    when(
      () => sessionCache.readUser(),
    ).thenReturn(_user(role: UserRole.teacher));
    when(
      () => userRepository.getUserById('u1'),
    ).thenThrow(Exception('offline'));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authRepositoryProvider).appUser!.role,
      UserRole.teacher,
    );
  });
}
