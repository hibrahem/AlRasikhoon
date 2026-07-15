import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/institute_model.dart';
import '../../data/repositories/institute_repository.dart';
import 'user_provider.dart';

/// Institutes the current teacher is assigned to.
///
/// Role-agnostic by construction: it depends only on the shared
/// [currentUserProvider] and the data-layer [instituteRepositoryProvider], so
/// it lives in `shared/providers` rather than a feature package. This lets the
/// shared account screen show the teacher's institutes without reaching into
/// the teacher feature. For non-teacher roles the repository simply returns an
/// empty list.
final teacherInstitutesProvider = FutureProvider<List<InstituteModel>>((
  ref,
) async {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final repo = ref.watch(instituteRepositoryProvider);
  return repo.getInstitutesForTeacher(currentUser.id);
});
