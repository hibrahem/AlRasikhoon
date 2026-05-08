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
