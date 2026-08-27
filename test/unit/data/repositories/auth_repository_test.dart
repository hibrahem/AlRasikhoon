import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/core/telemetry/usage_analytics.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSessionCache extends Mock implements SessionCache {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeFirebaseAuthException extends Fake implements FirebaseAuthException {
  @override
  final String code;

  @override
  final String? message;

  FakeFirebaseAuthException({required this.code, this.message});
}

class _RecordingReporter implements ErrorReporter {
  final List<({Object error, String? reason})> recorded = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    recorded.add((error: error, reason: reason));
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

class _RecordingAnalytics implements UsageAnalytics {
  final List<AnalyticsEvent> events = [];

  @override
  void record(AnalyticsEvent event) => events.add(event);

  @override
  void setUserProperties({required String role, required String instituteId}) {}

  @override
  void clearUserProperties() {}

  @override
  void recordScreenView(String templatedRoute) {}
}

void main() {
  late MockFirebaseService mockFirebaseService;
  late MockUserRepository mockUserRepository;
  late MockSessionCache mockSessionCache;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      UserModel(
        id: 'fallback',
        email: 'fallback@x.local',
        name: 'fallback',
        role: UserRole.teacher,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockUserRepository = MockUserRepository();
    mockSessionCache = MockSessionCache();

    when(
      () => mockFirebaseService.authStateChanges,
    ).thenAnswer((_) => Stream.empty());
    when(() => mockSessionCache.readUser()).thenReturn(null);
    when(() => mockSessionCache.cacheUser(any())).thenAnswer((_) async {});
    when(() => mockSessionCache.clear()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        sessionCacheProvider.overrideWithValue(mockSessionCache),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  UserModel buildUser({
    String id = 'user-id',
    String username = 'test_user',
    String email = 'test@example.com',
    String name = 'Test User',
    UserRole role = UserRole.teacher,
    UserAuthProvider authProvider = UserAuthProvider.emailPassword,
  }) {
    return UserModel(
      id: id,
      username: username,
      email: email,
      name: name,
      role: role,
      authProvider: authProvider,
      createdAt: DateTime.now(),
    );
  }

  group('AuthRepository', () {
    group('signInWithUsernameAndPassword', () {
      test('signs in successfully and loads app user by username', () async {
        const username = 'mohammed.a';
        const password = 'pass123';
        const synthesized = 'mohammed.a@alrasikhoon.local';
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = buildUser(id: uid, username: username);

        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: synthesized,
            password: password,
          ),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(uid);
        when(
          () => mockUserRepository.getUserByUsername(username),
        ).thenAnswer((_) async => appUser);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: username,
          password: password,
        );

        expect(result, isNotNull);
        expect(result?.id, uid);
        expect(result?.username, username);
        verify(() => mockSessionCache.cacheUser(appUser)).called(1);
      });

      test(
        'a successful sign-in records LoginSucceeded with the role',
        () async {
          const username = 'mohammed.a';
          const password = 'pass123';
          const synthesized = 'mohammed.a@alrasikhoon.local';
          const uid = 'firebase-uid';
          final mockUserCredential = MockUserCredential();
          final mockUser = MockUser();
          final appUser = buildUser(
            id: uid,
            username: username,
            role: UserRole.teacher,
          );
          final analytics = _RecordingAnalytics();

          when(
            () => mockFirebaseService.signInWithEmailPassword(
              email: synthesized,
              password: password,
            ),
          ).thenAnswer((_) async => mockUserCredential);
          when(() => mockUserCredential.user).thenReturn(mockUser);
          when(() => mockUser.uid).thenReturn(uid);
          when(
            () => mockUserRepository.getUserByUsername(username),
          ).thenAnswer((_) async => appUser);

          final scopedContainer = ProviderContainer(
            overrides: [
              firebaseServiceProvider.overrideWithValue(mockFirebaseService),
              userRepositoryProvider.overrideWithValue(mockUserRepository),
              sessionCacheProvider.overrideWithValue(mockSessionCache),
              usageAnalyticsProvider.overrideWithValue(analytics),
            ],
          );
          addTearDown(scopedContainer.dispose);

          final authRepo = scopedContainer.read(
            authRepositoryProvider.notifier,
          );
          await authRepo.signInWithUsernameAndPassword(
            username: username,
            password: password,
          );

          expect(analytics.events.whereType<LoginSucceeded>(), hasLength(1));
          expect(
            analytics.events.whereType<LoginSucceeded>().single.role,
            'teacher',
          );
        },
      );

      test('a failed login records a stable reason code, never the username '
          'or an email address', () async {
        final analytics = _RecordingAnalytics();

        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'wrong-password'));

        final scopedContainer = ProviderContainer(
          overrides: [
            firebaseServiceProvider.overrideWithValue(mockFirebaseService),
            userRepositoryProvider.overrideWithValue(mockUserRepository),
            sessionCacheProvider.overrideWithValue(mockSessionCache),
            usageAnalyticsProvider.overrideWithValue(analytics),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final authRepo = scopedContainer.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: 'mohammed.a',
          password: 'wrong',
        );

        expect(result, isNull);
        expect(analytics.events.whereType<LoginFailed>(), hasLength(1));
        final event = analytics.events.whereType<LoginFailed>().single;
        expect(event.reasonCode, 'wrong-password');

        final parameterValues = event.parameters.values
            .map((v) => v.toString())
            .join(' ');
        expect(parameterValues.contains('@'), isFalse);
        expect(parameterValues.contains('mohammed.a'), isFalse);
      });

      test('lowercases and trims the username before sign-in', () async {
        const username = '  Mohammed.A  ';
        const synthesized = 'mohammed.a@alrasikhoon.local';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = buildUser(id: 'uid', username: 'mohammed.a');

        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: synthesized,
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('uid');
        when(
          () => mockUserRepository.getUserByUsername('mohammed.a'),
        ).thenAnswer((_) async => appUser);

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithUsernameAndPassword(
          username: username,
          password: 'pass123',
        );

        verify(
          () => mockFirebaseService.signInWithEmailPassword(
            email: synthesized,
            password: 'pass123',
          ),
        ).called(1);
      });

      test('falls back to UID lookup when username lookup misses', () async {
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = buildUser(id: uid);

        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(uid);
        when(
          () => mockUserRepository.getUserByUsername(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockUserRepository.getUserById(uid),
        ).thenAnswer((_) async => appUser);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: 'someone',
          password: 'pass123',
        );

        expect(result, isNotNull);
        verify(() => mockUserRepository.getUserById(uid)).called(1);
      });

      test('sets account_not_found when no Firestore doc exists', () async {
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn('uid');
        when(
          () => mockUserRepository.getUserByUsername(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockUserRepository.getUserById(any()),
        ).thenAnswer((_) async => null);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: 'orphan',
          password: 'pass123',
        );

        expect(result, isNull);
        expect(
          container.read(authRepositoryProvider).error,
          'account_not_found',
        );
      });

      test('maps wrong-password to Arabic error', () async {
        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'wrong-password'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: 'mohammed.a',
          password: 'wrong',
        );

        expect(result, isNull);
        expect(
          container.read(authRepositoryProvider).error,
          'اسم المستخدم أو كلمة المرور غير صحيحة',
        );
      });

      test('maps user-not-found to Arabic error', () async {
        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'user-not-found'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithUsernameAndPassword(
          username: 'ghost',
          password: 'pass123',
        );

        expect(
          container.read(authRepositoryProvider).error,
          'لا يوجد حساب بهذا الاسم',
        );
      });

      test('clears loading state after error', () async {
        when(
          () => mockFirebaseService.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'wrong-password'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithUsernameAndPassword(
          username: 'x',
          password: 'y',
        );

        expect(container.read(authRepositoryProvider).isLoading, isFalse);
      });
    });

    // setPasswordForUser is intentionally not unit-tested — it just calls
    // the setUserPassword Cloud Function (covered by functions/test/).

    group('updateOwnProfile', () {
      test('writes the profile fields, refreshes the app user from the server, '
          'and re-caches the session', () async {
        final cached = buildUser(id: 'uid-1', name: 'Old Name');
        final refreshed = buildUser(id: 'uid-1', name: 'New Name');
        when(() => mockSessionCache.readUser()).thenReturn(cached);
        when(
          () => mockUserRepository.updateProfileFields(
            userId: 'uid-1',
            name: 'New Name',
            phone: '+966500000001',
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockUserRepository.getUserById('uid-1'),
        ).thenAnswer((_) async => refreshed);

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.updateOwnProfile(
          name: 'New Name',
          phone: '+966500000001',
        );

        verify(
          () => mockUserRepository.updateProfileFields(
            userId: 'uid-1',
            name: 'New Name',
            phone: '+966500000001',
          ),
        ).called(1);
        expect(container.read(authRepositoryProvider).appUser, refreshed);
        expect(
          container.read(authRepositoryProvider).appUser?.name,
          'New Name',
        );
        verify(() => mockSessionCache.cacheUser(refreshed)).called(1);
      });

      test(
        'falls back to a local copy when the post-write refetch misses',
        () async {
          final cached = buildUser(id: 'uid-1', name: 'Old Name');
          when(() => mockSessionCache.readUser()).thenReturn(cached);
          when(
            () => mockUserRepository.updateProfileFields(
              userId: any(named: 'userId'),
              name: any(named: 'name'),
              phone: any(named: 'phone'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockUserRepository.getUserById('uid-1'),
          ).thenAnswer((_) async => null);

          final authRepo = container.read(authRepositoryProvider.notifier);
          await authRepo.updateOwnProfile(name: 'New Name', phone: null);

          expect(
            container.read(authRepositoryProvider).appUser?.name,
            'New Name',
          );
        },
      );

      test('throws when no user is signed in', () async {
        final authRepo = container.read(authRepositoryProvider.notifier);
        expect(
          () => authRepo.updateOwnProfile(name: 'X', phone: null),
          throwsStateError,
        );
      });
    });

    group('changeOwnPassword', () {
      test('returns null on success', () async {
        when(
          () => mockFirebaseService.changePassword(
            currentPassword: 'old-pass',
            newPassword: 'new-pass',
          ),
        ).thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        final error = await authRepo.changeOwnPassword(
          currentPassword: 'old-pass',
          newPassword: 'new-pass',
        );

        expect(error, isNull);
        verify(
          () => mockFirebaseService.changePassword(
            currentPassword: 'old-pass',
            newPassword: 'new-pass',
          ),
        ).called(1);
      });

      test('maps a wrong current password to Arabic copy', () async {
        when(
          () => mockFirebaseService.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'wrong-password'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final error = await authRepo.changeOwnPassword(
          currentPassword: 'bad',
          newPassword: 'new-pass',
        );

        expect(error, 'كلمة المرور الحالية غير صحيحة');
      });

      test('maps invalid-credential to the same wrong-password copy', () async {
        when(
          () => mockFirebaseService.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'invalid-credential'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final error = await authRepo.changeOwnPassword(
          currentPassword: 'bad',
          newPassword: 'new-pass',
        );

        expect(error, 'كلمة المرور الحالية غير صحيحة');
      });

      test('maps weak-password to Arabic copy', () async {
        when(
          () => mockFirebaseService.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(FakeFirebaseAuthException(code: 'weak-password'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final error = await authRepo.changeOwnPassword(
          currentPassword: 'old-pass',
          newPassword: '123',
        );

        expect(error, 'كلمة المرور الجديدة ضعيفة، اختر كلمة أقوى');
      });

      test('returns a generic Arabic message on unexpected failure', () async {
        when(
          () => mockFirebaseService.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenThrow(Exception('network down'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final error = await authRepo.changeOwnPassword(
          currentPassword: 'old-pass',
          newPassword: 'new-pass',
        );

        expect(error, 'تعذر تغيير كلمة المرور، حاول مرة أخرى');
      });
    });

    group('signOut', () {
      test('signs out and clears the cached session', () async {
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signOut();

        verify(() => mockFirebaseService.signOut()).called(1);
        verify(() => mockSessionCache.clear()).called(1);

        final state = container.read(authRepositoryProvider);
        expect(state.firebaseUser, isNull);
        expect(state.appUser, isNull);
      });
    });

    group('_refreshAppUser (background reconcile)', () {
      test(
        'reports a swallowed refresh failure and keeps the cached optimistic '
        'profile intact instead of throwing',
        () async {
          final cachedUser = buildUser(id: 'uid-1', name: 'اسم سري للمستخدم');
          final mockUser = MockUser();
          when(() => mockUser.uid).thenReturn('uid-1');
          final authController = StreamController<User?>();
          addTearDown(authController.close);

          when(
            () => mockFirebaseService.authStateChanges,
          ).thenAnswer((_) => authController.stream);
          when(() => mockSessionCache.readUser()).thenReturn(cachedUser);
          when(
            () => mockUserRepository.getUserById('uid-1'),
          ).thenThrow(Exception('offline: getUserById unreachable'));

          final reporter = _RecordingReporter();
          final scopedContainer = ProviderContainer(
            overrides: [
              firebaseServiceProvider.overrideWithValue(mockFirebaseService),
              userRepositoryProvider.overrideWithValue(mockUserRepository),
              sessionCacheProvider.overrideWithValue(mockSessionCache),
              errorReporterProvider.overrideWithValue(reporter),
            ],
          );
          addTearDown(scopedContainer.dispose);

          // Seeds AuthState from the cached optimistic profile and starts
          // the authStateChanges listener that drives _refreshAppUser.
          scopedContainer.read(authRepositoryProvider);
          authController.add(mockUser);
          await pumpEventQueue();

          expect(reporter.recorded, hasLength(1));
          expect(reporter.recorded.single.reason, isNotNull);
          // The reason must be a fixed, hand-written string — never the
          // exception text and never anything derived from the user model.
          expect(
            reporter.recorded.single.reason,
            isNot(contains('اسم سري للمستخدم')),
          );
          expect(
            reporter.recorded.single.reason,
            isNot(contains('offline: getUserById unreachable')),
          );

          // The catch's existing fallback behaviour is unchanged: the
          // reconcile failure is swallowed and the cached optimistic user
          // stays in state rather than the method throwing or clearing it.
          final state = scopedContainer.read(authRepositoryProvider);
          expect(state.appUser?.id, 'uid-1');
        },
      );

      test('a repository built without overriding errorReporterProvider still '
          'reconciles safely (proves the default no-op fallback)', () async {
        final cachedUser = buildUser(id: 'uid-2');
        final mockUser = MockUser();
        when(() => mockUser.uid).thenReturn('uid-2');
        final authController = StreamController<User?>();
        addTearDown(authController.close);

        when(
          () => mockFirebaseService.authStateChanges,
        ).thenAnswer((_) => authController.stream);
        when(() => mockSessionCache.readUser()).thenReturn(cachedUser);
        when(
          () => mockUserRepository.getUserById('uid-2'),
        ).thenThrow(Exception('offline'));

        final scopedContainer = ProviderContainer(
          overrides: [
            firebaseServiceProvider.overrideWithValue(mockFirebaseService),
            userRepositoryProvider.overrideWithValue(mockUserRepository),
            sessionCacheProvider.overrideWithValue(mockSessionCache),
            // errorReporterProvider is deliberately left un-overridden —
            // it must default to NoopErrorReporter and never throw.
          ],
        );
        addTearDown(scopedContainer.dispose);

        scopedContainer.read(authRepositoryProvider);
        authController.add(mockUser);
        await pumpEventQueue();

        final state = scopedContainer.read(authRepositoryProvider);
        expect(state.appUser?.id, 'uid-2');
      });
    });
  });
}
