import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/session/session_duration.dart';
import '../../../shared/widgets/session_timer.dart';
import '../providers/teacher_provider.dart';

/// The live session timer for the lesson/تلقين flow: reads the start instant
/// from the active session and the target from the student's live pace, so
/// each in-session screen only has to drop this into its app bar.
class ActiveLessonTimer extends ConsumerWidget {
  final String studentId;

  const ActiveLessonTimer({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startedAt = ref.watch(activeSessionProvider)?.startedAt;
    if (startedAt == null) return const SizedBox.shrink();

    final pace =
        ref.watch(studentProvider(studentId)).value?.student.pace.multiplier ??
        1;
    return SessionTimer(
      key: ValueKey(startedAt),
      startedAt: startedAt,
      target: SessionDuration.targetForPace(pace),
    );
  }
}
