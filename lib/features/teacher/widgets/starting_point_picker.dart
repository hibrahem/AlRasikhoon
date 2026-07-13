import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/session_model.dart';
import '../../../data/repositories/curriculum_repository.dart';
import '../../../domain/curriculum/curriculum_position.dart';

/// Picks where a student enters the curriculum: **level, then juz, then
/// session** — which is exactly the identity of a curriculum session document
/// (`L{level}_J{juz}_S{n}`).
///
/// The middle step is the JUZ, not the hizb: a hizb is a nullable LABEL of
/// levels 1-2 alone, and a juz- or level-tier assessment belongs to no hizb at
/// all, so a hizb-keyed picker could not offer `سرد الجزء رقم 30 كاملًا` as a
/// starting point.
///
/// The juz are listed in the level's TEACHING order, read from the levels
/// catalog — never computed: levels 1-9 run their juz descending (30 → 29 → 28)
/// while level 10 runs ASCENDING (1 → 2 → 3), because سورة البقرة spans those
/// juz and a surah is memorized front to back.
///
/// The sessions are the ones the curriculum actually contains in that juz, each
/// labelled from the DATA: a lesson by its Qur'an range, an assessment by the
/// source's verbatim Arabic label. A student may be placed directly onto any
/// assessment — including a juz- or level-tier one — because a student may
/// arrive ready to be assessed.
///
/// [initialValue] seeds the picker's initial level/juz/session; from then on the
/// picker owns the selection itself and reports every change through
/// [onChanged]. There is no `didUpdateWidget` handling: changes to
/// [initialValue] after the first build are not picked up, by design — it is a
/// seed, not a controlled prop. A juz may hold no sessions at all (a gap in the
/// seeded curriculum) — when that happens there is no valid starting point to
/// report, so [onChanged] is called with `null` rather than inventing one.
class StartingPointPicker extends ConsumerStatefulWidget {
  final CurriculumPosition initialValue;
  final ValueChanged<CurriculumPosition?> onChanged;

  const StartingPointPicker({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  ConsumerState<StartingPointPicker> createState() =>
      _StartingPointPickerState();
}

class _StartingPointPickerState extends ConsumerState<StartingPointPicker> {
  late int _level;
  late int _juz;
  int? _session;

  /// The sessions that exist in the chosen juz — the curriculum's own rows, so
  /// each can be labelled from its own data.
  List<SessionModel> _sessions = const [];

  /// Guards against a slower response from an earlier (level, juz) selection
  /// overwriting the sessions of a later one: only the response whose
  /// generation matches the most recent request is applied.
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _level = widget.initialValue.level;
    _juz = widget.initialValue.juz;
    _session = widget.initialValue.session;
    _loadSessions(_level, _juz);
  }

  /// Fetches the sessions that exist in ([level], [juz]), keeps the current
  /// session if it is still valid there (otherwise falls back to the first
  /// available session, or to no session at all if there is none), and reports
  /// the resulting position to the parent.
  ///
  /// Used both for the initial load and every subsequent level/juz change —
  /// there is exactly one path that fetches sessions and applies them.
  Future<void> _loadSessions(int level, int juz) async {
    final requestId = ++_requestGeneration;
    final sessions = await ref
        .read(curriculumRepositoryProvider)
        .getSessionsForJuz(level: level, juz: juz);
    if (!mounted || requestId != _requestGeneration) return;

    setState(() {
      _sessions = sessions;
      final numbers = sessions.map((s) => s.sessionNumber);
      if (!numbers.contains(_session)) {
        _session = sessions.isEmpty ? null : sessions.first.sessionNumber;
      }
    });
    _report();
  }

  /// The juz of [level] in TEACHING order, from the catalog. Never computed.
  List<int> _juzOfLevel(List<LevelModel> levels, int level) {
    for (final entry in levels) {
      if (entry.levelNumber == level) return entry.juzNumbers;
    }
    return const [];
  }

  void _changeLevel(int level, List<LevelModel> levels) {
    final juz = _juzOfLevel(levels, level);
    if (juz.isEmpty) return;
    // The FIRST juz a level teaches, as the catalog orders it — which is juz 1
    // in level 10 and juz 30 in level 1.
    final first = juz.first;

    setState(() {
      _level = level;
      _juz = first;
      _session = null;
    });
    // Tell the parent there is nothing valid to submit *before* dispatching the
    // fetch for the new juz — otherwise the parent keeps holding the previous
    // juz's position for the entire in-flight window, and a submit during that
    // window would create the student at a position the picker is no longer even
    // displaying.
    _report();
    _loadSessions(level, first);
  }

  void _changeJuz(int juz) {
    setState(() {
      _juz = juz;
      _session = null;
    });
    _report();
    _loadSessions(_level, juz);
  }

  void _changeSession(int session) {
    setState(() => _session = session);
    _report();
  }

  /// Tells the parent the current, validated position — or `null` while no
  /// session in [_juz] is selected, including when [_juz] has none to offer. The
  /// parent must treat `null` as "nothing to submit yet".
  void _report() {
    final session = _session;
    widget.onChanged(
      session == null
          ? null
          : CurriculumPosition.validated(
              level: _level,
              juz: _juz,
              session: session,
            ),
    );
  }

  /// What a session IS, in the curriculum's own words: an assessment by its
  /// verbatim label (`سرد الجزء رقم 30 كاملًا على المحفظ المتابع`), a lesson by
  /// its Qur'an range. Never `session == 35 ? 'السرد' : …`.
  String _sessionLabel(SessionModel session) {
    if (session.isAssessment) return session.titleAr;

    final range = session.currentLevelContent?.rangeAr ?? '';
    if (range.isEmpty) return 'الحلقة ${session.sessionNumber}';
    return 'الحلقة ${session.sessionNumber} — $range';
  }

  SessionModel? get _selectedSession {
    for (final session in _sessions) {
      if (session.sessionNumber == _session) return session;
    }
    return null;
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
    final session = _selectedSession;
    final message = session == null
        ? 'لا توجد حلقات لهذا الجزء في المنهج. اختر جزءًا آخر.'
        : 'سيبدأ الطالب من ${_startingPointAr(session)}، '
              'الجزء $_juz، المستوى $_level — '
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

  /// The chosen starting point, said briefly: the assessment's own label, or
  /// the lesson's number.
  String _startingPointAr(SessionModel session) => session.isAssessment
      ? session.titleAr
      : 'الحلقة ${session.sessionNumber}';

  Widget _buildDropdowns(BuildContext context, List<LevelModel> levels) {
    final juzNumbers = _juzOfLevel(levels, _level);

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
              _changeLevel(level, levels);
            },
          ),
        ),
        const SizedBox(height: 16),
        _field(
          context,
          label: 'الجزء',
          child: DropdownButton<int>(
            key: const Key('starting_point_juz'),
            isExpanded: true,
            // The catalog's teaching order, verbatim.
            value: juzNumbers.contains(_juz) ? _juz : null,
            hint: const Text('اختر الجزء'),
            items: juzNumbers
                .map(
                  (juz) =>
                      DropdownMenuItem(value: juz, child: Text('الجزء $juz')),
                )
                .toList(),
            onChanged: (juz) {
              if (juz == null) return;
              _changeJuz(juz);
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
            value: _selectedSession?.sessionNumber,
            hint: const Text('اختر الحلقة'),
            items: _sessions
                .map(
                  (session) => DropdownMenuItem(
                    value: session.sessionNumber,
                    child: Text(
                      _sessionLabel(session),
                      overflow: TextOverflow.ellipsis,
                    ),
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
