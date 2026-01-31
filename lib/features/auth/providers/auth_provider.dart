import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';

// Re-export auth repository provider
export '../../../data/repositories/auth_repository.dart';

/// Current authenticated user provider
final currentAuthUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.appUser;
});

/// Is loading provider
final authLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.isLoading;
});

/// Auth error provider
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.error;
});

/// Password reset sent provider
final passwordResetSentProvider = Provider<bool>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.passwordResetSent;
});

/// Email authentication notifier for managing email/password and Google sign-in
class EmailAuthNotifier extends Notifier<EmailAuthState> {
  @override
  EmailAuthState build() => const EmailAuthState();

  Future<UserModel?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await ref.read(authRepositoryProvider.notifier).signInWithGoogle();
      final authState = ref.read(authRepositoryProvider);

      if (authState.error != null) {
        state = state.copyWith(
          isLoading: false,
          error: authState.error,
          isAccountNotFound: authState.error == 'account_not_found',
        );
        return null;
      }

      state = state.copyWith(isLoading: false, user: user);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await ref.read(authRepositoryProvider.notifier).signInWithEmailPassword(
        email: email,
        password: password,
      );
      final authState = ref.read(authRepositoryProvider);

      if (authState.error != null) {
        state = state.copyWith(
          isLoading: false,
          error: authState.error,
          isAccountNotFound: authState.error == 'account_not_found',
        );
        return null;
      }

      state = state.copyWith(isLoading: false, user: user);
      return user;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null, passwordResetSent: false);

    try {
      await ref.read(authRepositoryProvider.notifier).sendPasswordResetEmail(email);
      final authState = ref.read(authRepositoryProvider);

      if (authState.error != null) {
        state = state.copyWith(isLoading: false, error: authState.error);
      } else {
        state = state.copyWith(isLoading: false, passwordResetSent: true);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() {
    state = const EmailAuthState();
  }
}

class EmailAuthState {
  final bool isLoading;
  final String? error;
  final String? email;
  final UserModel? user;
  final bool isAccountNotFound;
  final bool passwordResetSent;

  const EmailAuthState({
    this.isLoading = false,
    this.error,
    this.email,
    this.user,
    this.isAccountNotFound = false,
    this.passwordResetSent = false,
  });

  EmailAuthState copyWith({
    bool? isLoading,
    String? error,
    String? email,
    UserModel? user,
    bool? isAccountNotFound,
    bool? passwordResetSent,
  }) {
    return EmailAuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      email: email ?? this.email,
      user: user ?? this.user,
      isAccountNotFound: isAccountNotFound ?? this.isAccountNotFound,
      passwordResetSent: passwordResetSent ?? this.passwordResetSent,
    );
  }
}

final emailAuthProvider = NotifierProvider<EmailAuthNotifier, EmailAuthState>(
  EmailAuthNotifier.new,
);
