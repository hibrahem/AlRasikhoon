import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/student_repository.dart';
import 'user_provider.dart';

/// Resolves "the student whose data we are viewing" for the current user.
///
/// Role-agnostic by construction: it depends only on the shared
/// [currentUserProvider] and the data-layer [studentRepositoryProvider]. It
/// works for a student viewing their own record and for a guardian viewing a
/// selected child, so it lives in `shared/providers` rather than the student
/// feature. This lets the shared account screen show a student's progress
/// without reaching into the student feature.

/// Selected child id for guardians who have multiple children.
/// `null` means "show the first child" (default for single-child guardians).
class SelectedChildId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? studentId) => state = studentId;
}

final selectedChildIdProvider = NotifierProvider<SelectedChildId, String?>(
  SelectedChildId.new,
);

/// Provider for current student profile
/// For students: returns their own student record
/// For guardians: returns the selected child (or first child if none selected)
final currentStudentProvider = FutureProvider<StudentModel?>((ref) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final repo = ref.watch(studentRepositoryProvider);

  // If user is a guardian, fetch their child's data
  if (currentUser.role == UserRole.guardian) {
    final selectedId = ref.watch(selectedChildIdProvider);
    if (selectedId != null) {
      return repo.getStudentById(selectedId);
    }
    return repo.getFirstStudentByGuardianId(currentUser.id);
  }

  // Otherwise, fetch the student's own data
  return repo.getStudentByUserId(currentUser.id);
});

/// Provider for guardian's children (for multi-child support)
final guardianChildrenProvider = FutureProvider<List<StudentWithUser>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null || currentUser.role != UserRole.guardian) return [];

  final repo = ref.watch(studentRepositoryProvider);
  return repo.getStudentsByGuardianId(currentUser.id);
});
