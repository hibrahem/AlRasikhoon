import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/level_model.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../domain/curriculum/curriculum_order.dart';
import '../../../domain/curriculum/curriculum_position.dart';

/// Picks where a student enters the curriculum: level, then hizb, then session.
///
/// The hizbs are offered in teaching order (level 1: 59, 60, 57, 58, 55, 56) and
/// the sessions are the ones the curriculum actually contains — it is sparse, so
/// a hizb may hold 18 sessions numbered between 2 and 36. Sard (35) and Exam (36)
/// are valid starting points: a student may arrive ready to be assessed.
class StartingPointPicker extends ConsumerStatefulWidget {
  final CurriculumPosition value;
  final ValueChanged<CurriculumPosition> onChanged;

  const StartingPointPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<StartingPointPicker> createState() =>
      _StartingPointPickerState();
}

class _StartingPointPickerState extends ConsumerState<StartingPointPicker> {
  List<int> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions(widget.value.level, widget.value.hizb);
  }

  Future<void> _loadSessions(int level, int hizb) async {
    final sessions = await ref
        .read(curriculumRepositoryProvider)
        .getSessionNumbersForHizb(level: level, hizb: hizb);
    if (mounted) setState(() => _sessions = sessions);
  }

  /// Moves the student to the first session that exists in [hizb] of [level].
  Future<void> _selectHizb(int level, int hizb) async {
    final sessions = await ref
        .read(curriculumRepositoryProvider)
        .getSessionNumbersForHizb(level: level, hizb: hizb);
    if (!mounted) return;
    setState(() => _sessions = sessions);
    widget.onChanged(
      CurriculumPosition.validated(
        level: level,
        hizb: hizb,
        session: sessions.isEmpty ? 1 : sessions.first,
      ),
    );
  }

  String _sessionLabel(int session) {
    if (session == AppConstants.sardSessionNumber) return 'السرد';
    if (session == AppConstants.examSessionNumber) return 'الاختبار';
    return 'الحلقة $session';
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(levelsProvider);
    final position = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نقطة البداية في المنهج',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        levelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'تعذر تحميل المنهج',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
          data: (levels) => _buildDropdowns(context, levels, position),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سيبدأ الطالب من ${_sessionLabel(position.session)}، '
                  'الحزب ${position.hizb}، المستوى ${position.level} — '
                  'ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdowns(
    BuildContext context,
    List<LevelModel> levels,
    CurriculumPosition position,
  ) {
    final hizbs = CurriculumOrder.hizbsOfLevel(position.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          context,
          label: 'المستوى',
          child: DropdownButton<int>(
            key: const Key('starting_point_level'),
            isExpanded: true,
            value: position.level,
            items: levels
                .map(
                  (level) => DropdownMenuItem(
                    value: level.levelNumber,
                    child: Text('${level.nameAr} (${level.juzRangeAr})'),
                  ),
                )
                .toList(),
            onChanged: (level) {
              if (level == null) return;
              _selectHizb(level, CurriculumOrder.firstHizbOfLevel(level));
            },
          ),
        ),
        const SizedBox(height: 16),
        _field(
          context,
          label: 'الحزب',
          child: DropdownButton<int>(
            key: const Key('starting_point_hizb'),
            isExpanded: true,
            value: position.hizb,
            items: hizbs
                .map(
                  (hizb) => DropdownMenuItem(
                    value: hizb,
                    child: Text(
                      'الحزب $hizb (الجزء ${CurriculumOrder.juzOfHizb(hizb)})',
                    ),
                  ),
                )
                .toList(),
            onChanged: (hizb) {
              if (hizb == null) return;
              _selectHizb(position.level, hizb);
            },
          ),
        ),
        const SizedBox(height: 16),
        _field(
          context,
          label: 'الحلقة',
          child: DropdownButton<int>(
            key: const Key('starting_point_session'),
            isExpanded: true,
            value: _sessions.contains(position.session)
                ? position.session
                : null,
            hint: const Text('اختر الحلقة'),
            items: _sessions
                .map(
                  (session) => DropdownMenuItem(
                    value: session,
                    child: Text(_sessionLabel(session)),
                  ),
                )
                .toList(),
            onChanged: (session) {
              if (session == null) return;
              widget.onChanged(
                CurriculumPosition.validated(
                  level: position.level,
                  hizb: position.hizb,
                  session: session,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(child: child),
        ),
      ],
    );
  }
}
