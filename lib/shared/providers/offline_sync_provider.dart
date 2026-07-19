import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../data/repositories/institute_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/offline_cache_primer.dart';
import '../../features/student/providers/student_provider.dart';
import '../../features/supervisor/providers/supervisor_provider.dart';
import '../../features/teacher/providers/teacher_provider.dart';
import 'connectivity_provider.dart';
import 'user_provider.dart';

final offlineCachePrimerProvider = Provider<OfflineCachePrimer>((ref) {
  return OfflineCachePrimer(
    studentRepository: ref.watch(studentRepositoryProvider),
    curriculumRepository: ref.watch(curriculumRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
    instituteRepository: ref.watch(instituteRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

/// Watched once from the app root. Primes Firestore's cache when a signed-in
/// user is online, and re-primes plus refreshes stale views on every
/// offline→online transition — the refresh is also what clears the
/// "بانتظار المزامنة" chips without user action (spec §4).
final offlineSyncControllerProvider = Provider<void>((ref) {
  void primeNow() {
    // Priming is opportunistic (see OfflineCachePrimer): a failure to even
    // START it — e.g. Firebase not initialized in a widget-test harness —
    // must never take the app root down with it.
    try {
      final user = ref.read(currentUserProvider);
      if (user != null && ref.read(isConnectedProvider)) {
        unawaited(ref.read(offlineCachePrimerProvider).prime(user));
      }
    } catch (_) {}
  }

  ref.listen(currentUserProvider, (previous, next) {
    if (next != null && previous?.id != next.id) primeNow();
  });

  ref.listen(isConnectedProvider, (previous, next) {
    if (previous == false && next == true) {
      primeNow();
      // Family-wide invalidation: every member refetches, so records that
      // just synced re-read with hasPendingWrites == false.
      ref.invalidate(teacherStudentsProvider);
      ref.invalidate(studentProvider);
      ref.invalidate(teacherStudentSessionHistoryProvider);
      ref.invalidate(examQueueProvider);
      ref.invalidate(supervisorStudentSessionHistoryProvider);
      ref.invalidate(studentHistoryProvider);
    }
  });

  primeNow();
});
