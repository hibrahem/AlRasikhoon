import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../domain/curriculum/curriculum_progress.dart';
import 'current_student_provider.dart';

/// The signed-in student's (or a guardian's selected child's) progress through
/// the whole curriculum: the numbers behind the dashboard's progress hero.
///
/// Composes the student's position with the levels catalog and defers every
/// derivation to [CurriculumProgress.of]. While either dependency is still
/// resolving — or there is no student — it yields an all-zero progress rather
/// than a fabricated figure.
final curriculumProgressProvider = FutureProvider<CurriculumProgress>((
  ref,
) async {
  final student = await ref.watch(currentStudentProvider.future);
  if (student == null) {
    return const CurriculumProgress(
      sessionsCompleted: 0,
      totalSessions: 0,
      juzMemorized: 0,
    );
  }

  final levels = await ref.watch(levelsProvider.future);

  return CurriculumProgress.of(
    currentLevel: student.currentLevel,
    currentOrderInLevel: student.currentOrderInLevel,
    curriculumCompleted: student.curriculumCompleted,
    levels: levels,
  );
});
