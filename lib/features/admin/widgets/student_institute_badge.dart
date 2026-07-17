import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/institute_badge.dart';
import '../providers/admin_provider.dart';

/// Names the institute a student belongs to, for the admin's student progress
/// header. An admin sees students across every institute, so the affiliation
/// is not implied by the shell the way it is for a teacher or a supervisor —
/// this is why only the admin route injects it into `StudentProgressScreen`.
///
/// Resolves the name itself from the student's `institute_id` so the shared
/// screen stays ignorant of institutes. While loading, or if the institute
/// can't be resolved (deleted, or a load error), it renders nothing rather
/// than an empty badge — the header is complete without it.
class StudentInstituteBadge extends ConsumerWidget {
  final String instituteId;

  const StudentInstituteBadge({super.key, required this.instituteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institute = ref.watch(instituteProvider(instituteId)).value;
    final name = institute?.name ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return InstituteBadge(name: name);
  }
}
