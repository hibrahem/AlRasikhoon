import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/google_auth_service.dart';
import '../services/local_storage_service.dart';
import 'user_repository.dart';
import '../models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final User? firebaseUser;
  final UserModel? appUser;
  final bool passwordResetSent;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.firebaseUser,
    this.appUser,
    this.passwordResetSent = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    User? firebaseUser,
    UserModel? appUser,
    bool? passwordResetSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      appUser: appUser ?? this.appUser,
      passwordResetSent: passwordResetSent ?? this.passwordResetSent,
    );
  }
}

class AuthRepository extends Notifier<AuthState> {
  late final FirebaseService _firebaseService;
  late final GoogleAuthService _googleAuthService;
  late final UserRepository _userRepository;
  late final LocalStorageService _localStorage;

  // Flag to skip auth state listener during first-time user setup
  bool _isFirstTimeUserSetupInProgress = false;

  @override
  AuthState build() {
    _firebaseService = ref.watch(firebaseServiceProvider);
    _googleAuthService = ref.watch(googleAuthServiceProvider);
    _userRepository = ref.watch(userRepositoryProvider);
    _localStorage = ref.watch(localStorageServiceProvider);
    _init();
    return const AuthState();
  }

  void _init() {
    _firebaseService.authStateChanges.listen((user) async {
      // Skip processing during first-time user setup in forgot password flow
      if (_isFirstTimeUserSetupInProgress) return;

      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        await _loadAppUser(user.uid, user.email);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadAppUser(String uid, String? email) async {
    try {
      // First try to find user by Firebase UID
      var appUser = await _userRepository.getUserById(uid);

      // If not found by UID and we have email, try to find by email
      if (appUser == null && email != null) {
        appUser = await _userRepository.getUserByEmail(email);

        // If found by email, migrate to use Firebase UID as document ID
        if (appUser != null) {
          appUser = await _userRepository.migrateUserToFirebaseUid(
            oldId: appUser.id,
            newFirebaseUid: uid,
          );
        }
      }

      if (appUser != null) {
        state = state.copyWith(appUser: appUser);
        await _localStorage.setUserId(appUser.id);
        await _localStorage.setUserRole(appUser.role.value);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // For web: use Firebase Auth's signInWithPopup (more reliable)
        userCredential = await _firebaseService.signInWithGooglePopup();
      } else {
        // For mobile: use google_sign_in package
        final googleAccount = await _googleAuthService.signIn();
        if (googleAccount == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'تم إلغاء تسجيل الدخول',
          );
          return null;
        }

        final authentication = await _googleAuthService.getAuthentication(googleAccount);
        if (authentication == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'فشل الحصول على بيانات المصادقة',
          );
          return null;
        }

        userCredential = await _firebaseService.signInWithGoogleCredential(
          idToken: authentication.idToken!,
          accessToken: authentication.accessToken!,
        );
      }

      final user = userCredential.user;
      if (user != null) {
        state = state.copyWith(firebaseUser: user);

        // Try to find existing user by UID or email
        var appUser = await _userRepository.getUserById(user.uid);
        if (appUser == null && user.email != null) {
          appUser = await _userRepository.getUserByEmail(user.email!);
          if (appUser != null) {
            // Migrate existing user to Firebase UID and update auth provider
            appUser = await _userRepository.migrateUserToFirebaseUid(
              oldId: appUser.id,
              newFirebaseUid: user.uid,
              authProvider: UserAuthProvider.google,
            );
          }
        }

        if (appUser != null) {
          state = state.copyWith(
            isLoading: false,
            appUser: appUser,
          );
          await _localStorage.setUserId(appUser.id);
          await _localStorage.setUserRole(appUser.role.value);
          return appUser;
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'account_not_found',
          );
          return null;
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: 'فشل تسجيل الدخول',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'فشل تسجيل الدخول بـ Google: $e',
      );
      return null;
    }
  }

  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final userCredential = await _firebaseService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        state = state.copyWith(firebaseUser: user);

        // Try to find existing user by UID or email
        var appUser = await _userRepository.getUserById(user.uid);
        if (appUser == null) {
          appUser = await _userRepository.getUserByEmail(email);
          if (appUser != null) {
            // Migrate existing user to Firebase UID and update auth provider
            appUser = await _userRepository.migrateUserToFirebaseUid(
              oldId: appUser.id,
              newFirebaseUid: user.uid,
              authProvider: UserAuthProvider.emailPassword,
            );
          }
        }

        if (appUser != null) {
          state = state.copyWith(
            isLoading: false,
            appUser: appUser,
          );
          await _localStorage.setUserId(appUser.id);
          await _localStorage.setUserRole(appUser.role.value);
          return appUser;
        } else {
          state = state.copyWith(
            isLoading: false,
            error: 'account_not_found',
          );
          return null;
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: 'فشل تسجيل الدخول',
      );
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Setup a pending user (created by admin/teacher) for first-time login
  /// Creates Firebase Auth account and sends password reset email
  /// Returns: 'pending_user_setup' if successful, 'normal_reset' for existing users,
  /// 'not_found' if no user exists with this email
  Future<String> setupPendingUserAndSendReset(String email) async {
    state = state.copyWith(isLoading: true, error: null, passwordResetSent: false);

    try {
      // Check if user exists in Firestore (this query is allowed for unauthenticated users)
      final firestoreUser = await _userRepository.getUserByEmail(email);

      if (firestoreUser == null) {
        // No user in Firestore - check if they have a Firebase Auth account
        // If they do, just send password reset. If not, return not_found
        try {
          await _firebaseService.sendPasswordResetEmail(email);
          state = state.copyWith(isLoading: false, passwordResetSent: true);
          return 'normal_reset';
        } on FirebaseAuthException catch (e) {
          if (e.code == 'user-not-found') {
            state = state.copyWith(
              isLoading: false,
              error: 'لا يوجد حساب بهذا البريد الإلكتروني',
            );
            return 'not_found';
          }
          rethrow;
        }
      }

      // User exists in Firestore
      if (firestoreUser.authProvider == UserAuthProvider.pending) {
        // First-time user - create Firebase Auth account and send reset email
        _isFirstTimeUserSetupInProgress = true;

        try {
          final tempPassword = _generateTempPassword();
          await _firebaseService.createUserWithEmailPassword(
            email: email,
            password: tempPassword,
          );

          // Send password reset email so user can set their own password
          await _firebaseService.sendPasswordResetEmail(email);

          // Sign out immediately - we don't want to stay logged in
          await _firebaseService.signOut();

          state = state.copyWith(isLoading: false, passwordResetSent: true);
          return 'pending_user_setup';
        } finally {
          _isFirstTimeUserSetupInProgress = false;
        }
      } else {
        // Existing user with active account - send normal password reset
        await _firebaseService.sendPasswordResetEmail(email);
        state = state.copyWith(isLoading: false, passwordResetSent: true);
        return 'normal_reset';
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Auth account already exists for pending user - just send reset email
        try {
          await _firebaseService.sendPasswordResetEmail(email);
          state = state.copyWith(isLoading: false, passwordResetSent: true);
          return 'normal_reset';
        } catch (_) {
          // Ignore and show the original error
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return 'error';
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return 'error';
    }
  }

  String _generateTempPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null, passwordResetSent: false);

    try {
      await _firebaseService.sendPasswordResetEmail(email);
      state = state.copyWith(
        isLoading: false,
        passwordResetSent: true,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    await _googleAuthService.signOut();
    await _localStorage.clearUserData();
    state = const AuthState();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'البريد الإلكتروني غير صحيح';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب';
        case 'user-not-found':
          return 'لا يوجد حساب بهذا البريد الإلكتروني';
        case 'wrong-password':
          return 'كلمة المرور غير صحيحة';
        case 'invalid-credential':
          return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً';
        case 'email-already-in-use':
          return 'البريد الإلكتروني مستخدم مسبقاً';
        case 'weak-password':
          return 'كلمة المرور ضعيفة';
        default:
          return error.message ?? 'حدث خطأ غير متوقع';
      }
    }
    return error.toString();
  }

  bool get isAuthenticated => state.firebaseUser != null && state.appUser != null;
  bool get isAccountNotFound => state.error == 'account_not_found';
  UserModel? get currentUser => state.appUser;
  UserRole? get currentUserRole => state.appUser?.role;
}

final authRepositoryProvider = NotifierProvider<AuthRepository, AuthState>(
  AuthRepository.new,
);
