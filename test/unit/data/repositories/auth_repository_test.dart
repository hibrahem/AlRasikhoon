import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/google_auth_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';

// Mocks
class MockFirebaseService extends Mock implements FirebaseService {}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

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
  late MockGoogleAuthService mockGoogleAuthService;
  late MockUserRepository mockUserRepository;
  late MockLocalStorageService mockLocalStorageService;
  late ProviderContainer container;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockGoogleAuthService = MockGoogleAuthService();
    mockUserRepository = MockUserRepository();
    mockLocalStorageService = MockLocalStorageService();

    // Setup default auth state changes stream (empty stream for tests)
    when(() => mockFirebaseService.authStateChanges)
        .thenAnswer((_) => Stream.empty());

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        googleAuthServiceProvider.overrideWithValue(mockGoogleAuthService),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('AuthRepository', () {
    group('setupPendingUserAndSendReset', () {
      test('returns pending_user_setup when user exists with pending status',
          () async {
        // Arrange
        const email = 'newuser@example.com';
        final pendingUser = UserModel(
          id: 'temp-id',
          email: email,
          name: 'New User',
          role: UserRole.teacher,
          authProvider: UserAuthProvider.pending,
          createdAt: DateTime.now(),
        );
        final mockUserCredential = MockUserCredential();

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => pendingUser);
        when(() => mockFirebaseService.createUserWithEmailPassword(
              email: email,
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'pending_user_setup');
        verify(() => mockFirebaseService.createUserWithEmailPassword(
              email: email,
              password: any(named: 'password'),
            )).called(1);
        verify(() => mockFirebaseService.sendPasswordResetEmail(email))
            .called(1);
        verify(() => mockFirebaseService.signOut()).called(1);
      });

      test('returns normal_reset when user exists with active auth provider',
          () async {
        // Arrange
        const email = 'existing@example.com';
        final existingUser = UserModel(
          id: 'user-id',
          email: email,
          name: 'Existing User',
          role: UserRole.teacher,
          authProvider: UserAuthProvider.emailPassword,
          createdAt: DateTime.now(),
        );

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => existingUser);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'normal_reset');
        verify(() => mockFirebaseService.sendPasswordResetEmail(email))
            .called(1);
        verifyNever(() => mockFirebaseService.createUserWithEmailPassword(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ));
      });

      test(
          'returns normal_reset when user not in Firestore but has Auth account',
          () async {
        // Arrange
        const email = 'authonly@example.com';

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => null);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'normal_reset');
        verify(() => mockFirebaseService.sendPasswordResetEmail(email))
            .called(1);
      });

      test('returns not_found when user does not exist anywhere', () async {
        // Arrange
        const email = 'nonexistent@example.com';

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => null);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenThrow(FakeFirebaseAuthException(code: 'user-not-found'));

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'not_found');
        final state = container.read(authRepositoryProvider);
        expect(state.error, 'لا يوجد حساب بهذا البريد الإلكتروني');
      });

      test(
          'returns normal_reset when email-already-in-use during pending user setup',
          () async {
        // Arrange
        const email = 'pending@example.com';
        final pendingUser = UserModel(
          id: 'temp-id',
          email: email,
          name: 'Pending User',
          role: UserRole.student,
          authProvider: UserAuthProvider.pending,
          createdAt: DateTime.now(),
        );

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => pendingUser);
        when(() => mockFirebaseService.createUserWithEmailPassword(
              email: email,
              password: any(named: 'password'),
            )).thenThrow(FakeFirebaseAuthException(code: 'email-already-in-use'));
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'normal_reset');
        verify(() => mockFirebaseService.sendPasswordResetEmail(email))
            .called(1);
      });

      test('sets loading state during operation', () async {
        // Arrange
        const email = 'test@example.com';
        final completer = Completer<UserModel?>();

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) => completer.future);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final future = authRepo.setupPendingUserAndSendReset(email);

        // Assert - should be loading
        await Future.delayed(Duration.zero);
        expect(container.read(authRepositoryProvider).isLoading, true);

        // Complete the operation
        completer.complete(null);
        await future;

        // Assert - should not be loading anymore
        expect(container.read(authRepositoryProvider).isLoading, false);
      });

      test('sets passwordResetSent to true on successful pending user setup',
          () async {
        // Arrange
        const email = 'pending@example.com';
        final pendingUser = UserModel(
          id: 'temp-id',
          email: email,
          name: 'Pending User',
          role: UserRole.teacher,
          authProvider: UserAuthProvider.pending,
          createdAt: DateTime.now(),
        );
        final mockUserCredential = MockUserCredential();

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => pendingUser);
        when(() => mockFirebaseService.createUserWithEmailPassword(
              email: email,
              password: any(named: 'password'),
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        final state = container.read(authRepositoryProvider);
        expect(state.passwordResetSent, true);
        expect(state.error, isNull);
      });

      test('returns error when an unexpected exception occurs', () async {
        // Arrange
        const email = 'error@example.com';

        when(() => mockUserRepository.getUserByEmail(email))
            .thenThrow(Exception('Unexpected error'));

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.setupPendingUserAndSendReset(email);

        // Assert
        expect(result, 'error');
        final state = container.read(authRepositoryProvider);
        expect(state.error, contains('Unexpected error'));
      });
    });

    group('signInWithEmailPassword', () {
      test('returns user when sign in succeeds and user exists in Firestore',
          () async {
        // Arrange
        const email = 'user@example.com';
        const password = 'password123';
        const uid = 'firebase-uid';

        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = UserModel(
          id: uid,
          email: email,
          name: 'Test User',
          role: UserRole.teacher,
          authProvider: UserAuthProvider.emailPassword,
          createdAt: DateTime.now(),
        );

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.signInWithEmailPassword(
              email: email,
              password: password,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => appUser);
        when(() => mockLocalStorageService.setUserId(uid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNotNull);
        expect(result?.id, uid);
        expect(result?.email, email);
      });

      test('returns null with error when credentials are invalid', () async {
        // Arrange
        const email = 'user@example.com';
        const password = 'wrongpassword';

        when(() => mockFirebaseService.signInWithEmailPassword(
              email: email,
              password: password,
            )).thenThrow(FakeFirebaseAuthException(code: 'invalid-credential'));

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNull);
        final state = container.read(authRepositoryProvider);
        expect(state.error, 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
      });

      test('returns account_not_found error when user not in Firestore',
          () async {
        // Arrange
        const email = 'unknown@example.com';
        const password = 'password123';
        const uid = 'firebase-uid';

        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.signInWithEmailPassword(
              email: email,
              password: password,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => null);
        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => null);

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNull);
        final state = container.read(authRepositoryProvider);
        expect(state.error, 'account_not_found');
      });

      test('migrates user when found by email but not by UID', () async {
        // Arrange
        const email = 'migrate@example.com';
        const password = 'password123';
        const oldId = 'old-id';
        const newUid = 'new-firebase-uid';

        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final oldUser = UserModel(
          id: oldId,
          email: email,
          name: 'Migrating User',
          role: UserRole.teacher,
          authProvider: UserAuthProvider.pending,
          createdAt: DateTime.now(),
        );
        final migratedUser = oldUser.copyWith(
          id: newUid,
          authProvider: UserAuthProvider.emailPassword,
        );

        when(() => mockUser.uid).thenReturn(newUid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.signInWithEmailPassword(
              email: email,
              password: password,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(newUid))
            .thenAnswer((_) async => null);
        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => oldUser);
        when(() => mockUserRepository.migrateUserToFirebaseUid(
              oldId: oldId,
              newFirebaseUid: newUid,
              authProvider: UserAuthProvider.emailPassword,
            )).thenAnswer((_) async => migratedUser);
        when(() => mockLocalStorageService.setUserId(newUid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(migratedUser.role.value))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailPassword(
          email: email,
          password: password,
        );

        // Assert
        expect(result, isNotNull);
        expect(result?.id, newUid);
        verify(() => mockUserRepository.migrateUserToFirebaseUid(
              oldId: oldId,
              newFirebaseUid: newUid,
              authProvider: UserAuthProvider.emailPassword,
            )).called(1);
      });
    });

    group('sendPasswordResetEmail', () {
      test('sets passwordResetSent to true on success', () async {
        // Arrange
        const email = 'user@example.com';

        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendPasswordResetEmail(email);

        // Assert
        final state = container.read(authRepositoryProvider);
        expect(state.passwordResetSent, true);
        expect(state.isLoading, false);
        expect(state.error, isNull);
      });

      test('sets error when email not found', () async {
        // Arrange
        const email = 'nonexistent@example.com';

        when(() => mockFirebaseService.sendPasswordResetEmail(email))
            .thenThrow(FakeFirebaseAuthException(code: 'user-not-found'));

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendPasswordResetEmail(email);

        // Assert
        final state = container.read(authRepositoryProvider);
        expect(state.passwordResetSent, false);
        expect(state.error, 'لا يوجد حساب بهذا البريد الإلكتروني');
      });
    });

    group('signOut', () {
      test('signs out from all services and clears local storage', () async {
        // Arrange
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});
        when(() => mockGoogleAuthService.signOut()).thenAnswer((_) async {});
        when(() => mockLocalStorageService.clearUserData())
            .thenAnswer((_) async {});

        // Act
        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signOut();

        // Assert
        verify(() => mockFirebaseService.signOut()).called(1);
        verify(() => mockGoogleAuthService.signOut()).called(1);
        verify(() => mockLocalStorageService.clearUserData()).called(1);

        final state = container.read(authRepositoryProvider);
        expect(state.firebaseUser, isNull);
        expect(state.appUser, isNull);
      });
    });
  });
}
