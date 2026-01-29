import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

/// Provider for the current authenticated user
final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.appUser;
});

/// Provider for the current user's role
final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.firebaseUser != null && authState.appUser != null;
});

/// Provider to check if user is a super admin
final isSuperAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.superAdmin;
});

/// Provider to check if user is a supervisor
final isSupervisorProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.supervisor;
});

/// Provider to check if user is a teacher
final isTeacherProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.teacher;
});

/// Provider to check if user is a student
final isStudentProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.student;
});

/// Provider to check if user is a guardian
final isGuardianProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == UserRole.guardian;
});
