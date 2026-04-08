import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/google_auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/deep_link_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'user_repository.dart';
import '../models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final User? firebaseUser;
  final UserModel? appUser;
  final bool emailLinkSent;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.firebaseUser,
    this.appUser,
    this.emailLinkSent = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    User? firebaseUser,
    UserModel? appUser,
    bool? emailLinkSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      appUser: appUser ?? this.appUser,
      emailLinkSent: emailLinkSent ?? this.emailLinkSent,
    );
  }
}

class AuthRepository extends Notifier<AuthState> {
  late final FirebaseService _firebaseService;
  late final GoogleAuthService _googleAuthService;
  late final UserRepository _userRepository;
  late final LocalStorageService _localStorage;

  // Stores the email link when user needs to provide email (cross-device)
  String? _pendingEmailLink;

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
      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        await _loadAppUser(user.uid, user.email);
      } else {
        state = const AuthState();
      }
    });

    _initDeepLinkListener();
  }

  void _initDeepLinkListener() {
    // On web, check Uri.base directly — more reliable than DeepLinkService
    // because all dependencies are guaranteed to be ready at this point
    if (kIsWeb) {
      final link = Uri.base.toString();
      if (_firebaseService.isSignInWithEmailLink(link)) {
        signInWithEmailLink(link);
        return;
      }
    }

    // For mobile, use DeepLinkService
    final deepLinkService = ref.read(deepLinkServiceProvider);
    final initialLink = deepLinkService.consumeInitialLink();
    if (initialLink != null) {
      final link = initialLink.toString();
      if (_firebaseService.isSignInWithEmailLink(link)) {
        signInWithEmailLink(link);
      }
    }
    deepLinkService.linkStream.listen((uri) {
      final link = uri.toString();
      if (_firebaseService.isSignInWithEmailLink(link)) {
        signInWithEmailLink(link);
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

  /// Send a sign-in link to the user's email.
  /// Returns after the link is sent successfully.
  /// Checks Firestore first to ensure the email belongs to a registered user.
  Future<void> sendSignInLink(String email) async {
    state = state.copyWith(isLoading: true, error: null, emailLinkSent: false);

    try {
      // Check if user exists in Firestore first
      final firestoreUser = await _userRepository.getUserByEmail(email);
      if (firestoreUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'لا يوجد حساب بهذا البريد الإلكتروني',
        );
        return;
      }

      await _firebaseService.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: _getActionCodeSettings(),
      );

      await _localStorage.setPendingSignInEmail(email);
      state = state.copyWith(isLoading: false, emailLinkSent: true);
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

  /// Sign in using an email link received via deep link.
  /// If no email is available (cross-device scenario), sets error to
  /// 'email_prompt_needed' and stores the link for later use.
  Future<UserModel?> signInWithEmailLink(String link, {String? email}) async {
    if (!_firebaseService.isSignInWithEmailLink(link)) {
      state = state.copyWith(error: 'الرابط غير صالح');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    // Use provided email or retrieve from storage
    final signInEmail = email ?? _localStorage.getPendingSignInEmail();
    if (signInEmail == null) {
      // Cross-device: user clicked link on a different device
      _pendingEmailLink = link;
      state = state.copyWith(
        isLoading: false,
        error: 'email_prompt_needed',
      );
      return null;
    }

    try {
      final userCredential = await _firebaseService.signInWithEmailLink(
        email: signInEmail,
        emailLink: link,
      );

      final user = userCredential.user;
      if (user != null) {
        state = state.copyWith(firebaseUser: user);

        // Firestore lookup + migration (same as Google sign-in)
        var appUser = await _userRepository.getUserById(user.uid);
        if (appUser == null && user.email != null) {
          appUser = await _userRepository.getUserByEmail(user.email!);
          if (appUser != null) {
            appUser = await _userRepository.migrateUserToFirebaseUid(
              oldId: appUser.id,
              newFirebaseUid: user.uid,
              authProvider: UserAuthProvider.emailLink,
            );
          }
        }

        await _localStorage.clearPendingSignInEmail();
        _pendingEmailLink = null;

        if (appUser != null) {
          state = state.copyWith(isLoading: false, appUser: appUser);
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

      state = state.copyWith(isLoading: false, error: 'فشل تسجيل الدخول');
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

  /// Complete sign-in when user provides email for a pending email link
  /// (cross-device scenario).
  Future<UserModel?> signInWithPendingLink(String email) async {
    if (_pendingEmailLink == null) {
      state = state.copyWith(error: 'لا يوجد رابط معلق');
      return null;
    }
    return signInWithEmailLink(_pendingEmailLink!, email: email);
  }

  ActionCodeSettings _getActionCodeSettings() {
    return ActionCodeSettings(
      url: 'https://alrasikhoon-57151.web.app',
      handleCodeInApp: true,
      androidPackageName: 'com.alrasikhoon.al_rasikhoon',
      androidInstallApp: true,
      iOSBundleId: 'com.alrasikhoon.alRasikhoon',
    );
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    await _googleAuthService.signOut();
    await _localStorage.clearPendingSignInEmail();
    await _localStorage.clearUserData();
    _pendingEmailLink = null;
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
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً';
        case 'expired-action-code':
          return 'انتهت صلاحية الرابط. يرجى طلب رابط جديد';
        case 'invalid-action-code':
          return 'الرابط غير صالح. يرجى طلب رابط جديد';
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
