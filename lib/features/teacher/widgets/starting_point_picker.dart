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
///
/// [value] seeds the picker's initial level/hizb/session; from then on the
/// picker owns the selection itself and reports every change through
/// [onChanged]. Some hizbs hold no sessions at all (a gap in the seeded
/// curriculum) — when that happens there is no valid starting point to
/// report, so [onChanged] is called with `null` rather than inventing one.
class StartingPointPicker extends ConsumerStatefulWidget {
  final CurriculumPosition value;
  final ValueChanged<CurriculumPosition?> onChanged;

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
  late int _level;
  late int _hizb;
  int? _session;
  List<int> _sessions = const [];

  /// Guards against a slower response from an earlier (level, hizb)
  /// selection overwriting the sessions of a later one: only the response
  /// whose generation matches the most recent request is applied.
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _level = widget.value.level;
    _hizb = widget.value.hizb;
    _session = widget.value.session;
    _loadSessions(_level, _hizb);
  }

  /// Fetches the sessions that exist for ([level], [hizb]), keeps the
  /// current session if it is still valid there (otherwise falls back to
  /// the first available session, or to no session at all if there is
  /// none), and reports the resulting position to the parent.
  ///
  /// Used both for the initial load and every subsequent level/hizb change
  /// — there is exactly one path that fetches sessions and applies them.
  Future<void> _loadSessions(int level, int hizb) async {
    final requestId = ++_requestGeneration;
    final sessions = await ref
        .read(curriculumRepositoryProvider)
        .getSessionNumbersForHizb(level: level, hizb: hizb);
    if (!mounted || requestId != _requestGeneration) return;

    setState(() {
      _sessions = sessions;
      if (!sessions.contains(_session)) {
        _session = sessions.isEmpty ? null : sessions.first;
      }
    });
    _report();
  }

  void _changeLevel(int level) {
    final hizb = CurriculumOrder.firstHizbOfLevel(level);
    setState(() {
      _level = level;
      _hizb = hizb;
      _session = null;
    });
    _loadSessions(level, hizb);
  }

  void _changeHizb(int hizb) {
    setState(() {
      _hizb = hizb;
      _session = null;
    });
    _loadSessions(_level, hizb);
  }

  void _changeSession(int session) {
    setState(() => _session = session);
    _report();
  }

  /// Tells the parent the current, validated position — or `null` while no
  /// session in [_hizb] is selected, including when [_hizb] has none to
  /// offer. The parent must treat `null` as "nothing to submit yet".
  void _report() {
    final session = _session;
    widget.onChanged(
      session == null
          ? null
          : CurriculumPosition.validated(
              level: _level,
              hizb: _hizb,
              session: session,
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
          data: (levels) => _buildDropdowns(context, levels),
        ),
        const SizedBox(height: 16),
        _buildBanner(context),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    final session = _session;
    final message = session == null
        ? 'لا توجد حلقات لهذا الحزب في المنهج. اختر حزبًا آخر.'
        : 'سيبدأ الطالب من ${_sessionLabel(session)}، '
              'الحزب $_hizb، المستوى $_level — '
              'ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا.';

    return Container(
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
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdowns(BuildContext context, List<LevelModel> levels) {
    final hizbs = CurriculumOrder.hizbsOfLevel(_level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          context,
          label: 'المستوى',
          child: DropdownButton<int>(
            key: const Key('starting_point_level'),
            isExpanded: true,
            value: _level,
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
              _changeLevel(level);
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
            value: _hizb,
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
              _changeHizb(hizb);
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
            value: _sessions.contains(_session) ? _session : null,
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
              _changeSession(session);
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
