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

/// Phone verification notifier for managing OTP flow
class PhoneVerificationNotifier extends Notifier<PhoneVerificationState> {
  @override
  PhoneVerificationState build() => const PhoneVerificationState();

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await ref.read(authRepositoryProvider.notifier).sendOtp(phoneNumber);
      final authState = ref.read(authRepositoryProvider);

      if (authState.error != null) {
        state = state.copyWith(isLoading: false, error: authState.error);
      } else if (authState.verificationId != null) {
        state = state.copyWith(
          isLoading: false,
          verificationId: authState.verificationId,
          phoneNumber: phoneNumber,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<UserModel?> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await ref.read(authRepositoryProvider.notifier).verifyOtp(otp);
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

  void reset() {
    state = const PhoneVerificationState();
  }
}

class PhoneVerificationState {
  final bool isLoading;
  final String? error;
  final String? verificationId;
  final String? phoneNumber;
  final UserModel? user;
  final bool isAccountNotFound;

  const PhoneVerificationState({
    this.isLoading = false,
    this.error,
    this.verificationId,
    this.phoneNumber,
    this.user,
    this.isAccountNotFound = false,
  });

  PhoneVerificationState copyWith({
    bool? isLoading,
    String? error,
    String? verificationId,
    String? phoneNumber,
    UserModel? user,
    bool? isAccountNotFound,
  }) {
    return PhoneVerificationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      user: user ?? this.user,
      isAccountNotFound: isAccountNotFound ?? this.isAccountNotFound,
    );
  }
}

final phoneVerificationProvider =
    NotifierProvider<PhoneVerificationNotifier, PhoneVerificationState>(
  PhoneVerificationNotifier.new,
);
