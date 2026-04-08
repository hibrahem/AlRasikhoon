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
import 'package:al_rasikhoon/data/services/deep_link_service.dart';

// Mocks
class MockFirebaseService extends Mock implements FirebaseService {}

class MockGoogleAuthService extends Mock implements GoogleAuthService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockDeepLinkService extends Mock implements DeepLinkService {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeFirebaseAuthException extends Fake implements FirebaseAuthException {
  @override
  final String code;

  @override
  final String? message;

  FakeFirebaseAuthException({required this.code, this.message});
}

class FakeActionCodeSettings extends Fake implements ActionCodeSettings {}

void main() {
  late MockFirebaseService mockFirebaseService;
  late MockGoogleAuthService mockGoogleAuthService;
  late MockUserRepository mockUserRepository;
  late MockLocalStorageService mockLocalStorageService;
  late MockDeepLinkService mockDeepLinkService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(FakeActionCodeSettings());
  });

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockGoogleAuthService = MockGoogleAuthService();
    mockUserRepository = MockUserRepository();
    mockLocalStorageService = MockLocalStorageService();
    mockDeepLinkService = MockDeepLinkService();

    // Setup default streams
    when(() => mockFirebaseService.authStateChanges)
        .thenAnswer((_) => Stream.empty());
    when(() => mockDeepLinkService.linkStream)
        .thenAnswer((_) => Stream.empty());

    container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(mockFirebaseService),
        googleAuthServiceProvider.overrideWithValue(mockGoogleAuthService),
        userRepositoryProvider.overrideWithValue(mockUserRepository),
        localStorageServiceProvider.overrideWithValue(mockLocalStorageService),
        deepLinkServiceProvider.overrideWithValue(mockDeepLinkService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  UserModel _createUser({
    String id = 'user-id',
    String email = 'test@example.com',
    String name = 'Test User',
    UserRole role = UserRole.teacher,
    UserAuthProvider authProvider = UserAuthProvider.pending,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name,
      role: role,
      authProvider: authProvider,
      createdAt: DateTime.now(),
    );
  }

  group('AuthRepository', () {
    group('sendSignInLink', () {
      test('sends link when user exists in Firestore', () async {
        const email = 'teacher@example.com';
        final user = _createUser(email: email);

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => user);
        when(() => mockFirebaseService.sendSignInLinkToEmail(
              email: email,
              actionCodeSettings: any(named: 'actionCodeSettings'),
            )).thenAnswer((_) async {});
        when(() => mockLocalStorageService.setPendingSignInEmail(email))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendSignInLink(email);

        final state = container.read(authRepositoryProvider);
        expect(state.emailLinkSent, true);
        expect(state.error, isNull);
        expect(state.isLoading, false);

        verify(() => mockFirebaseService.sendSignInLinkToEmail(
              email: email,
              actionCodeSettings: any(named: 'actionCodeSettings'),
            )).called(1);
        verify(() => mockLocalStorageService.setPendingSignInEmail(email))
            .called(1);
      });

      test('sets error when user not found in Firestore', () async {
        const email = 'nonexistent@example.com';

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => null);

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendSignInLink(email);

        final state = container.read(authRepositoryProvider);
        expect(state.emailLinkSent, false);
        expect(state.error, 'لا يوجد حساب بهذا البريد الإلكتروني');

        verifyNever(() => mockFirebaseService.sendSignInLinkToEmail(
              email: any(named: 'email'),
              actionCodeSettings: any(named: 'actionCodeSettings'),
            ));
      });

      test('sets error on Firebase exception', () async {
        const email = 'test@example.com';
        final user = _createUser(email: email);

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => user);
        when(() => mockFirebaseService.sendSignInLinkToEmail(
              email: email,
              actionCodeSettings: any(named: 'actionCodeSettings'),
            )).thenThrow(FakeFirebaseAuthException(code: 'too-many-requests'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendSignInLink(email);

        final state = container.read(authRepositoryProvider);
        expect(state.emailLinkSent, false);
        expect(state.error, 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً');
      });

      test('sets loading state during operation', () async {
        const email = 'test@example.com';
        final completer = Completer<UserModel?>();

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) => completer.future);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final future = authRepo.sendSignInLink(email);

        await Future.delayed(Duration.zero);
        expect(container.read(authRepositoryProvider).isLoading, true);

        completer.complete(null);
        await future;

        expect(container.read(authRepositoryProvider).isLoading, false);
      });

      test('stores email in localStorage', () async {
        const email = 'store@example.com';
        final user = _createUser(email: email);

        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => user);
        when(() => mockFirebaseService.sendSignInLinkToEmail(
              email: email,
              actionCodeSettings: any(named: 'actionCodeSettings'),
            )).thenAnswer((_) async {});
        when(() => mockLocalStorageService.setPendingSignInEmail(email))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.sendSignInLink(email);

        verify(() => mockLocalStorageService.setPendingSignInEmail(email))
            .called(1);
      });
    });

    group('signInWithEmailLink', () {
      const validLink = 'https://alrasikhoon-57151.firebaseapp.com/__/auth/action?oobCode=abc123';

      test('signs in when stored email exists and user found by UID', () async {
        const email = 'teacher@example.com';
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = _createUser(
          id: uid,
          email: email,
          authProvider: UserAuthProvider.emailLink,
        );

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => appUser);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserId(uid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNotNull);
        expect(result?.id, uid);

        verify(() => mockLocalStorageService.clearPendingSignInEmail())
            .called(1);
      });

      test('migrates user when found by email but not by UID', () async {
        const email = 'migrate@example.com';
        const oldId = 'old-uuid';
        const newUid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final oldUser = _createUser(id: oldId, email: email);
        final migratedUser = oldUser.copyWith(
          id: newUid,
          authProvider: UserAuthProvider.emailLink,
        );

        when(() => mockUser.uid).thenReturn(newUid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(newUid))
            .thenAnswer((_) async => null);
        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => oldUser);
        when(() => mockUserRepository.migrateUserToFirebaseUid(
              oldId: oldId,
              newFirebaseUid: newUid,
              authProvider: UserAuthProvider.emailLink,
            )).thenAnswer((_) async => migratedUser);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserId(newUid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(migratedUser.role.value))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNotNull);
        expect(result?.id, newUid);

        verify(() => mockUserRepository.migrateUserToFirebaseUid(
              oldId: oldId,
              newFirebaseUid: newUid,
              authProvider: UserAuthProvider.emailLink,
            )).called(1);
      });

      test('sets email_prompt_needed when no stored email (cross-device)',
          () async {
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(null);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'email_prompt_needed');
        expect(state.isLoading, false);
      });

      test('returns null with error for invalid link', () async {
        const invalidLink = 'https://example.com/not-a-signin-link';

        when(() => mockFirebaseService.isSignInWithEmailLink(invalidLink))
            .thenReturn(false);

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(invalidLink);

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'الرابط غير صالح');
      });

      test('handles expired link error', () async {
        const email = 'test@example.com';

        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenThrow(FakeFirebaseAuthException(code: 'expired-action-code'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'انتهت صلاحية الرابط. يرجى طلب رابط جديد');
      });

      test('handles invalid action code error', () async {
        const email = 'test@example.com';

        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenThrow(FakeFirebaseAuthException(code: 'invalid-action-code'));

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'الرابط غير صالح. يرجى طلب رابط جديد');
      });

      test('returns account_not_found when user not in Firestore', () async {
        const email = 'unknown@example.com';
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => null);
        when(() => mockUserRepository.getUserByEmail(email))
            .thenAnswer((_) async => null);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithEmailLink(validLink);

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'account_not_found');
      });

      test('clears pending email on success', () async {
        const email = 'test@example.com';
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = _createUser(id: uid, email: email);

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => appUser);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserId(uid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithEmailLink(validLink);

        verify(() => mockLocalStorageService.clearPendingSignInEmail())
            .called(1);
      });

      test('sets user data in localStorage on success', () async {
        const email = 'test@example.com';
        const uid = 'firebase-uid';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = _createUser(id: uid, email: email);

        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(email);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => appUser);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserId(uid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithEmailLink(validLink);

        verify(() => mockLocalStorageService.setUserId(uid)).called(1);
        verify(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .called(1);
      });
    });

    group('signInWithPendingLink', () {
      test('completes sign-in with provided email', () async {
        const email = 'crossdevice@example.com';
        const uid = 'firebase-uid';
        const validLink = 'https://alrasikhoon-57151.firebaseapp.com/__/auth/action?oobCode=abc123';
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final appUser = _createUser(id: uid, email: email);

        // First, trigger the email_prompt_needed state
        when(() => mockFirebaseService.isSignInWithEmailLink(validLink))
            .thenReturn(true);
        when(() => mockLocalStorageService.getPendingSignInEmail())
            .thenReturn(null);

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signInWithEmailLink(validLink);
        expect(container.read(authRepositoryProvider).error,
            'email_prompt_needed');

        // Now complete with the email
        when(() => mockUser.uid).thenReturn(uid);
        when(() => mockUser.email).thenReturn(email);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockFirebaseService.signInWithEmailLink(
              email: email,
              emailLink: validLink,
            )).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserRepository.getUserById(uid))
            .thenAnswer((_) async => appUser);
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserId(uid))
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.setUserRole(appUser.role.value))
            .thenAnswer((_) async {});

        final result = await authRepo.signInWithPendingLink(email);

        expect(result, isNotNull);
        expect(result?.id, uid);
      });

      test('returns error when no pending link', () async {
        final authRepo = container.read(authRepositoryProvider.notifier);
        final result = await authRepo.signInWithPendingLink('test@example.com');

        expect(result, isNull);

        final state = container.read(authRepositoryProvider);
        expect(state.error, 'لا يوجد رابط معلق');
      });
    });

    group('signOut', () {
      test('signs out from all services and clears local storage', () async {
        when(() => mockFirebaseService.signOut()).thenAnswer((_) async {});
        when(() => mockGoogleAuthService.signOut()).thenAnswer((_) async {});
        when(() => mockLocalStorageService.clearPendingSignInEmail())
            .thenAnswer((_) async {});
        when(() => mockLocalStorageService.clearUserData())
            .thenAnswer((_) async {});

        final authRepo = container.read(authRepositoryProvider.notifier);
        await authRepo.signOut();

        verify(() => mockFirebaseService.signOut()).called(1);
        verify(() => mockGoogleAuthService.signOut()).called(1);
        verify(() => mockLocalStorageService.clearPendingSignInEmail())
            .called(1);
        verify(() => mockLocalStorageService.clearUserData()).called(1);

        final state = container.read(authRepositoryProvider);
        expect(state.firebaseUser, isNull);
        expect(state.appUser, isNull);
      });
    });
  });
}
