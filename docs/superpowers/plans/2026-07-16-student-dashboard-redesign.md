# Student Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cluttered, duplicate-heavy student dashboard with a single grounded progress hero (curriculum-percent ring + juz-memorized caption + supporting stats), a merged home-practice card, and collapsed level-journey / stats sections — removing every duplicated figure.

**Architecture:** A new pure domain value object `CurriculumProgress` derives "sessions completed", "total sessions", and "juz memorized" from the student's curriculum position against the levels catalog. A thin `curriculumProgressProvider` composes it from `currentStudentProvider` + `levelsProvider`. Two new presentation widgets (`ProgressHeroCard`, `HomePracticeCard`) render the redesigned sections, and `StudentDashboardScreen` is re-assembled to wire them in the new order with `ExpansionTile`-collapsed journey and stats.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), go_router, `flutter_test`. RTL Arabic UI, manuscript design tokens via `context.tokens`.

## Global Constraints

- Run a single test with `flutter test <path>`; run the suite with `flutter test`. There is no Makefile or wrapper script.
- `flutter analyze` MUST be clean (no errors, no unused imports) before any commit.
- All user-facing strings are Arabic; the screen renders RTL. Interpolate integers directly (`'$juzMemorized'`) — the codebase renders Western digits, matching existing code like `'المستوى ${stats.currentLevel}'`. Do NOT hardcode Arabic-Indic numerals.
- Colors come only from `context.tokens` (`AppTokens`): `green` (positive/hero), `gold` (milestone), `maroon` (streak accent), `sepia` (captions), `hairline` (dividers), `surfaceVariant`. Never raw hex.
- Domain code follows the existing precedent (`lib/domain/curriculum/paced_session.dart` already imports `data/models`): `CurriculumProgress` may import `LevelModel`. Domain tests build `LevelModel` via `LevelModel.fromJson(id, map)` with plain maps — never a live Firestore.
- Reuse existing widgets: `CircularProgress`, `ProgressBar` (`lib/shared/widgets/progress_bar.dart`), `AppCard` (`lib/shared/widgets/app_card.dart`), `StatCardCompact` (`lib/shared/widgets/stat_card.dart`), `LevelProgressionWidget` (`lib/shared/widgets/level_progression_widget.dart`).
- Do NOT delete `HomeAssignmentCard` (still used by `home_practice_screen.dart`) or `StudentLevelProgress` (still used by `student_profile_screen.dart` and `student_progress_screen.dart`). Only remove their usages from the dashboard.
- Beads issue: `al_rasikhoon-4gw`. Spec: `docs/superpowers/specs/2026-07-16-student-dashboard-redesign-design.md`.

---

## File Structure

- **Create** `lib/domain/curriculum/curriculum_progress.dart` — pure `CurriculumProgress` value object + `.of(...)` factory. One responsibility: derive progress figures from position + catalog.
- **Create** `test/unit/domain/curriculum/curriculum_progress_test.dart` — domain tests (no mocks, no Firestore).
- **Create** `lib/shared/providers/curriculum_progress_provider.dart` — `curriculumProgressProvider` composing student + catalog.
- **Create** `lib/features/student/widgets/progress_hero_card.dart` — pure `ProgressHeroCard` (ring + juz caption + 3 stat chips).
- **Create** `test/widget/progress_hero_card_test.dart` — isolated widget test.
- **Create** `lib/features/student/widgets/home_practice_card.dart` — merged `HomePracticeCard` (assignment + counters).
- **Create** `test/widget/home_practice_card_test.dart` — both branches.
- **Modify** `lib/features/student/screens/student_dashboard_screen.dart` — new section order; wire new widgets; collapse journey + stats; remove `_buildProgressCard`, `_buildHomePracticeCard`, `_buildQuickStats`, `_PracticeStatItem`, and the dashboard usages of `StudentLevelProgress` / `HomeAssignmentCard`.

---

### Task 1: `CurriculumProgress` domain service

**Files:**
- Create: `lib/domain/curriculum/curriculum_progress.dart`
- Test: `test/unit/domain/curriculum/curriculum_progress_test.dart`

**Interfaces:**
- Consumes: `LevelModel` (`lib/data/models/level_model.dart`) — `levelNumber`, `sessionCount`, `juz` (list of `LevelJuz` with `lastOrderInLevel`).
- Produces:
  - `class CurriculumProgress` with `final int sessionsCompleted; final int totalSessions; final int juzMemorized;`, getters `double get fraction` (0..1) and `int get percent` (0..100), and `static const int totalJuz = 30;`.
  - `factory CurriculumProgress.of({required int currentLevel, required int currentOrderInLevel, required bool curriculumCompleted, required List<LevelModel> levels})`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/curriculum_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/level_model.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_progress.dart';

/// Builds a level's JSON the way `data/curriculum/levels.json` carries it, with
/// each juz's `first_order_in_level` computed from the running session total.
Map<String, dynamic> _levelJson(
  int id,
  List<int> juz,
  List<int> juzSessions,
) {
  var first = 1;
  final juzList = <Map<String, dynamic>>[];
  for (var i = 0; i < juz.length; i++) {
    juzList.add({
      'juz_number': juz[i],
      'session_count': juzSessions[i],
      'first_order_in_level': first,
    });
    first += juzSessions[i];
  }
  return {
    'id': id,
    'name_ar': '',
    'name_en': '',
    'order': id,
    'juz_numbers': juz,
    'session_count': juzSessions.fold<int>(0, (a, b) => a + b),
    'juz': juzList,
  };
}

List<LevelModel> _catalog(List<Map<String, dynamic>> jsons) => [
  for (final j in jsons) LevelModel.fromJson('level_${j['id']}', j),
];

/// A full 10-level catalog: levels 1-9 each teach three juz descending, level
/// 10 teaches juz 1,2,3 ascending. Session counts are illustrative but the
/// juz *count* per level (3) and level 10's ascending order are what matter.
List<LevelModel> _fullCatalog() => _catalog([
  _levelJson(1, [30, 29, 28], [70, 71, 69]),
  _levelJson(2, [27, 26, 25], [53, 49, 52]),
  _levelJson(3, [24, 23, 22], [35, 30, 35]),
  _levelJson(4, [21, 20, 19], [32, 33, 29]),
  _levelJson(5, [18, 17, 16], [22, 26, 23]),
  _levelJson(6, [15, 14, 13], [26, 26, 30]),
  _levelJson(7, [12, 11, 10], [17, 19, 24]),
  _levelJson(8, [9, 8, 7], [16, 26, 25]),
  _levelJson(9, [6, 5, 4], [23, 22, 22]),
  _levelJson(10, [1, 2, 3], [16, 19, 15]),
]);

void main() {
  group('CurriculumProgress.of', () {
    test('a brand-new student has memorized no juz and 0% of the curriculum', () {
      final p = CurriculumProgress.of(
        currentLevel: 1,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: _catalog([_levelJson(1, [30, 29, 28], [70, 71, 69])]),
      );
      expect(p.juzMemorized, 0);
      expect(p.sessionsCompleted, 0);
      expect(p.percent, 0);
      expect(p.fraction, 0);
    });

    test('mid first juz: sessions count up but no juz is memorized yet', () {
      final p = CurriculumProgress.of(
        currentLevel: 1,
        currentOrderInLevel: 40, // inside juz 30's block (orders 1..70)
        curriculumCompleted: false,
        levels: _catalog([_levelJson(1, [30, 29, 28], [70, 71, 69])]),
      );
      expect(p.juzMemorized, 0);
      expect(p.sessionsCompleted, 39);
    });

    test('crossing a juz boundary banks exactly one juz', () {
      final p = CurriculumProgress.of(
        currentLevel: 1,
        currentOrderInLevel: 71, // juz 30 (last order 70) is now fully behind
        curriculumCompleted: false,
        levels: _catalog([_levelJson(1, [30, 29, 28], [70, 71, 69])]),
      );
      expect(p.juzMemorized, 1);
    });

    test('standing at the start of level 2 means all of level 1 is memorized', () {
      final p = CurriculumProgress.of(
        currentLevel: 2,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: _catalog([
          _levelJson(1, [30, 29, 28], [70, 71, 69]),
          _levelJson(2, [27, 26, 25], [53, 49, 52]),
        ]),
      );
      expect(p.juzMemorized, 3);
      expect(p.sessionsCompleted, 210); // 70+71+69
    });

    test('level 10 ascends: order 1 means 27 juz memorized, not 30 - currentJuz', () {
      final p = CurriculumProgress.of(
        currentLevel: 10,
        currentOrderInLevel: 1, // juz 1 not yet finished
        curriculumCompleted: false,
        levels: _fullCatalog(),
      );
      // Levels 1-9 = 27 juz; none of level 10's juz banked yet.
      expect(p.juzMemorized, 27);
    });

    test('level 10: finishing juz 1 banks the 28th juz', () {
      final p = CurriculumProgress.of(
        currentLevel: 10,
        currentOrderInLevel: 17, // juz 1 block is orders 1..16
        curriculumCompleted: false,
        levels: _fullCatalog(),
      );
      expect(p.juzMemorized, 28);
    });

    test('a flexibly-enrolled student credits lower levels without completedLevels', () {
      final p = CurriculumProgress.of(
        currentLevel: 4,
        currentOrderInLevel: 1,
        curriculumCompleted: false,
        levels: _catalog([
          _levelJson(1, [30, 29, 28], [70, 71, 69]),
          _levelJson(2, [27, 26, 25], [53, 49, 52]),
          _levelJson(3, [24, 23, 22], [35, 30, 35]),
          _levelJson(4, [21, 20, 19], [32, 33, 29]),
        ]),
      );
      expect(p.juzMemorized, 9); // levels 1-3
      expect(p.sessionsCompleted, 210 + 154 + 100);
    });

    test('a graduated student is 30 juz / 100% regardless of position', () {
      final p = CurriculumProgress.of(
        currentLevel: 10,
        currentOrderInLevel: 44,
        curriculumCompleted: true,
        levels: _fullCatalog(),
      );
      expect(p.juzMemorized, 30);
      expect(p.percent, 100);
      expect(p.sessionsCompleted, p.totalSessions);
    });

    test('an unresolved (empty) catalog reports zero, never a fabricated denominator', () {
      final p = CurriculumProgress.of(
        currentLevel: 3,
        currentOrderInLevel: 20,
        curriculumCompleted: false,
        levels: const [],
      );
      expect(p.totalSessions, 0);
      expect(p.juzMemorized, 0);
      expect(p.fraction, 0);
      expect(p.percent, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/curriculum_progress_test.dart`
Expected: FAIL — `curriculum_progress.dart` / `CurriculumProgress` does not exist (compile error).

- [ ] **Step 3: Write minimal implementation**

Create `lib/domain/curriculum/curriculum_progress.dart`:

```dart
import '../../data/models/level_model.dart';

/// How far a student has come through the whole منهج, derived from their
/// curriculum position against the levels catalog.
///
/// Every figure is DATA-driven — the earlier Juz-ring hero was removed because
/// it computed its own math. `juzMemorized` is NOT `30 - currentJuz`: that
/// conflates the juz being worked on with a completed one, ignores mid-juz
/// progress, and is wrong for level 10 (whose juz ascend 1 → 2 → 3) and for
/// flexibly-enrolled students. Instead a juz counts as memorized only when its
/// whole session block sits behind the student's position, and every level
/// below the frontier is memorized in full (taught or credited at enrollment).
class CurriculumProgress {
  /// The Qur'an is 30 juz — the ceiling for [juzMemorized].
  static const int totalJuz = 30;

  final int sessionsCompleted;
  final int totalSessions;
  final int juzMemorized;

  const CurriculumProgress({
    required this.sessionsCompleted,
    required this.totalSessions,
    required this.juzMemorized,
  });

  /// 0.0..1.0. Zero when the catalog has not resolved ([totalSessions] == 0),
  /// so the hero shows no progress rather than dividing by a made-up total.
  double get fraction => totalSessions > 0
      ? (sessionsCompleted / totalSessions).clamp(0.0, 1.0)
      : 0.0;

  /// The curriculum fraction as a 0..100 integer, for the ring's center label.
  int get percent => (fraction * 100).round();

  /// Derives the figures from the student's position and the whole [levels]
  /// catalog (as `levelsProvider` yields it). An empty [levels] — the catalog
  /// is still loading — yields all zeros.
  factory CurriculumProgress.of({
    required int currentLevel,
    required int currentOrderInLevel,
    required bool curriculumCompleted,
    required List<LevelModel> levels,
  }) {
    if (levels.isEmpty) {
      return const CurriculumProgress(
        sessionsCompleted: 0,
        totalSessions: 0,
        juzMemorized: 0,
      );
    }

    final totalSessions = levels.fold<int>(0, (sum, l) => sum + l.sessionCount);

    if (curriculumCompleted) {
      return CurriculumProgress(
        sessionsCompleted: totalSessions,
        totalSessions: totalSessions,
        juzMemorized: totalJuz,
      );
    }

    var sessionsCompleted = 0;
    var juzMemorized = 0;

    // Every level below the frontier is memorized in full.
    for (final level in levels) {
      if (level.levelNumber < currentLevel) {
        sessionsCompleted += level.sessionCount;
        juzMemorized += level.juz.length;
      }
    }

    // The current level contributes its passed sessions and any juz whose whole
    // block is already behind the student.
    for (final level in levels) {
      if (level.levelNumber == currentLevel) {
        sessionsCompleted +=
            (currentOrderInLevel - 1).clamp(0, level.sessionCount);
        for (final juz in level.juz) {
          if (juz.lastOrderInLevel < currentOrderInLevel) juzMemorized++;
        }
        break;
      }
    }

    return CurriculumProgress(
      sessionsCompleted: sessionsCompleted,
      totalSessions: totalSessions,
      juzMemorized: juzMemorized,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/curriculum_progress_test.dart`
Expected: PASS (all 9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/curriculum/curriculum_progress.dart test/unit/domain/curriculum/curriculum_progress_test.dart
git commit -m "feat(student): CurriculumProgress domain service for dashboard hero (al_rasikhoon-4gw)"
```

---

### Task 2: `curriculumProgressProvider`

**Files:**
- Create: `lib/shared/providers/curriculum_progress_provider.dart`

**Interfaces:**
- Consumes: `currentStudentProvider` (`FutureProvider<StudentModel?>`, `lib/shared/providers/current_student_provider.dart`) — `StudentModel` exposes `currentLevel`, `currentOrderInLevel`, `curriculumCompleted`. `levelsProvider` (`FutureProvider<List<LevelModel>>`, `lib/data/repositories/curriculum_repository.dart`). `CurriculumProgress` (Task 1).
- Produces: `final curriculumProgressProvider` — `FutureProvider<CurriculumProgress>`.

This task is a thin composition with no branching logic of its own (all logic lives in the Task 1 domain service, which is fully tested). It is verified by `flutter analyze` + the widget wiring in Task 5, not a dedicated provider test.

- [ ] **Step 1: Write the implementation**

Create `lib/shared/providers/curriculum_progress_provider.dart`:

```dart
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
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `flutter analyze lib/shared/providers/curriculum_progress_provider.dart`
Expected: "No issues found!" If it reports that `StudentModel` lacks `curriculumCompleted` / `currentOrderInLevel`, open `lib/data/models/student_model.dart`, confirm the exact field names, and adjust the three arguments to match — do not invent fields.

- [ ] **Step 3: Commit**

```bash
git add lib/shared/providers/curriculum_progress_provider.dart
git commit -m "feat(student): curriculumProgressProvider composing student + catalog (al_rasikhoon-4gw)"
```

---

### Task 3: `ProgressHeroCard` widget

**Files:**
- Create: `lib/features/student/widgets/progress_hero_card.dart`
- Test: `test/widget/progress_hero_card_test.dart`

**Interfaces:**
- Consumes: `AppCard`, `CircularProgress` (`lib/shared/widgets/progress_bar.dart`), `context.tokens`.
- Produces: `class ProgressHeroCard extends StatelessWidget` with a const constructor taking `{required int percent, required double fraction, required int juzMemorized, required int currentJuz, required int currentLevel, required int streakDays, required int passedSessions}`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/progress_hero_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/widgets/progress_hero_card.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: ProgressHeroCard(
            percent: 27,
            fraction: 0.27,
            juzMemorized: 8,
            currentJuz: 22,
            currentLevel: 4,
            streakDays: 12,
            passedSessions: 36,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProgressHeroCard', () {
    testWidgets('shows the curriculum percent in the ring', (tester) async {
      await _pump(tester);
      expect(find.textContaining('27%'), findsOneWidget);
      expect(find.textContaining('من المنهج'), findsOneWidget);
    });

    testWidgets('shows juz memorized and the current juz in the caption', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.textContaining('حفظت 8 من 30'), findsOneWidget);
      expect(find.textContaining('الجزء 22'), findsOneWidget);
    });

    testWidgets('shows the three supporting stats: level, streak, passed', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('4'), findsWidgets); // level
      expect(find.text('12'), findsWidgets); // streak days
      expect(find.text('36'), findsWidgets); // passed sessions
      expect(find.textContaining('المستوى'), findsOneWidget);
      expect(find.textContaining('متتالية'), findsOneWidget);
      expect(find.textContaining('ناجحة'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/progress_hero_card_test.dart`
Expected: FAIL — `progress_hero_card.dart` / `ProgressHeroCard` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/student/widgets/progress_hero_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_bar.dart';

/// The dashboard's progress hero: a curriculum-percent ring headline, a
/// juz-memorized caption, and three supporting stats (level · streak · passed).
///
/// Every number is passed in already derived — the ring's [fraction] and
/// [percent] come from [CurriculumProgress], [juzMemorized]/[currentJuz] name
/// the milestone and where the student is now. This widget renders; it never
/// computes progress.
class ProgressHeroCard extends StatelessWidget {
  final int percent;
  final double fraction;
  final int juzMemorized;
  final int currentJuz;
  final int currentLevel;
  final int streakDays;
  final int passedSessions;

  const ProgressHeroCard({
    super.key,
    required this.percent,
    required this.fraction,
    required this.juzMemorized,
    required this.currentJuz,
    required this.currentLevel,
    required this.streakDays,
    required this.passedSessions,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppCard(
      margin: EdgeInsets.zero,
      backgroundColor: tokens.green.withValues(alpha: 0.05),
      child: Column(
        children: [
          CircularProgress(
            progress: fraction,
            size: 132,
            strokeWidth: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tokens.green,
                  ),
                ),
                Text(
                  'من المنهج',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'حفظت $juzMemorized من 30 جزءاً · تتقدّم في الجزء $currentJuz',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '$currentLevel',
                  label: 'المستوى',
                  color: tokens.green,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '$streakDays',
                  label: 'يوماً متتالية',
                  color: tokens.maroon,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '$passedSessions',
                  label: 'حلقة ناجحة',
                  color: tokens.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HeroStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: tokens.sepia),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/progress_hero_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/student/widgets/progress_hero_card.dart test/widget/progress_hero_card_test.dart
git commit -m "feat(student): ProgressHeroCard for the redesigned dashboard (al_rasikhoon-4gw)"
```

---

### Task 4: `HomePracticeCard` (merged)

**Files:**
- Create: `lib/features/student/widgets/home_practice_card.dart`
- Test: `test/widget/home_practice_card_test.dart`

**Interfaces:**
- Consumes: `homeAssignmentProvider` (`FutureProvider<HomeAssignment?>`) and `homePracticeStatsProvider` (`FutureProvider<HomePracticeStats>`), both in `lib/features/student/providers/student_provider.dart`; `HomeAssignment` (`curriculumSessionId`, `repetitionsRequired`, `repetitionsDone`, `isComplete`) and `HomePracticeStats` (`todayRepetitions`, `streakDays`, `totalRepetitions`) from the same file. `AppCard`, `ProgressBar`, `AppRoutes.homePractice` (`lib/routing/app_router.dart`), `context.tokens`.
- Produces: `class HomePracticeCard extends ConsumerWidget` with a const constructor `const HomePracticeCard({super.key})`.

This merges the old `HomeAssignmentCard` usage and `_buildHomePracticeCard` into one card: when an assignment is active it shows the assignment progress plus a today/streak caption; when there is none it shows the today/streak/total counters only.

- [ ] **Step 1: Write the failing test**

Create `test/widget/home_practice_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/widgets/home_practice_card.dart';

Future<void> _pump(
  WidgetTester tester, {
  required HomeAssignment? assignment,
  required HomePracticeStats stats,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeAssignmentProvider.overrideWith((ref) async => assignment),
        homePracticeStatsProvider.overrideWith((ref) async => stats),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: HomePracticeCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('HomePracticeCard', () {
    testWidgets('with an active assignment shows progress and the streak caption', (
      tester,
    ) async {
      await _pump(
        tester,
        assignment: const HomeAssignment(
          curriculumSessionId: 'L1_J30_S1',
          repetitionsRequired: 10,
          repetitionsDone: 7,
        ),
        stats: const HomePracticeStats(
          todayRepetitions: 3,
          streakDays: 12,
          totalRepetitions: 50,
        ),
      );
      expect(find.textContaining('التكرار في المنزل'), findsOneWidget);
      expect(find.textContaining('7 / 10'), findsOneWidget);
      expect(find.byType(ProgressBar), findsOneWidget);
      expect(find.textContaining('اليوم 3'), findsOneWidget);
      expect(find.textContaining('متتالية 12'), findsOneWidget);
    });

    testWidgets('with no assignment shows the counters and no progress bar', (
      tester,
    ) async {
      await _pump(
        tester,
        assignment: null,
        stats: const HomePracticeStats(
          todayRepetitions: 3,
          streakDays: 12,
          totalRepetitions: 50,
        ),
      );
      expect(find.textContaining('التكرار في المنزل'), findsOneWidget);
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.textContaining('اليوم 3'), findsOneWidget);
      expect(find.textContaining('متتالية 12'), findsOneWidget);
      expect(find.textContaining('الإجمالي 50'), findsOneWidget);
    });
  });
}
```

Note: this test imports `ProgressBar` transitively via `home_practice_card.dart`; if the analyzer flags `ProgressBar` as undefined in the test, add `import 'package:al_rasikhoon/shared/widgets/progress_bar.dart';` to the test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/home_practice_card_test.dart`
Expected: FAIL — `home_practice_card.dart` / `HomePracticeCard` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/student/widgets/home_practice_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/states/loading_state.dart';
import '../providers/student_provider.dart';

/// The student's home repetition, as one card. When the last session assigned
/// repetitions, the card shows that assignment's progress with a today/streak
/// caption; otherwise it shows the today/streak/total counters alone. This
/// replaces the two near-identical cards the dashboard used to stack.
class HomePracticeCard extends ConsumerWidget {
  const HomePracticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final assignmentAsync = ref.watch(homeAssignmentProvider);
    final statsAsync = ref.watch(homePracticeStatsProvider);

    return statsAsync.when(
      loading: () => const LoadingState(lines: 1),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final assignment = assignmentAsync.asData?.value;

        return AppCard(
          margin: EdgeInsets.zero,
          onTap: () => context.push(AppRoutes.homePractice),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'التكرار في المنزل',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (assignment != null)
                    Text(
                      // Capped at the target so an over-practising student sees
                      // '10 / 10', matching the bar, not an off '12 / 10'.
                      '${assignment.repetitionsDone.clamp(0, assignment.repetitionsRequired)}'
                      ' / ${assignment.repetitionsRequired}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: assignment.isComplete
                            ? tokens.green
                            : tokens.gold,
                      ),
                    ),
                ],
              ),
              if (assignment != null) ...[
                const SizedBox(height: 12),
                ProgressBar(
                  progress:
                      assignment.repetitionsDone / assignment.repetitionsRequired,
                  height: 8,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'اليوم ${stats.todayRepetitions} · متتالية ${stats.streakDays} يوماً'
                ' · الإجمالي ${stats.totalRepetitions}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.homePractice),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('سجّل تكراراً'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/home_practice_card_test.dart`
Expected: PASS (2 tests). If `find.textContaining('اليوم 3')` fails because the caption splits across widgets, confirm the caption is a single `Text` as written above — it is one string, so one `Text`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/student/widgets/home_practice_card.dart test/widget/home_practice_card_test.dart
git commit -m "feat(student): merged HomePracticeCard for the dashboard (al_rasikhoon-4gw)"
```

---

### Task 5: Re-assemble `StudentDashboardScreen`

**Files:**
- Modify: `lib/features/student/screens/student_dashboard_screen.dart`

**Interfaces:**
- Consumes: `curriculumProgressProvider` (Task 2), `ProgressHeroCard` (Task 3), `HomePracticeCard` (Task 4), plus existing `studentStatsProvider`, `homePracticeStatsProvider`, `studentDashboardMeetingProvider`, `currentStudentProvider`, `currentUserProvider`, `LevelProgressionWidget`.
- Produces: the redesigned screen. No new public API.

The current-session card logic (`_buildCurrentSessionCard`, talqeen/exam/sard/lesson branches) is preserved verbatim — juz stays there as its single home. This task changes the `build` method's `Column` children and deletes the now-dead builders.

- [ ] **Step 1: Update imports**

In `lib/features/student/screens/student_dashboard_screen.dart`, replace the widget imports block. Remove:
```dart
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/student_level_progress.dart';
import '../widgets/home_assignment_card.dart';
```
Add:
```dart
import '../../../shared/providers/curriculum_progress_provider.dart';
import '../widgets/home_practice_card.dart';
import '../widgets/progress_hero_card.dart';
```
Keep: `app_tokens.dart`, `user_model.dart`, `paced_session.dart`, `app_router.dart`, `assessment_copy.dart`, `current_student_provider.dart`, `stats_provider.dart`, `user_provider.dart`, `app_card.dart`, `states/error_state.dart`, `states/loading_state.dart`, `level_progression_widget.dart`, `student_provider.dart`.

- [ ] **Step 2: Replace the `build` body's Column children**

In `build`, add `final progressAsync = ref.watch(curriculumProgressProvider);` alongside the existing `statsAsync` / `meetingAsync` watches. Replace the `Column`'s `children` (currently the welcome block through quick stats) with:

```dart
children: [
  if (currentUser?.role == UserRole.guardian) const _GuardianChildSwitcher(),

  Text(
    'مرحباً، ${currentUser?.name ?? 'الطالب'}',
    style: Theme.of(context).textTheme.headlineSmall,
  ),
  const SizedBox(height: 24),

  // Progress hero — the screen's headline. Needs curriculum progress, the
  // student's position (level/juz/passed), and the streak; renders only
  // when all three have resolved, else a single loading block.
  statsAsync.when(
    data: (stats) => progressAsync.when(
      data: (progress) {
        final practice = ref.watch(homePracticeStatsProvider).asData?.value;
        return ProgressHeroCard(
          percent: progress.percent,
          fraction: progress.fraction,
          juzMemorized: progress.juzMemorized,
          currentJuz: stats.currentJuz,
          currentLevel: stats.currentLevel,
          streakDays: practice?.streakDays ?? 0,
          passedSessions: stats.passedSessions,
        );
      },
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(message: 'تعذر تحميل التقدم: $e'),
    ),
    loading: () => const LoadingState(),
    error: (e, _) => ErrorState(message: 'تعذر تحميل التقدم: $e'),
  ),

  const SizedBox(height: 24),

  // Current session — juz lives here, and only here.
  Text('الحلقة الحالية', style: Theme.of(context).textTheme.titleMedium),
  const SizedBox(height: 12),
  meetingAsync.when(
    data: (meeting) => _buildCurrentSessionCard(meeting),
    loading: () => const LoadingState(),
    error: (e, _) => ErrorState(message: 'تعذر تحميل الحلقة: $e'),
  ),

  const SizedBox(height: 24),

  // Home practice — one merged card.
  const HomePracticeCard(),

  const SizedBox(height: 24),

  // Level journey — collapsed by default; the only home of completed-levels.
  statsAsync.when(
    data: (stats) => _buildJourneyExpander(stats),
    loading: () => const SizedBox(),
    error: (_, _) => const SizedBox(),
  ),

  const SizedBox(height: 12),

  // Full stats — collapsed by default; no 'المستويات' tile (it lives in the
  // hero chip and the journey row above).
  statsAsync.when(
    data: (stats) => _buildStatsExpander(stats),
    loading: () => const SizedBox(),
    error: (_, _) => const SizedBox(),
  ),
],
```

Also update the `RefreshIndicator.onRefresh` to invalidate and await the new provider: after `ref.invalidate(homePracticeStatsProvider);` add `ref.invalidate(curriculumProgressProvider);`, and add `ref.read(curriculumProgressProvider.future),` to the `Future.wait([...])` list.

- [ ] **Step 3: Add the two expander builders; delete the dead builders**

Add these two methods to `_StudentDashboardScreenState` (place them where `_buildProgressCard` / `_buildHomePracticeCard` / `_buildQuickStats` were):

```dart
/// The level journey, collapsed. Its header carries the completed count; the
/// body is the full ten-tile grid. This is the single place completed-levels
/// is shown on the dashboard.
Widget _buildJourneyExpander(StudentStats stats) {
  final tokens = context.tokens;
  return AppCard(
    margin: EdgeInsets.zero,
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'رحلة المستويات',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Text(
          '${stats.completedLevels}/10 مكتمل',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
        ),
        children: [
          LevelProgressionWidget(
            currentLevel: stats.currentLevel,
            unlockedLevels: stats.unlockedLevelsList,
            completedLevels: stats.completedLevelsList,
          ),
        ],
      ),
    ),
  );
}

/// The full stat set, collapsed. No 'المستويات' tile — that figure lives in
/// the hero chip and the journey header.
Widget _buildStatsExpander(StudentStats stats) {
  final tokens = context.tokens;
  return AppCard(
    margin: EdgeInsets.zero,
    padding: EdgeInsets.zero,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          'إحصائياتي',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'الحلقات',
                  value: '${stats.totalSessions}',
                  color: tokens.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'الناجحة',
                  value: '${stats.passedSessions}',
                  color: tokens.green,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

Add this small private widget (replaces the removed `StatCardCompact` usage and the removed `_PracticeStatItem`):

```dart
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
        ],
      ),
    );
  }
}
```

Delete these now-dead members from the file: `_buildProgressCard`, `_buildHomePracticeCard`, `_buildQuickStats`, and the `_PracticeStatItem` class. Keep `_buildCurrentSessionCard`, `_ContentRow`, and `_GuardianChildSwitcher` unchanged.

- [ ] **Step 4: Analyze — no errors, no unused imports/members**

Run: `flutter analyze lib/features/student/screens/student_dashboard_screen.dart`
Expected: "No issues found!" Fix any unused-import or undefined-symbol reports by removing the offending import or correcting the reference. In particular confirm `stat_card.dart`, `student_level_progress.dart`, and `home_assignment_card.dart` imports are gone and nothing else in the file referenced them.

- [ ] **Step 5: Structural de-duplication check**

Run: `grep -n "completedLevels\|currentJuz\|stats.currentJuz\|HomeAssignmentCard\|StudentLevelProgress" lib/features/student/screens/student_dashboard_screen.dart`
Expected: `completedLevels` appears only inside `_buildJourneyExpander`; `currentJuz` appears only in the `ProgressHeroCard` wiring (the hero caption) and inside `_buildCurrentSessionCard`; `HomeAssignmentCard` and `StudentLevelProgress` do not appear at all. If any figure appears in a second place, remove the duplicate.

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS — all existing tests plus the three new test files. If a pre-existing dashboard widget test referenced a removed builder or the old layout, update it to the new structure (search `test/` for `student_dashboard`).

- [ ] **Step 7: Commit**

```bash
git add lib/features/student/screens/student_dashboard_screen.dart test/
git commit -m "feat(student): redesign dashboard — progress hero, merged practice, collapsed journey (al_rasikhoon-4gw)"
```

---

### Task 6: Final verification, issue close, and push

**Files:** none (verification + housekeeping).

- [ ] **Step 1: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!" Fix anything reported before proceeding.

- [ ] **Step 2: Run the whole test suite**

Run: `flutter test`
Expected: All tests pass. Capture the summary line (e.g. "All tests passed!").

- [ ] **Step 3: Verify the running screen (if the app can be launched here)**

If a Flutter run target is available (`flutter run -d chrome` or an emulator with Firebase configured), launch it, sign in as a student, and confirm: the hero ring shows a percent, the juz caption reads "حفظت N من 30 جزءاً", the current session card shows the juz, the merged home-practice card renders, and the journey / stats sections expand. If the app cannot be launched in this environment (no Firebase config / no device), record that here and rely on `flutter analyze` + `flutter test` as the verification of record — do NOT claim runtime verification that wasn't performed.

- [ ] **Step 4: Close the beads issue**

```bash
bd close al_rasikhoon-4gw
```

- [ ] **Step 5: Push**

```bash
git pull --rebase
bd dolt push
git push
git status  # MUST show "up to date with origin"
```

---

## Self-Review

**Spec coverage:**
- Greeting without subtitle → Task 5 Step 2. ✓
- Progress hero (ring percent + juz caption + 3 chips) → Task 3 + Task 5 wiring. ✓
- Current session, juz only here → Task 5 (preserved `_buildCurrentSessionCard`; imports/grep confirm single juz home). ✓
- Merged home-practice card, both branches → Task 4. ✓
- Level journey collapsed, single completed-levels home → Task 5 `_buildJourneyExpander`. ✓
- Stats collapsed, no المستويات tile → Task 5 `_buildStatsExpander`. ✓
- De-duplication scorecard → Task 5 Step 5 structural check. ✓
- Honest juz-memorized derivation (position-based, level-10 ascending, flexible enrollment, graduated, empty catalog) → Task 1 domain service + its 9 tests. ✓
- Derivation in domain/app layer, not widget → Task 1 (domain) + Task 2 (provider); widgets take derived values. ✓
- Loading/error/empty states → Task 4 (stats `.when`, assignment-absent branch) + Task 5 (`.when` per section) + Task 1 (empty catalog → zero). ✓
- Manuscript tokens, RTL → Global Constraints + every widget uses `context.tokens`. ✓

**Placeholder scan:** No TBD/TODO; every code step carries full code; every command has an expected result. ✓

**Type consistency:** `CurriculumProgress` fields/getters (`sessionsCompleted`, `totalSessions`, `juzMemorized`, `fraction`, `percent`) are identical across Tasks 1, 2, 5. `ProgressHeroCard` constructor params match the Task 5 wiring exactly. `HomePracticeCard` is a no-arg `const` widget in Tasks 4 and 5. `curriculumProgressProvider` type `FutureProvider<CurriculumProgress>` consistent across Tasks 2 and 5. ✓
