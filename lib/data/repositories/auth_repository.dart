import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import 'user_repository.dart';
import '../models/user_model.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final int? resendToken;
  final User? firebaseUser;
  final UserModel? appUser;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.resendToken,
    this.firebaseUser,
    this.appUser,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? verificationId,
    int? resendToken,
    User? firebaseUser,
    UserModel? appUser,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      firebaseUser: firebaseUser ?? this.firebaseUser,
      appUser: appUser ?? this.appUser,
    );
  }
}

class AuthRepository extends Notifier<AuthState> {
  late final FirebaseService _firebaseService;
  late final UserRepository _userRepository;
  late final LocalStorageService _localStorage;

  @override
  AuthState build() {
    _firebaseService = ref.watch(firebaseServiceProvider);
    _userRepository = ref.watch(userRepositoryProvider);
    _localStorage = ref.watch(localStorageServiceProvider);
    _init();
    return const AuthState();
  }

  void _init() {
    _firebaseService.authStateChanges.listen((user) async {
      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        await _loadAppUser(user.uid);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadAppUser(String uid) async {
    try {
      final appUser = await _userRepository.getUserById(uid);
      if (appUser != null) {
        state = state.copyWith(appUser: appUser);
        await _localStorage.setUserId(appUser.id);
        await _localStorage.setUserRole(appUser.role.value);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _firebaseService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(
            isLoading: false,
            error: _getErrorMessage(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            resendToken: resendToken,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
        forceResendingToken: state.resendToken,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<UserModel?> verifyOtp(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(error: 'لم يتم إرسال رمز التحقق');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final credential = _firebaseService.createPhoneAuthCredential(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );

      return await _signInWithCredential(credential);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
      return null;
    }
  }

  Future<UserModel?> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await _firebaseService.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        state = state.copyWith(firebaseUser: user);

        // Check if user exists in our database
        final appUser = await _userRepository.getUserById(user.uid);

        if (appUser != null) {
          state = state.copyWith(
            isLoading: false,
            appUser: appUser,
          );
          await _localStorage.setUserId(appUser.id);
          await _localStorage.setUserRole(appUser.role.value);
          return appUser;
        } else {
          // User not found in database
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
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    await _localStorage.clearUserData();
    state = const AuthState();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'رقم الجوال غير صحيح';
        case 'invalid-verification-code':
          return 'رمز التحقق غير صحيح';
        case 'too-many-requests':
          return 'تم تجاوز عدد المحاولات، يرجى المحاولة لاحقاً';
        case 'session-expired':
          return 'انتهت صلاحية رمز التحقق';
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
