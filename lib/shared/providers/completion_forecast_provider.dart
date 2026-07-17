import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/session_model.dart';
import '../../data/repositories/curriculum_repository.dart';
import '../../domain/curriculum/completion_forecast.dart';

/// A student's position, as the forecast cares about it. A record, so two
/// equal positions are ONE family entry — every host of the forecast card for
/// the same student shares a single computation.
typedef ForecastPosition = ({int level, int order, bool completed});

/// Everything still ahead of a position, run-length encoded for the forecast.
///
/// Watches the catalog plus each remaining level's sessions
/// ([levelSessionsProvider] caches per level), so the worst case — a level-1
/// student, the whole curriculum — is fetched once per app session and every
/// what-if slider tick after that is pure arithmetic on this value.
final remainingCurriculumProvider =
    FutureProvider.family<RemainingCurriculum, ForecastPosition>((
      ref,
      position,
    ) async {
      if (position.completed) return RemainingCurriculum.none;

      final levels = await ref.watch(levelsProvider.future);

      final ahead = levels
          .where((level) => level.levelNumber >= position.level)
          .toList();
      final sessionLists = await Future.wait(
        ahead.map(
          (level) => ref.watch(levelSessionsProvider(level.levelNumber).future),
        ),
      );
      final sessionsByLevel = <int, List<SessionModel>>{
        for (var i = 0; i < ahead.length; i++)
          ahead[i].levelNumber: sessionLists[i],
      };

      return RemainingCurriculum.of(
        currentLevel: position.level,
        currentOrderInLevel: position.order,
        curriculumCompleted: position.completed,
        levels: levels,
        sessionsByLevel: sessionsByLevel,
      );
    });
