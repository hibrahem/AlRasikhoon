# Session Detail Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enrich the student session-detail screen (`تفاصيل الحلقة`) with per-part ayah ranges, session duration, pace, and clearly-labeled repetition counts, in a cleaner stat-chip layout.

**Architecture:** Presentation-only change. A new pure Arabic duration formatter goes in the domain layer (`SessionDuration`). The screen (`session_detail_screen.dart`) is reworked to (a) move the attempt/repetition rows out of the header into a chip grid that also shows pace, duration and the home-repetitions field, and (b) render each part's Qur'an range from the already-fetched curriculum `SessionModel`. No models, repositories, providers, or Firestore schema change.

**Tech Stack:** Flutter, Riverpod, Dart. Tests: `flutter_test` widget tests + Dart unit tests.

## Global Constraints

- DDD/Clean Architecture: the duration formatter is pure Dart in the domain layer (no `BuildContext`, no Flutter import). View wording/logic stays in the screen file.
- **Digits are Western** (e.g. `7 د 12 ث`, `3`) to match the existing `${record.attemptNumber}` and `N أخطاء` displays. Dates keep the intl `ar` locale (Arabic-Indic) — unchanged.
- RTL screen; reuse `context.tokens` (`surfaceVariant`, `sepia`, `green`, `maroon`) and `AppCard`.
- Binary pass/fail logic (`grades.passesForLevel`) and the تلقين special-casing are unchanged.
- Every task ends green: run the named tests and the full `flutter test` before committing.

---

### Task 1: Arabic words duration formatter

**Files:**
- Modify: `lib/domain/session/session_duration.dart` (add a static method to `SessionDuration`)
- Test: `test/unit/domain/session/session_duration_test.dart` (append a group)

**Interfaces:**
- Produces: `static String SessionDuration.formatWordsAr(Duration d)` — returns `'$s ث'` under a minute, `'$m د'` when seconds are zero, otherwise `'$m د $s ث'`. Western digits. Used by Task 2.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/domain/session/session_duration_test.dart`, inside `void main() { ... }`:

```dart
  group('formatWordsAr', () {
    test('minutes and seconds', () {
      expect(
        SessionDuration.formatWordsAr(const Duration(minutes: 7, seconds: 12)),
        '7 د 12 ث',
      );
    });

    test('whole minutes omit the seconds segment', () {
      expect(
        SessionDuration.formatWordsAr(const Duration(minutes: 7)),
        '7 د',
      );
    });

    test('under a minute shows seconds only', () {
      expect(
        SessionDuration.formatWordsAr(const Duration(seconds: 45)),
        '45 ث',
      );
    });

    test('exactly one minute omits seconds', () {
      expect(
        SessionDuration.formatWordsAr(const Duration(minutes: 1)),
        '1 د',
      );
    });

    test('zero renders as 0 ث', () {
      expect(SessionDuration.formatWordsAr(Duration.zero), '0 ث');
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/domain/session/session_duration_test.dart`
Expected: FAIL — `formatWordsAr` is not defined on `SessionDuration`.

- [ ] **Step 3: Add the formatter**

In `lib/domain/session/session_duration.dart`, add this static method to the `SessionDuration` class (next to the existing `formatClock`):

```dart
  /// The measured length in Arabic unit words with Western digits, e.g.
  /// `7 د 12 ث`. Under a minute shows seconds only (`45 ث`); a whole number of
  /// minutes omits the seconds segment (`7 د`). This is the reader-facing
  /// length format on the student's session-detail screen, distinct from the
  /// stopwatch-style [formatClock] the teacher sees.
  static String formatWordsAr(Duration d) {
    final totalSeconds = d.inSeconds;
    if (totalSeconds < 60) return '$totalSeconds ث';
    final minutes = d.inMinutes;
    final seconds = totalSeconds % 60;
    if (seconds == 0) return '$minutes د';
    return '$minutes د $seconds ث';
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/domain/session/session_duration_test.dart`
Expected: PASS (all groups green).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/session/session_duration.dart test/unit/domain/session/session_duration_test.dart
git commit -m "feat(session): add Arabic words duration formatter"
```

---

### Task 2: Stat-chip grid (attempt, pace, duration, both repetitions)

Replace the two in-header `_InfoRow`s with a chip grid below the header. Adds pace (`المقدار`), duration (`المدة`), and the home-repetitions field (`التكرار المطلوب في البيت`); relabels attempt to `رقم المحاولة` and the with-teacher count to `التكرار مع المعلم`. The attempt chip is omitted for a تلقين.

**Files:**
- Modify: `lib/features/student/screens/session_detail_screen.dart`
- Test: `test/widget/session_detail_stat_chips_test.dart` (create)

**Interfaces:**
- Consumes: `SessionDuration.formatWordsAr` (Task 1).
- Produces: private `_StatChip` widget and private `String? _paceAmountAr(int pace)` helper, used within this file.

- [ ] **Step 1: Write the failing test**

Create `test/widget/session_detail_stat_chips_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  Future<void> pump(WidgetTester tester, SessionRecordModel record) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            record.id,
          ).overrideWith((ref) async => record),
          curriculumSessionByIdProvider(
            record.curriculumSessionId,
          ).overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionDetailScreen(recordId: record.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SessionRecordModel record({
    int attemptNumber = 1,
    int paceAtTime = 1,
    Duration? duration,
    int repetitionsWithTeacher = 0,
    int homeRepetitionsRequired = 0,
    SessionKind kind = SessionKind.lesson,
  }) {
    return SessionRecordModel(
      id: 'r1',
      studentId: 'student1',
      teacherId: 'teacher1',
      curriculumSessionId: 'L1_J30_S5',
      levelId: 1,
      kind: kind,
      juzNumber: 30,
      sessionNumber: 5,
      fromOrderInLevel: 5,
      toOrderInLevel: 5,
      coversSessionIds: const ['L1_J30_S5'],
      paceAtTime: paceAtTime,
      date: DateTime(2026, 7, 14),
      attemptNumber: attemptNumber,
      grades: const SessionGrades(
        newMemorizationErrors: 0,
        recentReviewErrors: 0,
        distantReviewErrors: 0,
      ),
      passed: true,
      repetitionsWithTeacher: repetitionsWithTeacher,
      homeRepetitionsRequired: homeRepetitionsRequired,
      createdAt: DateTime(2026, 7, 14),
      duration: duration,
    );
  }

  testWidgets('attempt chip is relabeled رقم المحاولة', (tester) async {
    await pump(tester, record(attemptNumber: 2));
    expect(find.text('رقم المحاولة'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('pace chip is hidden at 1x', (tester) async {
    await pump(tester, record(paceAtTime: 1));
    expect(find.text('المقدار'), findsNothing);
  });

  testWidgets('pace chip reads ضعف الكمّ at 2x', (tester) async {
    await pump(tester, record(paceAtTime: 2));
    expect(find.text('المقدار'), findsOneWidget);
    expect(find.text('ضعف الكمّ'), findsOneWidget);
  });

  testWidgets('pace chip reads ثلاثة أضعاف at 3x', (tester) async {
    await pump(tester, record(paceAtTime: 3));
    expect(find.text('ثلاثة أضعاف'), findsOneWidget);
  });

  testWidgets('duration chip hidden when null, shown formatted otherwise', (
    tester,
  ) async {
    await pump(tester, record(duration: null));
    expect(find.text('المدة'), findsNothing);

    await pump(tester, record(duration: const Duration(minutes: 7, seconds: 12)));
    expect(find.text('المدة'), findsOneWidget);
    expect(find.text('7 د 12 ث'), findsOneWidget);
  });

  testWidgets('both repetition counts are shown with clear labels', (
    tester,
  ) async {
    await pump(
      tester,
      record(repetitionsWithTeacher: 3, homeRepetitionsRequired: 5),
    );
    expect(find.text('التكرار مع المعلم'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('التكرار المطلوب في البيت'), findsOneWidget);
    expect(find.text('5 مرات'), findsOneWidget);
  });

  testWidgets('repetition chips hidden when zero', (tester) async {
    await pump(tester, record());
    expect(find.text('التكرار مع المعلم'), findsNothing);
    expect(find.text('التكرار المطلوب في البيت'), findsNothing);
  });

  testWidgets('attempt chip is omitted for a تلقين', (tester) async {
    await pump(tester, record(kind: SessionKind.talqeen));
    expect(find.text('رقم المحاولة'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/session_detail_stat_chips_test.dart`
Expected: FAIL — labels `رقم المحاولة` / `المقدار` / `المدة` / `التكرار مع المعلم` / `التكرار المطلوب في البيت` not found (screen still shows `المحاولة` / `التكرارات`).

- [ ] **Step 3: Add the import and helpers**

In `lib/features/student/screens/session_detail_screen.dart`, add the duration import near the top imports:

```dart
import '../../../domain/session/session_duration.dart';
```

Add this top-level helper next to `_partTitleAr` (below the `SessionDetailScreen` class):

```dart
/// The pace of a meeting stated as an amount of memorization. Null at normal
/// pace (1×) — a normal portion is the default and is not worth a chip; 2× is
/// double the usual amount, 3× is triple.
String? _paceAmountAr(int pace) {
  switch (pace) {
    case 2:
      return 'ضعف الكمّ';
    case 3:
      return 'ثلاثة أضعاف';
    default:
      return null;
  }
}
```

- [ ] **Step 4: Replace the header info rows with the chip grid**

In `build`, the header `AppCard` currently ends with `const SizedBox(height: 16)` followed by the `_InfoRow` attempt/repetition block (the `_InfoRow('المحاولة'…)` and the `if (record.repetitionsWithTeacher > 0) _InfoRow('التكرارات'…)`).

Delete that trailing `SizedBox` and both `_InfoRow`s from inside the `AppCard`'s `Column` so the header card holds only the icon/title/date `Row`.

Then, immediately after the header `AppCard` widget (before the existing `const SizedBox(height: 24)`), insert:

```dart
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    final half = (constraints.maxWidth - spacing) / 2;
                    final pace = _paceAmountAr(record.paceAtTime);
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        if (!record.isTalqeen)
                          _StatChip(
                            width: half,
                            label: 'رقم المحاولة',
                            value: '${record.attemptNumber}',
                          ),
                        if (pace != null)
                          _StatChip(
                            width: half,
                            label: 'المقدار',
                            value: pace,
                          ),
                        if (record.duration != null)
                          _StatChip(
                            width: half,
                            label: 'المدة',
                            value: SessionDuration.formatWordsAr(
                              record.duration!,
                            ),
                          ),
                        if (record.repetitionsWithTeacher > 0)
                          _StatChip(
                            width: half,
                            label: 'التكرار مع المعلم',
                            value: '${record.repetitionsWithTeacher}',
                          ),
                        if (record.homeRepetitionsRequired > 0)
                          _StatChip(
                            width: constraints.maxWidth,
                            label: 'التكرار المطلوب في البيت',
                            value: '${record.homeRepetitionsRequired} مرات',
                          ),
                      ],
                    );
                  },
                ),
```

- [ ] **Step 5: Replace the `_InfoRow` class with `_StatChip`**

Delete the entire `_InfoRow` class (it is now unused) and add in its place:

```dart
class _StatChip extends StatelessWidget {
  final double width;
  final String label;
  final String value;

  const _StatChip({
    required this.width,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/widget/session_detail_stat_chips_test.dart`
Expected: PASS (all cases green).

- [ ] **Step 7: Run the existing detail suite to catch regressions**

Run: `flutter test test/widget/session_detail_overall_result_test.dart test/widget/session_detail_talqeen_test.dart`
Expected: PASS (no test asserted the old `المحاولة`/`التكرارات` labels; the تلقين attempt chip is now gated off).

- [ ] **Step 8: Commit**

```bash
git add lib/features/student/screens/session_detail_screen.dart test/widget/session_detail_stat_chips_test.dart
git commit -m "feat(session-detail): stat-chip grid with pace, duration, and both repetition counts"
```

---

### Task 3: Per-part ayah range

Show each part's Qur'an range under its title, resolved from the curriculum `SessionModel` already fetched for the title. Hidden when that part carries no content.

**Files:**
- Modify: `lib/features/student/screens/session_detail_screen.dart`
- Test: `test/widget/session_detail_part_content_test.dart` (create)

**Interfaces:**
- Consumes: `SessionModel.currentLevelContent` / `recentReviewContent` / `distantReviewContent` and `QuranContent.rangeAr`.
- Produces: private `String _rangeForPart(SessionModel? session, int part)`; `_PartResultCard` gains a required `String range`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/session_detail_part_content_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/features/student/providers/student_provider.dart';
import 'package:al_rasikhoon/features/student/screens/session_detail_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  final recordModel = SessionRecordModel(
    id: 'r1',
    studentId: 'student1',
    teacherId: 'teacher1',
    curriculumSessionId: 'L1_J30_S5',
    levelId: 1,
    kind: SessionKind.lesson,
    juzNumber: 30,
    sessionNumber: 5,
    fromOrderInLevel: 5,
    toOrderInLevel: 5,
    coversSessionIds: const ['L1_J30_S5'],
    date: DateTime(2026, 7, 14),
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    presentParts: const [1, 2],
    passed: true,
    createdAt: DateTime(2026, 7, 14),
  );

  Future<void> pump(WidgetTester tester, SessionModel? session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRecordByIdProvider(
            recordModel.id,
          ).overrideWith((ref) async => recordModel),
          curriculumSessionByIdProvider(
            recordModel.curriculumSessionId,
          ).overrideWith((ref) async => session),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SessionDetailScreen(recordId: recordModel.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SessionModel sessionWith({
    QuranContent? current,
    QuranContent? recent,
  }) {
    return SessionModel(
      id: 'L1_J30_S5',
      levelId: 1,
      juzNumber: 30,
      sessionNumber: 5,
      orderInLevel: 5,
      kind: SessionKind.lesson,
      currentLevelContent: current,
      recentReviewContent: recent,
    );
  }

  testWidgets('shows the ayah range for a part that has content', (
    tester,
  ) async {
    await pump(
      tester,
      sessionWith(
        current: const QuranContent(
          fromSurah: 'الإخلاص',
          fromVerse: 1,
          toSurah: 'الإخلاص',
          toVerse: 4,
        ),
      ),
    );
    expect(find.text('الإخلاص: 1 - 4'), findsOneWidget);
  });

  testWidgets('hides the range line for a part with no content', (
    tester,
  ) async {
    // Part 1 has content, part 2 does not — only one range line appears.
    await pump(
      tester,
      sessionWith(
        current: const QuranContent(
          fromSurah: 'الإخلاص',
          fromVerse: 1,
          toSurah: 'الإخلاص',
          toVerse: 4,
        ),
        recent: null,
      ),
    );
    expect(find.text('الإخلاص: 1 - 4'), findsOneWidget);
    expect(find.textContaining('إلى'), findsNothing);
  });

  testWidgets('renders parts without ranges when the session is unresolved', (
    tester,
  ) async {
    await pump(tester, null);
    expect(find.text('الحفظ الجديد'), findsOneWidget);
    expect(find.text('المراجعة القريبة'), findsOneWidget);
    expect(find.textContaining(':'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/session_detail_part_content_test.dart`
Expected: FAIL — `find.text('الإخلاص: 1 - 4')` finds nothing (range not rendered yet).

- [ ] **Step 3: Add the part→content range helper**

In `lib/features/student/screens/session_detail_screen.dart`, add this top-level helper next to `_partTitleAr`:

```dart
/// The Qur'an range recited for a part, from the curriculum session's content
/// blocks: 1 = new memorization, 2 = recent review, 3 = distant review.
/// Empty when the session is unresolved or that part carries no content.
String _rangeForPart(SessionModel? session, int part) {
  if (session == null) return '';
  final content = switch (part) {
    1 => session.currentLevelContent,
    2 => session.recentReviewContent,
    3 => session.distantReviewContent,
    _ => null,
  };
  return content?.rangeAr ?? '';
}
```

`SessionModel` and `QuranContent` come from `session_model.dart`; add the import if it is not already present:

```dart
import '../../../data/models/session_model.dart';
```

- [ ] **Step 4: Pass the range into each part card**

In `build`, the loop over `record.presentParts` constructs `_PartResultCard`. Add the `range` argument:

```dart
                    _PartResultCard(
                      title: _partTitleAr(part),
                      errors: record.grades.errorsForPart(part),
                      level: record.levelId,
                      range: _rangeForPart(session, part),
                    ),
```

- [ ] **Step 5: Render the range in `_PartResultCard`**

In the `_PartResultCard` class, add the field and constructor param:

```dart
class _PartResultCard extends StatelessWidget {
  final String title;
  final int errors;
  final int level;
  final String range;

  const _PartResultCard({
    required this.title,
    required this.errors,
    required this.level,
    required this.range,
  });
```

Then replace the middle `Expanded(child: Text(title, …))` with a title-plus-range column:

```dart
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                if (range.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    range,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.sepia),
                  ),
                ],
              ],
            ),
          ),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/widget/session_detail_part_content_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS (whole suite green).

- [ ] **Step 8: Commit**

```bash
git add lib/features/student/screens/session_detail_screen.dart test/widget/session_detail_part_content_test.dart
git commit -m "feat(session-detail): show per-part ayah range from curriculum content"
```

---

## Final verification

- [ ] Run `flutter analyze` — expect no new warnings (unused `_InfoRow` removed, all imports used).
- [ ] Run `flutter test` — expect the full suite green.

## Self-Review notes

- **Spec coverage:** ayah range (Task 3), duration (Task 1+2), split repetitions (Task 2), pace `المقدار` hidden at 1× (Task 2), attempt relabel + تلقين gating (Task 2), comment unchanged (untouched), no kind badge (header untouched — the current header has none). All covered.
- **Placeholders:** none — every step carries full code.
- **Type consistency:** `formatWordsAr` defined in Task 1, consumed in Task 2; `_paceAmountAr` returns `String?`; `_rangeForPart` returns `String`; `_PartResultCard.range` is `String` used in Task 3. Consistent.
