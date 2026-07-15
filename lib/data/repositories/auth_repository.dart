import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/session_cache.dart';
import '../../core/constants/app_constants.dart';
import 'user_repository.dart';
import '../models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final User? firebaseUser;
  final UserModel? appUser;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.firebaseUser,
    this.appUser,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    User? firebaseUser,
    UserModel? appUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      appUser: appUser ?? this.appUser,
    );
  }
}

class AuthRepository extends Notifier<AuthState> {
  late final FirebaseService _firebaseService;
  late final UserRepository _userRepository;
  late final SessionCache _sessionCache;

  @override
  AuthState build() {
    _firebaseService = ref.watch(firebaseServiceProvider);
    _userRepository = ref.watch(userRepositoryProvider);
    _sessionCache = ref.watch(sessionCacheProvider);

    // Optimistic seed: route the returning user from the locally cached
    // profile before any network call. The authStateChanges listener below
    // refreshes and reconciles in the background.
    final cachedUser = _sessionCache.readUser();

    _init();

    return AuthState(appUser: cachedUser);
  }

  void _init() {
    _firebaseService.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        // Fire-and-forget: never blocks the UI-visible state.
        _refreshAppUser(user.uid);
      } else {
        // Genuine auth loss (no persisted session or revoked): drop the
        // optimistic cache and fall back to login.
        _sessionCache.clear();
        state = const AuthState();
      }
    });
  }

  /// Background refresh + reconcile against Firestore. The server is the
  /// source of truth; a role/profile change updates state (and the router
  /// re-routes), a deleted/disabled account signs out, and an offline
  /// failure leaves the cached optimistic state intact.
  Future<void> _refreshAppUser(String uid) async {
    try {
      final appUser = await _userRepository.getUserById(uid);
      if (appUser == null || !appUser.isActive) {
        await signOut();
        return;
      }
      state = state.copyWith(appUser: appUser);
      await _sessionCache.cacheUser(appUser);
    } catch (_) {
      // Offline / transient: keep showing the cached profile.
    }
  }

  /// Sign in with username + password. The username is the user-visible
  /// identifier; under the hood we feed Firebase Auth the synthesized email
  /// `<username>@alrasikhoon.local`. Returns the loaded UserModel on success
  /// or null on failure (state.error is set).
  Future<UserModel?> signInWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final normalizedUsername = username.trim().toLowerCase();
    final synthesizedEmail =
        '$normalizedUsername@${AppConstants.synthesizedEmailDomain}';

    try {
      final userCredential = await _firebaseService.signInWithEmailPassword(
        email: synthesizedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        state = state.copyWith(isLoading: false, error: 'فشل تسجيل الدخول');
        return null;
      }

      state = state.copyWith(firebaseUser: user);

      // Look up the user doc by username first; fall back to UID.
      var appUser = await _userRepository.getUserByUsername(normalizedUsername);
      appUser ??= await _userRepository.getUserById(user.uid);

      if (appUser == null) {
        state = state.copyWith(isLoading: false, error: 'account_not_found');
        return null;
      }

      state = state.copyWith(isLoading: false, appUser: appUser);
      await _sessionCache.cacheUser(appUser);
      return appUser;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Reset another user's password via the setUserPassword Cloud Function.
  /// Authorization is enforced server-side: super_admin can reset any user;
  /// teachers can reset their own students/guardians.
  Future<void> setPasswordForUser({
    required String userId,
    required String newPassword,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'setUserPassword',
    );
    await callable.call<dynamic>({
      'userId': userId,
      'newPassword': newPassword,
    });
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    await _sessionCache.clear();
    state = const AuthState();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'اسم المستخدم غير صحيح';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب';
        case 'user-not-found':
          return 'لا يوجد حساب بهذا الاسم';
        case 'wrong-password':
        case 'invalid-credential':
          return 'اسم المستخدم أو كلمة المرور غير صحيحة';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً';
        default:
          return error.message ?? 'حدث خطأ غير متوقع';
      }
    }
    return error.toString();
  }

  bool get isAuthenticated => state.appUser != null;
  bool get isAccountNotFound => state.error == 'account_not_found';
  UserModel? get currentUser => state.appUser;
  UserRole? get currentUserRole => state.appUser?.role;
}

final authRepositoryProvider = NotifierProvider<AuthRepository, AuthState>(
  AuthRepository.new,
);
