import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    _firebaseService.authStateChanges.listen((user) async {
      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        // Fire-and-forget: never blocks the UI-visible state.
        _refreshAppUser(user.uid);
      } else {
        // Genuine auth loss (no persisted session or revoked): drop the
        // optimistic cache and fall back to login. Not on the hot UI path,
        // so await for durability.
        await _sessionCache.clear();
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
      // Discard a stale result: the session may have changed (sign-out or a
      // different account signing in) while this fetch was in flight. Applying
      // it would resurrect a superseded session and re-persist it to disk.
      if (state.firebaseUser?.uid != uid) return;
      if (appUser == null || !appUser.isActive) {
        await signOut();
        return;
      }
      state = state.copyWith(appUser: appUser);
      await _sessionCache.cacheUser(appUser);
    } catch (error, stackTrace) {
      // Expected path: an offline / transient getUserById failure — keep
      // showing the cached optimistic profile. But this bare catch also
      // swallows programming errors and any throw from signOut(), so surface
      // it at debug level so a genuine reconcile bug isn't invisible in the
      // field.
      debugPrint('_refreshAppUser reconcile failed: $error\n$stackTrace');
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

  /// Update the signed-in user's own profile (name, phone), then reconcile
  /// local state and the session cache so the UI reflects the change
  /// immediately. The post-write refetch keeps the server the source of
  /// truth (server timestamp on updated_at); if it misses (e.g. transient
  /// read failure right after a successful write), fall back to a local copy
  /// so the visible profile still matches what was saved.
  Future<void> updateOwnProfile({
    required String name,
    required String? phone,
  }) async {
    final current = state.appUser;
    if (current == null) {
      throw StateError('updateOwnProfile called with no signed-in user');
    }

    await _userRepository.updateProfileFields(
      userId: current.id,
      name: name,
      phone: phone,
    );

    // Not copyWith: its null-coalescing semantics can't CLEAR phone.
    final updated =
        await _userRepository.getUserById(current.id) ??
        UserModel(
          id: current.id,
          username: current.username,
          email: current.email,
          phone: phone,
          name: name,
          role: current.role,
          authProvider: current.authProvider,
          instituteId: current.instituteId,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
          isActive: current.isActive,
        );
    state = state.copyWith(appUser: updated);
    await _sessionCache.cacheUser(updated);
  }

  /// Change the signed-in user's own password (any role, including admins).
  /// Reauthenticates with [currentPassword] first. Returns null on success,
  /// or a user-facing Arabic error message on failure.
  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _firebaseService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'كلمة المرور الحالية غير صحيحة';
        case 'weak-password':
          return 'كلمة المرور الجديدة ضعيفة، اختر كلمة أقوى';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً';
        default:
          return 'تعذر تغيير كلمة المرور، حاول مرة أخرى';
      }
    } catch (_) {
      return 'تعذر تغيير كلمة المرور، حاول مرة أخرى';
    }
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
