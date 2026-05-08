import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeFirebaseAuthException extends Fake implements FirebaseAuthException {
  @override
  final String code;

  @override
  final String? message;

  FakeFirebaseAuthException({required this.code, this.message});
}

void main() {
  late MockFirebaseService mockFirebaseService;
  late MockUserRepository mockUserRepository;
  late MockLocalStorageService mockLocalStorageService;
  late ProviderContainer container;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockUserRepository = MockUserRepository();
    mockLocalStorageService = MockLocalStorageService();

    when(
      () => mockFirebaseService.authStateChanges,
    ).thenAnswer((_) => Stream.empty());

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
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
        when(
          () => mockLocalStorageService.setUserId(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorageService.setUserRole(any()),
        ).thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithUsernameAndPassword(
          username: username,
          password: password,
        );

        expect(result, isNotNull);
        expect(result?.id, uid);
        expect(result?.username, username);
        verify(() => mockLocalStorageService.setUserId(uid)).called(1);
        verify(
          () => mockLocalStorageService.setUserRole(UserRole.teacher.value),
        ).called(1);
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
        when(
          () => mockLocalStorageService.setUserId(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorageService.setUserRole(any()),
        ).thenAnswer((_) async {});

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
        when(
          () => mockLocalStorageService.setUserId(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorageService.setUserRole(any()),
        ).thenAnswer((_) async {});

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

    group('setPasswordForUser', () {
      test('throws UnimplementedError pending phase 7', () async {
        final authRepo = container.read(authRepositoryProvider.notifier);

        expect(
          () => authRepo.setPasswordForUser(
            userId: 'uid',
            newPassword: 'pass123',
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });
    });

    group('signOut', () {
      test('signs out and clears local storage', () async {
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});
        when(
          () => mockLocalStorageService.clearUserData(),
        ).thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signOut();

        verify(() => mockFirebaseService.signOut()).called(1);
        verify(() => mockLocalStorageService.clearUserData()).called(1);

        final state = container.read(authRepositoryProvider);
        expect(state.firebaseUser, isNull);
        expect(state.appUser, isNull);
      });
    });
  });
}
