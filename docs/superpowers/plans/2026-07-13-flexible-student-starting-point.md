# Flexible Student Starting Point — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a teacher or supervisor admit a student at any point in the curriculum (Level → Hizb → Session), crediting everything before that point as already memorized — and fix the curriculum traversal order this depends on.

**Architecture:** A new framework-free `lib/domain/curriculum/` module owns curriculum arithmetic (`CurriculumOrder`) and an immutable `CurriculumPosition` value object. `StudentRepository` stops doing curriculum math itself: advancement walks the real, sparse session data through `CurriculumRepository`, and `StudentModel` gains an immutable enrollment anchor from which prior credit is derived. The UI adds a cascading picker to the existing shared `AddStudentScreen`.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore. Tests: `flutter_test`, `mocktail`, `fake_cloud_firestore`, `integration_test`.

**Spec:** `docs/superpowers/specs/2026-07-13-flexible-student-starting-point-design.md`

## Global Constraints

- **Curriculum order (authoritative):** levels ascend 1–10; within a level juz **descend**; within a juz hizbs **ascend** (juz *j* = hizb `2j−1`, then `2j`). Level 1 runs **59, 60, 57, 58, 55, 56**; level 2 runs 53, 54, 51, 52, 49, 50; level 10 runs 5, 6, 3, 4, 1, 2.
- **Derived formulas:** `juzOfHizb(h) = (h + 1) ~/ 2`; `juzOfLevel(L) = [33−3L, 32−3L, 31−3L]`; `firstHizbOfLevel(L) = 65 − 6L`; `lastHizbOfLevel(L) = 62 − 6L`; `levelOfHizb(h) = ((60 − h) ~/ 6) + 1`; `nextHizb(h) = h + 1` if *h* is odd, `h − 3` if *h* is even, and `null` when `h == 2` (end of curriculum).
- **Sessions are sparse.** A hizb's session numbers are a subset of 1–36 (e.g. level 2 / hizb 49 has 18 sessions scattered over 2–36). Never assume `session + 1` exists. 35 = Sard, 36 = Exam.
- **Data anomalies are tolerated, not fixed:** ignore session documents whose `session_number <= 0`, and those whose `juz_number != juzOfHizb(hizb_number)` (this drops the stray `L1_J29_H59` pair). Unknown `session_type` values already fall back to `regular` via `SessionTypeExtension.fromString`.
- **No migration.** There is no production student progress; do not write migration code.
- **Default start is unchanged:** level 1, juz 30, hizb 59, session 1.
- **Domain purity (CLAUDE.md):** files under `lib/domain/` must not import Flutter, Firebase, or Riverpod.
- **All user-facing strings are Arabic**, matching the existing screens.
- Run `flutter analyze` before each commit; it must report no new issues.

---

### Task 1: `CurriculumOrder` — the curriculum arithmetic

The level/juz/hizb rules currently live as two private helpers inside `StudentRepository` (`_getFirstHizbOfLevel`, `_getFirstJuzOfLevel`) and are wrong. This task creates the correct, framework-free home for them. Nothing consumes it yet.

**Files:**
- Create: `lib/domain/curriculum/curriculum_order.dart`
- Test: `test/unit/domain/curriculum/curriculum_order_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class CurriculumOrder` with static members — `int juzOfHizb(int hizb)`, `List<int> hizbsOfJuz(int juz)`, `List<int> juzOfLevel(int level)`, `List<int> hizbsOfLevel(int level)`, `int firstHizbOfLevel(int level)`, `int lastHizbOfLevel(int level)`, `int levelOfHizb(int hizb)`, `int? nextHizb(int hizb)`, `int hizbOrderIndex(int hizb)`, `const int totalLevels = 10`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/curriculum_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_order.dart';

void main() {
  group('CurriculumOrder', () {
    test('a juz is its odd hizb then its even hizb', () {
      expect(CurriculumOrder.hizbsOfJuz(30), [59, 60]);
      expect(CurriculumOrder.hizbsOfJuz(1), [1, 2]);
      expect(CurriculumOrder.juzOfHizb(59), 30);
      expect(CurriculumOrder.juzOfHizb(60), 30);
      expect(CurriculumOrder.juzOfHizb(55), 28);
      expect(CurriculumOrder.juzOfHizb(1), 1);
    });

    test('a level owns three descending juz', () {
      expect(CurriculumOrder.juzOfLevel(1), [30, 29, 28]);
      expect(CurriculumOrder.juzOfLevel(2), [27, 26, 25]);
      expect(CurriculumOrder.juzOfLevel(10), [3, 2, 1]);
    });

    test('level one is taught as hizb 59, 60, 57, 58, 55, 56', () {
      expect(CurriculumOrder.hizbsOfLevel(1), [59, 60, 57, 58, 55, 56]);
      expect(CurriculumOrder.hizbsOfLevel(2), [53, 54, 51, 52, 49, 50]);
      expect(CurriculumOrder.hizbsOfLevel(10), [5, 6, 3, 4, 1, 2]);
    });

    test('a level begins at its first hizb and ends at its last', () {
      expect(CurriculumOrder.firstHizbOfLevel(1), 59);
      expect(CurriculumOrder.lastHizbOfLevel(1), 56);
      expect(CurriculumOrder.firstHizbOfLevel(2), 53);
      expect(CurriculumOrder.lastHizbOfLevel(10), 2);
    });

    test('every hizb belongs to exactly one level', () {
      expect(CurriculumOrder.levelOfHizb(60), 1);
      expect(CurriculumOrder.levelOfHizb(55), 1);
      expect(CurriculumOrder.levelOfHizb(54), 2);
      expect(CurriculumOrder.levelOfHizb(49), 2);
      expect(CurriculumOrder.levelOfHizb(1), 10);
    });

    test('advancing walks a level in teaching order then enters the next level', () {
      expect(CurriculumOrder.nextHizb(59), 60);
      expect(CurriculumOrder.nextHizb(60), 57);
      expect(CurriculumOrder.nextHizb(58), 55);
      expect(CurriculumOrder.nextHizb(55), 56);
      // Leaving the last hizb of level 1 enters the first hizb of level 2.
      expect(CurriculumOrder.nextHizb(56), 53);
      expect(CurriculumOrder.levelOfHizb(53), 2);
    });

    test('the curriculum ends after the last hizb of level ten', () {
      expect(CurriculumOrder.nextHizb(1), 2);
      expect(CurriculumOrder.nextHizb(2), isNull);
    });

    test('walking nextHizb from the start visits all sixty hizbs in order', () {
      final visited = <int>[];
      int? hizb = CurriculumOrder.firstHizbOfLevel(1);
      while (hizb != null) {
        visited.add(hizb);
        hizb = CurriculumOrder.nextHizb(hizb);
      }

      expect(visited.length, 60);
      expect(visited.toSet().length, 60);
      expect(visited.take(6), [59, 60, 57, 58, 55, 56]);
      expect(visited.last, 2);
    });

    test('order index increases monotonically along the teaching order', () {
      expect(
        CurriculumOrder.hizbOrderIndex(59) < CurriculumOrder.hizbOrderIndex(60),
        isTrue,
      );
      expect(
        CurriculumOrder.hizbOrderIndex(60) < CurriculumOrder.hizbOrderIndex(57),
        isTrue,
      );
      expect(
        CurriculumOrder.hizbOrderIndex(56) < CurriculumOrder.hizbOrderIndex(53),
        isTrue,
      );
      expect(CurriculumOrder.hizbOrderIndex(59), 0);
      expect(CurriculumOrder.hizbOrderIndex(2), 59);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/curriculum_order_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'al_rasikhoon/domain/curriculum/curriculum_order.dart'` (the file does not exist).

- [ ] **Step 3: Write the implementation**

Create `lib/domain/curriculum/curriculum_order.dart`:

```dart
/// Curriculum arithmetic for منهج الراسخون — pure domain, no framework imports.
///
/// The curriculum is 10 levels. Level L owns three juz, descending, and the six
/// hizbs of those juz. Within a juz the hizbs ascend: juz j is hizb 2j-1, then
/// hizb 2j. Level 1 is therefore taught as 59, 60, 57, 58, 55, 56 — a student
/// begins at juz 30, hizb 59, and the juz descend as they advance.
class CurriculumOrder {
  CurriculumOrder._();

  static const int totalLevels = 10;
  static const int hizbsPerLevel = 6;

  /// The juz a hizb belongs to. Juz j spans hizbs 2j-1 and 2j.
  static int juzOfHizb(int hizb) => (hizb + 1) ~/ 2;

  /// The two hizbs of a juz, in teaching order.
  static List<int> hizbsOfJuz(int juz) => [juz * 2 - 1, juz * 2];

  /// The three juz of a level, in teaching order (descending).
  static List<int> juzOfLevel(int level) => [
    33 - 3 * level,
    32 - 3 * level,
    31 - 3 * level,
  ];

  /// The six hizbs of a level, in teaching order.
  static List<int> hizbsOfLevel(int level) => [
    for (final juz in juzOfLevel(level)) ...hizbsOfJuz(juz),
  ];

  /// The hizb a level starts at: 59, 53, 47 ... 5.
  static int firstHizbOfLevel(int level) => 65 - 6 * level;

  /// The hizb a level ends at: 56, 50, 44 ... 2. A level is complete only
  /// after this hizb — not after its first, which was the historical bug.
  static int lastHizbOfLevel(int level) => 62 - 6 * level;

  /// The level a hizb belongs to. Level 1 owns hizbs 55-60, level 2 owns 49-54.
  static int levelOfHizb(int hizb) => ((60 - hizb) ~/ 6) + 1;

  /// The next hizb in teaching order, or null at the end of the curriculum.
  ///
  /// Odd hizbs are the first half of their juz, so the next hizb is the second
  /// half (59 -> 60). Even hizbs end their juz, so the next hizb is the first
  /// half of the next (lower) juz (60 -> 57). This crosses level boundaries
  /// naturally: 56 -> 53.
  static int? nextHizb(int hizb) {
    if (hizb == lastHizbOfLevel(totalLevels)) return null;
    return hizb.isOdd ? hizb + 1 : hizb - 3;
  }

  /// A hizb's position in the whole curriculum, 0 (hizb 59) to 59 (hizb 2).
  /// Monotonic in teaching order, so positions can be compared numerically.
  static int hizbOrderIndex(int hizb) {
    final level = levelOfHizb(hizb);
    final indexInLevel = hizbsOfLevel(level).indexOf(hizb);
    return (level - 1) * hizbsPerLevel + indexInLevel;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/curriculum_order_test.dart`
Expected: PASS — all 8 tests.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze lib/domain test/unit/domain
git add lib/domain/curriculum/curriculum_order.dart test/unit/domain/curriculum/curriculum_order_test.dart
git commit -m "feat(curriculum): add CurriculumOrder with the correct teaching order"
```

---

### Task 2: `CurriculumPosition` — the position value object

An immutable point in the curriculum: the same four fields the student record already carries. Used for both the student's current position and their enrollment anchor.

**Files:**
- Create: `lib/domain/curriculum/curriculum_position.dart`
- Test: `test/unit/domain/curriculum/curriculum_position_test.dart`

**Interfaces:**
- Consumes: `CurriculumOrder` (Task 1).
- Produces: `class CurriculumPosition` — `const CurriculumPosition({required int level, required int hizb, required int session})`, getters `int level`, `int hizb`, `int session`, `int juz`; `static const CurriculumPosition start`; `factory CurriculumPosition.fromMap(Map<String, dynamic> map)`; `Map<String, dynamic> toMap()`; `bool isBefore(CurriculumPosition other)`; value equality.

- [ ] **Step 1: Write the failing test**

Create `test/unit/domain/curriculum/curriculum_position_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';

void main() {
  group('CurriculumPosition', () {
    test('the default start is the first session of the curriculum', () {
      expect(CurriculumPosition.start.level, 1);
      expect(CurriculumPosition.start.juz, 30);
      expect(CurriculumPosition.start.hizb, 59);
      expect(CurriculumPosition.start.session, 1);
    });

    test('the juz is derived from the hizb', () {
      const position = CurriculumPosition(level: 2, hizb: 53, session: 12);
      expect(position.juz, 27);
    });

    // Validation lives in the named `validated` constructor: a const
    // constructor cannot throw, and positions from the UI or from Firestore
    // must be checked at that boundary.
    test('a position rejects a hizb that does not belong to its level', () {
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 53, session: 1),
        throwsArgumentError,
      );
    });

    test('a position rejects a session outside the hizb', () {
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 59, session: 0),
        throwsArgumentError,
      );
      expect(
        () => CurriculumPosition.validated(level: 1, hizb: 59, session: 37),
        throwsArgumentError,
      );
    });

    test('a position rejects a level outside the curriculum', () {
      expect(
        () => CurriculumPosition.validated(level: 11, hizb: 1, session: 1),
        throwsArgumentError,
      );
    });

    test('an earlier session in the same hizb comes before a later one', () {
      const earlier = CurriculumPosition(level: 1, hizb: 59, session: 5);
      const later = CurriculumPosition(level: 1, hizb: 59, session: 35);
      expect(earlier.isBefore(later), isTrue);
      expect(later.isBefore(earlier), isFalse);
    });

    test('ordering follows the teaching order, not the hizb number', () {
      // Hizb 60 is taught after hizb 59, and hizb 57 after both.
      const inHizb59 = CurriculumPosition(level: 1, hizb: 59, session: 36);
      const inHizb60 = CurriculumPosition(level: 1, hizb: 60, session: 1);
      const inHizb57 = CurriculumPosition(level: 1, hizb: 57, session: 1);

      expect(inHizb59.isBefore(inHizb60), isTrue);
      expect(inHizb60.isBefore(inHizb57), isTrue);
      expect(inHizb57.isBefore(inHizb59), isFalse);
    });

    test('an earlier level comes before a later one', () {
      const inLevel1 = CurriculumPosition(level: 1, hizb: 56, session: 36);
      const inLevel2 = CurriculumPosition(level: 2, hizb: 53, session: 1);
      expect(inLevel1.isBefore(inLevel2), isTrue);
    });

    test('a position is not before itself', () {
      const position = CurriculumPosition(level: 3, hizb: 47, session: 10);
      expect(position.isBefore(position), isFalse);
    });

    test('a position round-trips through a map', () {
      const position = CurriculumPosition(level: 2, hizb: 53, session: 35);
      final map = position.toMap();

      expect(map, {'level': 2, 'juz': 27, 'hizb': 53, 'session': 35});
      expect(CurriculumPosition.fromMap(map), position);
    });

    test('positions with the same coordinates are equal', () {
      const a = CurriculumPosition(level: 1, hizb: 59, session: 1);
      const b = CurriculumPosition(level: 1, hizb: 59, session: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/domain/curriculum/curriculum_position_test.dart`
Expected: FAIL — `curriculum_position.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/domain/curriculum/curriculum_position.dart`:

```dart
import 'curriculum_order.dart';

/// An immutable point in the curriculum: a session, in a hizb, in a level.
///
/// The juz is derived from the hizb rather than stored, so a position cannot
/// contradict itself. Positions are ordered by the curriculum's teaching order
/// (see [CurriculumOrder]), which is not the numeric order of the hizbs.
class CurriculumPosition {
  final int level;
  final int hizb;
  final int session;

  /// The first session of the curriculum: level 1, juz 30, hizb 59, session 1.
  static const CurriculumPosition start = CurriculumPosition(
    level: 1,
    hizb: 59,
    session: 1,
  );

  const CurriculumPosition({
    required this.level,
    required this.hizb,
    required this.session,
  }) : assert(level >= 1), assert(session >= 1);

  /// Validates the position against the curriculum. Throws [ArgumentError] if
  /// the level, hizb and session cannot describe a real point in the curriculum.
  CurriculumPosition.validated({
    required this.level,
    required this.hizb,
    required this.session,
  }) {
    if (level < 1 || level > CurriculumOrder.totalLevels) {
      throw ArgumentError.value(level, 'level', 'Level must be 1-10');
    }
    if (CurriculumOrder.levelOfHizb(hizb) != level) {
      throw ArgumentError.value(
        hizb,
        'hizb',
        'Hizb $hizb does not belong to level $level',
      );
    }
    if (session < 1 || session > 36) {
      throw ArgumentError.value(session, 'session', 'Session must be 1-36');
    }
  }

  /// The juz this position falls in, derived from the hizb.
  int get juz => CurriculumOrder.juzOfHizb(hizb);

  /// Whether this position is taught before [other].
  bool isBefore(CurriculumPosition other) {
    final thisHizb = CurriculumOrder.hizbOrderIndex(hizb);
    final otherHizb = CurriculumOrder.hizbOrderIndex(other.hizb);
    if (thisHizb != otherHizb) return thisHizb < otherHizb;
    return session < other.session;
  }

  factory CurriculumPosition.fromMap(Map<String, dynamic> map) {
    return CurriculumPosition.validated(
      level: map['level'] as int,
      hizb: map['hizb'] as int,
      session: map['session'] as int,
    );
  }

  /// The juz is written for readability; [fromMap] re-derives it from the hizb.
  Map<String, dynamic> toMap() => {
    'level': level,
    'juz': juz,
    'hizb': hizb,
    'session': session,
  };

  @override
  String toString() =>
      'CurriculumPosition(level: $level, juz: $juz, hizb: $hizb, session: $session)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurriculumPosition &&
          other.level == level &&
          other.hizb == hizb &&
          other.session == session;

  @override
  int get hashCode => Object.hash(level, hizb, session);
}
```

Note: a const constructor cannot throw, so validation lives in the named
`CurriculumPosition.validated` constructor — which every boundary (the picker, Firestore
deserialization) must use. The const constructor keeps `start` and test literals cheap.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/domain/curriculum/curriculum_position_test.dart`
Expected: PASS — all 11 tests.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze lib/domain test/unit/domain
git add lib/domain/curriculum/curriculum_position.dart test/unit/domain/curriculum/curriculum_position_test.dart
git commit -m "feat(curriculum): add CurriculumPosition value object"
```

---

### Task 3: Real session numbers for a hizb (tolerating bad data)

Advancement and the picker both need the session numbers that **actually exist** in a hizb — the data is sparse and carries extraction noise. This adds one query to `CurriculumRepository` that filters the noise out.

**Files:**
- Modify: `lib/data/repositories/curriculum_repository.dart` (add a method; keep everything else)
- Test: `test/unit/data/repositories/curriculum_repository_test.dart` (create — no test file exists for this repository yet)

**Interfaces:**
- Consumes: `CurriculumOrder.juzOfHizb` (Task 1).
- Produces: `Future<List<int>> CurriculumRepository.getSessionNumbersForHizb({required int level, required int hizb})` — ascending, deduplicated, excluding sessions with `session_number <= 0` and sessions whose `juz_number` contradicts the hizb.

- [ ] **Step 1: Write the failing test**

Create `test/unit/data/repositories/curriculum_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';

void main() {
  group('CurriculumRepository.getSessionNumbersForHizb', () {
    late FakeFirebaseFirestore firestore;
    late CurriculumRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = CurriculumRepository(firestore: firestore);
    });

    Future<void> seedSession({
      required int level,
      required int juz,
      required int hizb,
      required int session,
      String type = 'regular',
    }) async {
      await firestore
          .collection('sessions')
          .doc('L${level}_J${juz}_H${hizb}_S$session')
          .set({
            'session_number': session,
            'level_id': level,
            'juz_number': juz,
            'hizb_number': hizb,
            'session_type': type,
          });
    }

    test('returns the sessions of the hizb in ascending order', () async {
      await seedSession(level: 1, juz: 30, hizb: 59, session: 12);
      await seedSession(level: 1, juz: 30, hizb: 59, session: 2);
      await seedSession(level: 1, juz: 30, hizb: 59, session: 35, type: 'sard');
      await seedSession(level: 1, juz: 30, hizb: 59, session: 36, type: 'exam');

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 59,
      );

      expect(sessions, [2, 12, 35, 36]);
    });

    test('the curriculum is sparse — missing session numbers are not invented', () async {
      await seedSession(level: 2, juz: 25, hizb: 49, session: 2);
      await seedSession(level: 2, juz: 25, hizb: 49, session: 18);
      await seedSession(level: 2, juz: 25, hizb: 49, session: 36, type: 'exam');

      final sessions = await repository.getSessionNumbersForHizb(
        level: 2,
        hizb: 49,
      );

      expect(sessions, [2, 18, 36]);
    });

    test('sessions whose juz contradicts their hizb are ignored', () async {
      // The seeded curriculum carries an extraction artefact: a hizb-59 session
      // filed under juz 29, though hizb 59 belongs to juz 30.
      await seedSession(level: 1, juz: 30, hizb: 59, session: 1);
      await seedSession(level: 1, juz: 29, hizb: 59, session: 2);

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 59,
      );

      expect(sessions, [1]);
    });

    test('a session numbered zero is ignored', () async {
      await seedSession(level: 1, juz: 29, hizb: 58, session: 0);
      await seedSession(level: 1, juz: 29, hizb: 58, session: 1);

      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 58,
      );

      expect(sessions, [1]);
    });

    test('a hizb with no seeded sessions returns empty', () async {
      final sessions = await repository.getSessionNumbersForHizb(
        level: 1,
        hizb: 57,
      );

      expect(sessions, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/repositories/curriculum_repository_test.dart`
Expected: FAIL — `The method 'getSessionNumbersForHizb' isn't defined for the type 'CurriculumRepository'`.

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/curriculum_repository.dart`, add the import at the top of the file:

```dart
import '../../domain/curriculum/curriculum_order.dart';
```

and add this method to the `CurriculumRepository` class, after `getSessionsForHizb`:

```dart
  /// The session numbers that actually exist in a hizb, ascending.
  ///
  /// The curriculum is sparse: a hizb holds a subset of the numbers 1-36, so
  /// callers must never assume `session + 1` exists. The seeded data also
  /// carries extraction noise, tolerated here rather than fixed at the source:
  /// sessions numbered 0, and sessions whose juz contradicts their hizb (a
  /// stray hizb-59 pair filed under juz 29), are ignored.
  Future<List<int>> getSessionNumbersForHizb({
    required int level,
    required int hizb,
  }) async {
    final query = await _sessionsCollection
        .where('level_id', isEqualTo: level)
        .where('hizb_number', isEqualTo: hizb)
        .get();

    final expectedJuz = CurriculumOrder.juzOfHizb(hizb);
    final numbers = <int>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final sessionNumber = data['session_number'] as int? ?? 0;
      final juzNumber = data['juz_number'] as int?;
      if (sessionNumber < 1) continue;
      if (juzNumber != expectedJuz) continue;
      numbers.add(sessionNumber);
    }

    return numbers.toList()..sort();
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/data/repositories/curriculum_repository_test.dart`
Expected: PASS — all 5 tests.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze lib/data test/unit/data
git add lib/data/repositories/curriculum_repository.dart test/unit/data/repositories/curriculum_repository_test.dart
git commit -m "feat(curriculum): expose the real (sparse) session numbers of a hizb"
```

---

### Task 4: Give `StudentModel` a position and an enrollment anchor

The student record already carries the four position fields; this exposes them as a `CurriculumPosition` and adds the immutable enrollment anchor, plus the factory that backfills credit for everything before it.

**Files:**
- Modify: `lib/data/models/student_model.dart`
- Test: `test/unit/data/models/student_model_test.dart` (append a group; leave existing tests untouched)

**Interfaces:**
- Consumes: `CurriculumPosition` (Task 2), `CurriculumOrder` (Task 1).
- Produces on `StudentModel`: field `CurriculumPosition enrollmentPosition` (constructor parameter `enrollmentPosition`, defaulting to `CurriculumPosition.start`), getter `CurriculumPosition currentPosition`, factory `StudentModel.enrolledAt({required String id, required String userId, required String instituteId, String? teacherId, String? guardianId, required CurriculumPosition position, required DateTime createdAt})`. Firestore key: `enrollment_position`.

- [ ] **Step 1: Write the failing test**

Append to `test/unit/data/models/student_model_test.dart`, inside the existing top-level `group('StudentModel', ...)` (add the two imports at the top of the file if absent):

```dart
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
```

```dart
    group('enrollment position', () {
      test('a student enrolled at the start of the curriculum earns no credit', () {
        final student = StudentModel.enrolledAt(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          position: CurriculumPosition.start,
          createdAt: DateTime(2026, 7, 13),
        );

        expect(student.enrollmentPosition, CurriculumPosition.start);
        expect(student.currentLevel, 1);
        expect(student.currentJuz, 30);
        expect(student.currentHizb, 59);
        expect(student.currentSession, 1);
        expect(student.completedLevels, isEmpty);
        expect(student.unlockedLevels, [1]);
      });

      test('a student enrolled mid-curriculum is credited with the levels before them', () {
        final student = StudentModel.enrolledAt(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          position: const CurriculumPosition(level: 3, hizb: 47, session: 12),
          createdAt: DateTime(2026, 7, 13),
        );

        expect(student.currentLevel, 3);
        expect(student.currentJuz, 24);
        expect(student.currentHizb, 47);
        expect(student.currentSession, 12);
        expect(student.completedLevels, [1, 2]);
        expect(student.unlockedLevels, [1, 2, 3]);
      });

      test('a student can be enrolled directly onto a Sard session', () {
        final student = StudentModel.enrolledAt(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          position: const CurriculumPosition(level: 2, hizb: 53, session: 35),
          createdAt: DateTime(2026, 7, 13),
        );

        expect(student.currentSession, 35);
        expect(student.canTakeSard, isTrue);
        expect(student.completedLevels, [1]);
      });

      test('the current position is exposed as a curriculum position', () {
        final student = StudentModel(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          currentLevel: 2,
          currentJuz: 27,
          currentHizb: 53,
          currentSession: 4,
          createdAt: DateTime(2026, 7, 13),
        );

        expect(
          student.currentPosition,
          const CurriculumPosition(level: 2, hizb: 53, session: 4),
        );
      });

      test('the enrollment position round-trips through Firestore', () async {
        final student = StudentModel.enrolledAt(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          position: const CurriculumPosition(level: 2, hizb: 53, session: 35),
          createdAt: DateTime(2026, 7, 13),
        );

        final data = student.toFirestore();
        expect(data['enrollment_position'], {
          'level': 2,
          'juz': 27,
          'hizb': 53,
          'session': 35,
        });

        final firestore = FakeFirebaseFirestore();
        await firestore.collection('students').doc('s1').set(data);
        final doc = await firestore.collection('students').doc('s1').get();

        expect(
          StudentModel.fromFirestore(doc).enrollmentPosition,
          const CurriculumPosition(level: 2, hizb: 53, session: 35),
        );
      });

      test('a student created before this feature reads back as starting at the beginning', () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('students').doc('old').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_hizb': 59,
          'current_session': 8,
          'current_attempt': 1,
          'completed_levels': <int>[],
          'unlocked_levels': [1],
          'is_active': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });

        final doc = await firestore.collection('students').doc('old').get();

        expect(
          StudentModel.fromFirestore(doc).enrollmentPosition,
          CurriculumPosition.start,
        );
      });
    });
```

If `FakeFirebaseFirestore` and `Timestamp` are not already imported in this test file, add:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/models/student_model_test.dart`
Expected: FAIL — `The method 'enrolledAt' isn't defined for the type 'StudentModel'`.

- [ ] **Step 3: Write the implementation**

In `lib/data/models/student_model.dart`, add the import:

```dart
import '../../domain/curriculum/curriculum_position.dart';
```

Add the field to the class, alongside the existing ones:

```dart
  /// Where this student entered the curriculum. Everything before it is
  /// credited as memorized before joining — the app never taught it. Students
  /// created before flexible placement have no stored anchor and read back as
  /// [CurriculumPosition.start], which is exactly what they were.
  final CurriculumPosition enrollmentPosition;
```

Add the constructor parameter (in the `const StudentModel({...})` parameter list):

```dart
    this.enrollmentPosition = CurriculumPosition.start,
```

Add the factory below the main constructor:

```dart
  /// Enrolls a student at [position], crediting every level before it as
  /// already memorized. The student's current position *is* the anchor: they
  /// start work at the session they were placed on.
  factory StudentModel.enrolledAt({
    required String id,
    required String userId,
    required String instituteId,
    String? teacherId,
    String? guardianId,
    required CurriculumPosition position,
    required DateTime createdAt,
  }) {
    final completedLevels = [
      for (var level = 1; level < position.level; level++) level,
    ];
    final unlockedLevels = [
      for (var level = 1; level <= position.level; level++) level,
    ];

    return StudentModel(
      id: id,
      userId: userId,
      instituteId: instituteId,
      teacherId: teacherId,
      guardianId: guardianId,
      currentLevel: position.level,
      currentJuz: position.juz,
      currentHizb: position.hizb,
      currentSession: position.session,
      completedLevels: completedLevels,
      unlockedLevels: unlockedLevels,
      enrollmentPosition: position,
      createdAt: createdAt,
    );
  }
```

Add the getter, next to the other computed getters:

```dart
  /// Where the student is now, as a curriculum position.
  CurriculumPosition get currentPosition => CurriculumPosition(
    level: currentLevel,
    hizb: currentHizb,
    session: currentSession,
  );
```

In `fromFirestore`, read the anchor (place it with the other field reads):

```dart
      enrollmentPosition: data['enrollment_position'] == null
          ? CurriculumPosition.start
          : CurriculumPosition.fromMap(
              Map<String, dynamic>.from(data['enrollment_position'] as Map),
            ),
```

In `toFirestore`, write it:

```dart
      'enrollment_position': enrollmentPosition.toMap(),
```

In `copyWith`, add the parameter `CurriculumPosition? enrollmentPosition,` and pass
`enrollmentPosition: enrollmentPosition ?? this.enrollmentPosition,`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/data/models/student_model_test.dart`
Expected: PASS — the existing tests plus the 6 new ones.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze lib/data test/unit/data
git add lib/data/models/student_model.dart test/unit/data/models/student_model_test.dart
git commit -m "feat(student): add the enrollment anchor and derived credit"
```

---

### Task 5: Fix advancement to follow the real curriculum

This is the bug fix the placement feature depends on. Today `advanceStudentSession` decrements the hizb (59 → 58) and compares against the level's *first* hizb, so a student completes a level after one of its six hizbs; it also walks session numbers that don't exist.

**Files:**
- Modify: `lib/data/repositories/student_repository.dart` (constructor, `advanceStudentSession`, delete `_getFirstHizbOfLevel` and `_getFirstJuzOfLevel`, update `studentRepositoryProvider`)
- Test: `test/unit/data/repositories/student_repository_test.dart` (rewrite the `advanceStudentSession` group; update `setUp`)

**Interfaces:**
- Consumes: `CurriculumOrder` (Task 1), `CurriculumPosition` (Task 2), `CurriculumRepository.getSessionNumbersForHizb` (Task 3), `StudentModel.currentPosition` (Task 4).
- Produces: `StudentRepository({FirebaseFirestore? firestore, required FirebaseService firebaseService, required UserRepository userRepository, required CurriculumRepository curriculumRepository})` — **a new required parameter**; `advanceStudentSession` unchanged in signature.

- [ ] **Step 1: Write the failing tests**

In `test/unit/data/repositories/student_repository_test.dart`:

First, in `setUp`, construct the repository with a curriculum repository over the same fake
Firestore (add `import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';` at the top):

```dart
      studentRepository = StudentRepository(
        firestore: fakeFirestore,
        firebaseService: firebaseService,
        userRepository: userRepository,
        curriculumRepository: CurriculumRepository(firestore: fakeFirestore),
      );
```

Then **replace the whole `group('advanceStudentSession', ...)` block** with:

```dart
    group('advanceStudentSession', () {
      /// Seeds one curriculum session. The curriculum is sparse, so tests seed
      /// exactly the sessions they mean to exist.
      Future<void> seedSession({
        required int level,
        required int hizb,
        required int session,
      }) async {
        final juz = (hizb + 1) ~/ 2;
        await fakeFirestore
            .collection('sessions')
            .doc('L${level}_J${juz}_H${hizb}_S$session')
            .set({
              'session_number': session,
              'level_id': level,
              'juz_number': juz,
              'hizb_number': hizb,
              'session_type': session == 35
                  ? 'sard'
                  : session == 36
                  ? 'exam'
                  : 'regular',
            });
      }

      Future<void> seedStudent({
        required int level,
        required int hizb,
        required int session,
        int attempt = 1,
        List<int> completedLevels = const [],
        List<int> unlockedLevels = const [1],
      }) async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': level,
          'current_juz': (hizb + 1) ~/ 2,
          'current_hizb': hizb,
          'current_session': session,
          'current_attempt': attempt,
          'completed_levels': completedLevels,
          'unlocked_levels': unlockedLevels,
          'is_active': true,
          'created_at': Timestamp.now(),
        });
      }

      Future<Map<String, dynamic>> readStudent() async {
        final doc = await fakeFirestore.collection('students').doc('s1').get();
        return doc.data()!;
      }

      test('moves to the next session in the same hizb', () async {
        await seedSession(level: 1, hizb: 59, session: 5);
        await seedSession(level: 1, hizb: 59, session: 6);
        await seedStudent(level: 1, hizb: 59, session: 5, attempt: 2);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_session'], 6);
        expect(student['current_hizb'], 59);
        expect(student['current_attempt'], 1);
      });

      test('skips session numbers the curriculum does not contain', () async {
        // Hizb 49 is sparse: sessions 2 and 18 exist, nothing between them.
        await seedSession(level: 2, hizb: 49, session: 2);
        await seedSession(level: 2, hizb: 49, session: 18);
        await seedStudent(
          level: 2,
          hizb: 49,
          session: 2,
          completedLevels: [1],
          unlockedLevels: [1, 2],
        );

        await studentRepository.advanceStudentSession('s1');

        expect((await readStudent())['current_session'], 18);
      });

      test('moves to the next hizb in teaching order, not the next number down', () async {
        // Level 1 is taught 59, 60, 57, 58, 55, 56 — after hizb 59 comes 60.
        await seedSession(level: 1, hizb: 59, session: 36);
        await seedSession(level: 1, hizb: 60, session: 1);
        await seedStudent(level: 1, hizb: 59, session: 36);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_hizb'], 60);
        expect(student['current_juz'], 30);
        expect(student['current_session'], 1);
        expect(student['current_level'], 1);
        expect(student['completed_levels'], isEmpty);
      });

      test('finishing a hizb does not complete the level', () async {
        // The old code promoted the student to level 2 here. It must not.
        await seedSession(level: 1, hizb: 60, session: 36);
        await seedSession(level: 1, hizb: 57, session: 1);
        await seedStudent(level: 1, hizb: 60, session: 36);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 1);
        expect(student['current_hizb'], 57);
        expect(student['current_juz'], 29);
        expect(student['completed_levels'], isEmpty);
      });

      test('the level completes only after its last hizb', () async {
        // Hizb 56 is the last hizb of level 1; the next is 53, in level 2.
        await seedSession(level: 1, hizb: 56, session: 36);
        await seedSession(level: 2, hizb: 53, session: 1);
        await seedStudent(level: 1, hizb: 56, session: 36);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 2);
        expect(student['current_hizb'], 53);
        expect(student['current_juz'], 27);
        expect(student['current_session'], 1);
        expect(student['completed_levels'], contains(1));
        expect(student['unlocked_levels'], contains(2));
      });

      test('a hizb with no seeded sessions is stepped over', () async {
        await seedSession(level: 1, hizb: 59, session: 36);
        // Hizb 60 has no sessions at all; the next real one is in hizb 57.
        await seedSession(level: 1, hizb: 57, session: 1);
        await seedStudent(level: 1, hizb: 59, session: 36);

        await studentRepository.advanceStudentSession('s1');

        expect((await readStudent())['current_hizb'], 57);
      });

      test('the end of the curriculum is a terminal position', () async {
        // Hizb 2 is the last hizb of level 10, session 36 its exam.
        await seedSession(level: 10, hizb: 2, session: 36);
        await seedStudent(
          level: 10,
          hizb: 2,
          session: 36,
          attempt: 2,
          completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9],
          unlockedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        );

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 10);
        expect(student['current_hizb'], 2);
        expect(student['current_session'], 36);
        expect(student['current_attempt'], 1);
      });

      test('does nothing when the student does not exist', () async {
        await studentRepository.advanceStudentSession('nonexistent');
      });
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: FAIL — compilation error first (`No named parameter with the name 'curriculumRepository'`).

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/student_repository.dart`:

Add imports:

```dart
import '../../domain/curriculum/curriculum_order.dart';
import '../../domain/curriculum/curriculum_position.dart';
import 'curriculum_repository.dart';
```

Add the dependency to the class and constructor:

```dart
  final CurriculumRepository _curriculumRepository;

  StudentRepository({
    FirebaseFirestore? firestore,
    required FirebaseService firebaseService,
    required UserRepository userRepository,
    required CurriculumRepository curriculumRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseService = firebaseService,
       _userRepository = userRepository,
       _curriculumRepository = curriculumRepository;
```

Replace `advanceStudentSession` entirely:

```dart
  /// Advance the student to the next session in the curriculum.
  ///
  /// Follows the real teaching order (level 1 runs 59, 60, 57, 58, 55, 56) over
  /// the sessions that actually exist — the curriculum is sparse, so the next
  /// session is rarely `current + 1`. A level completes only after its last
  /// hizb. At the end of the curriculum the student stays where they are.
  Future<void> advanceStudentSession(String studentId) async {
    final student = await getStudentById(studentId);
    if (student == null) return;

    final next = await _nextPosition(student.currentPosition);
    if (next == null) {
      await resetStudentAttempt(studentId);
      return;
    }

    final completedLevels = List<int>.from(student.completedLevels);
    final unlockedLevels = List<int>.from(student.unlockedLevels);
    if (next.level > student.currentLevel) {
      if (!completedLevels.contains(student.currentLevel)) {
        completedLevels.add(student.currentLevel);
      }
      if (!unlockedLevels.contains(next.level)) {
        unlockedLevels.add(next.level);
      }
    }

    await _studentsCollection.doc(studentId).update({
      'current_level': next.level,
      'current_juz': next.juz,
      'current_hizb': next.hizb,
      'current_session': next.session,
      'current_attempt': 1,
      'completed_levels': completedLevels,
      'unlocked_levels': unlockedLevels,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// The next position after [from] in teaching order, or null at the end of
  /// the curriculum. Hizbs with no seeded sessions are stepped over.
  Future<CurriculumPosition?> _nextPosition(CurriculumPosition from) async {
    final sessions = await _curriculumRepository.getSessionNumbersForHizb(
      level: from.level,
      hizb: from.hizb,
    );
    final laterInHizb = sessions.where((s) => s > from.session);
    if (laterInHizb.isNotEmpty) {
      return CurriculumPosition(
        level: from.level,
        hizb: from.hizb,
        session: laterInHizb.first,
      );
    }

    int? hizb = CurriculumOrder.nextHizb(from.hizb);
    while (hizb != null) {
      final level = CurriculumOrder.levelOfHizb(hizb);
      final next = await _curriculumRepository.getSessionNumbersForHizb(
        level: level,
        hizb: hizb,
      );
      if (next.isNotEmpty) {
        return CurriculumPosition(level: level, hizb: hizb, session: next.first);
      }
      hizb = CurriculumOrder.nextHizb(hizb);
    }

    return null;
  }
```

Delete the two private helpers at the bottom of the class (`_getFirstHizbOfLevel`,
`_getFirstJuzOfLevel`) — curriculum rules now live in `CurriculumOrder`.

Update the provider at the bottom of the file:

```dart
final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseService: ref.watch(firebaseServiceProvider),
    userRepository: ref.watch(userRepositoryProvider),
    curriculumRepository: ref.watch(curriculumRepositoryProvider),
  );
});
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: PASS — 8 advancement tests plus the file's existing tests.

Then run the whole suite, since other tests construct `StudentRepository`:

Run: `flutter test`
Expected: PASS. If another test file constructs `StudentRepository` directly, add
`curriculumRepository: CurriculumRepository(firestore: fakeFirestore),` there too.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze
git add lib/data/repositories/student_repository.dart test/unit/data/repositories/student_repository_test.dart
git commit -m "fix(curriculum): advance through the real teaching order and sparse sessions

A level was completing after one of its six hizbs: advancement decremented
the hizb (59 -> 58) instead of following the teaching order (59 -> 60), then
compared against the level's first hizb. It also walked session numbers the
curriculum does not contain. Curriculum rules move to CurriculumOrder."
```

---

### Task 6: Create a student at a chosen position

**Files:**
- Modify: `lib/data/repositories/student_repository.dart` (`createStudent`)
- Test: `test/unit/data/repositories/student_repository_test.dart` (append to the existing `createStudent` group)

**Interfaces:**
- Consumes: `StudentModel.enrolledAt` (Task 4), `CurriculumPosition` (Task 2).
- Produces: `createStudent(...)` gains `CurriculumPosition startingPosition = CurriculumPosition.start` as a new optional named parameter. All existing callers keep working.

- [ ] **Step 1: Write the failing test**

Append inside the existing `group('createStudent', ...)` in
`test/unit/data/repositories/student_repository_test.dart`:

```dart
      test('a student created without a position starts at the beginning', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب جديد',
          username: 'newstudent',
          password: 'secret123',
          instituteId: 'i1',
          teacherId: 't1',
        );

        expect(result.student.enrollmentPosition, CurriculumPosition.start);
        expect(result.student.currentHizb, 59);
        expect(result.student.completedLevels, isEmpty);
      });

      test('a student placed mid-curriculum is credited with the levels before them', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب حافظ',
          username: 'hafiz',
          password: 'secret123',
          instituteId: 'i1',
          teacherId: 't1',
          startingPosition: const CurriculumPosition(
            level: 2,
            hizb: 53,
            session: 35,
          ),
        );

        expect(result.student.currentLevel, 2);
        expect(result.student.currentHizb, 53);
        expect(result.student.currentJuz, 27);
        expect(result.student.currentSession, 35);
        expect(result.student.completedLevels, [1]);
        expect(result.student.unlockedLevels, [1, 2]);

        final doc = await fakeFirestore
            .collection('students')
            .doc(result.student.id)
            .get();
        expect(doc.data()?['enrollment_position'], {
          'level': 2,
          'juz': 27,
          'hizb': 53,
          'session': 35,
        });
      });
```

Add to the file's imports if absent:

```dart
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart --plain-name createStudent`
Expected: FAIL — `No named parameter with the name 'startingPosition'`.

- [ ] **Step 3: Write the implementation**

In `lib/data/repositories/student_repository.dart`, add the parameter to `createStudent`'s
signature (after `guardianPhone`):

```dart
    CurriculumPosition startingPosition = CurriculumPosition.start,
```

and extend the doc comment above it with:

```dart
  /// [startingPosition] is where the student enters the curriculum. It defaults
  /// to the first session; a teacher or supervisor may place a student who has
  /// already memorized part of the Quran at any point, which credits everything
  /// before that point as memorized before joining.
```

Then replace the student construction at the end of the method:

```dart
    final studentDocRef = _studentsCollection.doc();
    final student = StudentModel.enrolledAt(
      id: studentDocRef.id,
      userId: user.id,
      instituteId: instituteId,
      teacherId: teacherId,
      guardianId: guardianId,
      position: startingPosition,
      createdAt: DateTime.now(),
    );
    await studentDocRef.set(student.toFirestore());
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/unit/data/repositories/student_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze lib/data test/unit/data
git add lib/data/repositories/student_repository.dart test/unit/data/repositories/student_repository_test.dart
git commit -m "feat(student): create a student at a chosen curriculum position"
```

---

### Task 7: The starting-point picker

`AddStudentScreen` is already shared by the teacher route and the supervisor route
(`asSupervisor: true`, `lib/routing/app_router.dart:297` and `:353`), so both roles get the
picker from this one change.

**Files:**
- Create: `lib/features/teacher/widgets/starting_point_picker.dart`
- Modify: `lib/features/teacher/screens/add_student_screen.dart` (state field, the info banner at lines ~360-381, the `createStudent` call at ~157)
- Test: `test/widget/starting_point_picker_test.dart`

**Interfaces:**
- Consumes: `CurriculumOrder` (Task 1), `CurriculumPosition` (Task 2), `levelsProvider` and `curriculumRepositoryProvider` (existing, `lib/data/repositories/curriculum_repository.dart`), `createStudent(startingPosition:)` (Task 6).
- Produces: `class StartingPointPicker extends ConsumerStatefulWidget` — `const StartingPointPicker({super.key, required CurriculumPosition value, required ValueChanged<CurriculumPosition> onChanged})`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/starting_point_picker_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
import 'package:al_rasikhoon/features/teacher/widgets/starting_point_picker.dart';

/// Seeds two levels' worth of curriculum: level 1 hizb 59 (sessions 1, 2, 35, 36)
/// and level 2 hizb 53 (sessions 1, 35).
Future<FakeFirebaseFirestore> _seedCurriculum() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30, 29, 28],
    'total_sessions': 219,
    'hizb_count': 6,
    'order': 1,
  });
  await firestore.collection('levels').doc('level_2').set({
    'id': 2,
    'name_ar': 'المستوى الثاني',
    'name_en': 'Level 2',
    'juz_numbers': [27, 26, 25],
    'total_sessions': 150,
    'hizb_count': 6,
    'order': 2,
  });

  Future<void> session(int level, int hizb, int number, String type) {
    final juz = (hizb + 1) ~/ 2;
    return firestore
        .collection('sessions')
        .doc('L${level}_J${juz}_H${hizb}_S$number')
        .set({
          'session_number': number,
          'level_id': level,
          'juz_number': juz,
          'hizb_number': hizb,
          'session_type': type,
        });
  }

  await session(1, 59, 1, 'regular');
  await session(1, 59, 2, 'regular');
  await session(1, 59, 35, 'sard');
  await session(1, 59, 36, 'exam');
  await session(2, 53, 1, 'regular');
  await session(2, 53, 35, 'sard');

  return firestore;
}

Future<void> _pumpPicker(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  void Function(CurriculumPosition) onChanged,
) async {
  var value = CurriculumPosition.start;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [firestoreProvider.overrideWithValue(firestore)],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: StartingPointPicker(
                value: value,
                onChanged: (position) {
                  onChanged(position);
                  setState(() => value = position);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to the first session of the curriculum', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    expect(find.text('المستوى الأول'), findsOneWidget);
    expect(find.textContaining('الحزب ٥٩'), findsWidgets);
  });

  testWidgets('lists the hizbs of a level in teaching order', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    final picker = tester.widget<StartingPointPicker>(
      find.byType(StartingPointPicker),
    );
    expect(picker.value, CurriculumPosition.start);

    // The hizb dropdown offers level 1's hizbs in teaching order: 59, 60, 57...
    await tester.tap(find.byKey(const Key('starting_point_hizb')));
    await tester.pumpAndSettle();

    final items = tester
        .widgetList<Text>(find.textContaining('الحزب'))
        .map((t) => t.data)
        .toList();
    expect(items.first, contains('٥٩'));
  });

  testWidgets('choosing a session reports the position to the parent', (tester) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_session')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السرد').last);
    await tester.pumpAndSettle();

    expect(reported, const CurriculumPosition(level: 1, hizb: 59, session: 35));
  });

  testWidgets('changing the level resets the hizb and session', (tester) async {
    final firestore = await _seedCurriculum();
    CurriculumPosition? reported;
    await _pumpPicker(tester, firestore, (position) => reported = position);

    await tester.tap(find.byKey(const Key('starting_point_level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المستوى الثاني').last);
    await tester.pumpAndSettle();

    expect(reported?.level, 2);
    expect(reported?.hizb, 53); // first hizb of level 2 in teaching order
    expect(reported?.session, 1); // its first existing session
  });

  testWidgets('states the consequence of the placement', (tester) async {
    final firestore = await _seedCurriculum();
    await _pumpPicker(tester, firestore, (_) {});

    expect(
      find.textContaining('ويُعتبر ما قبلها من المنهج محفوظًا ومعتمدًا'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/starting_point_picker_test.dart`
Expected: FAIL — `starting_point_picker.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/features/teacher/widgets/starting_point_picker.dart`:

```dart
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
```

Then wire it into `lib/features/teacher/screens/add_student_screen.dart`:

Add the imports:

```dart
import '../../../domain/curriculum/curriculum_position.dart';
import '../widgets/starting_point_picker.dart';
```

Add the state field next to `_selectedInstitute`:

```dart
  CurriculumPosition _startingPosition = CurriculumPosition.start;
```

Pass it to `createStudent` (the call at ~line 157), adding one argument:

```dart
        startingPosition: _startingPosition,
```

Replace the info banner (the `Container` whose text reads
`'الطالب يبدأ من المستوى الأول. شارك اسم المستخدم وكلمة المرور معه.'`, together with the
`const SizedBox(height: 24)` immediately before it) with:

```dart
              const SizedBox(height: 24),
              StartingPointPicker(
                value: _startingPosition,
                onChanged: (position) {
                  setState(() => _startingPosition = position);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'شارك اسم المستخدم وكلمة المرور مع الطالب.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/widget/starting_point_picker_test.dart`
Expected: PASS — all 5 tests.

Run: `flutter test`
Expected: PASS — the whole suite.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze
git add lib/features/teacher/widgets/starting_point_picker.dart lib/features/teacher/screens/add_student_screen.dart test/widget/starting_point_picker_test.dart
git commit -m "feat(student): pick a starting point when adding a student"
```

---

### Task 8: End-to-end — a placed student reaches the Sard

The whole point of the feature is that a placed student keeps *all* the app's functionality. This
drives it: a student is created through the real `createStudent` path directly onto a Sard in
level 2, and the supervisor conducts that Sard through the UI — with the student holding zero
session records.

This mirrors the existing test at `integration_test/supervisor_flow_test.dart:173`
("Supervisor conducts a Sard end-to-end"), reusing its `TestEnvironment` and `SupervisorRobot`.
The difference: the student is *placed* rather than seeded at the default position.

**Files:**
- Modify: `integration_test/supervisor_flow_test.dart` (append one test inside the existing `group('Supervisor E2E Flow', ...)`)

**Interfaces:**
- Consumes: `createStudent(startingPosition:)` (Task 6), `CurriculumPosition` (Task 2), the existing `SupervisorRobot` Sard methods (`goToStudents`, `tapStudent`, `verifySessionOverview`, `verifySardAvailableForSupervisor`, `startSard`, `verifySardSession`, `enterSardErrors`, `finishSard`, `verifySardResult`, `saveSardResult`, `verifySardSaved`).
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Add these imports to `integration_test/supervisor_flow_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
```

Append inside `group('Supervisor E2E Flow', ...)`:

```dart
    testWidgets(
      'a student placed on a Sard is assessed with no prior sessions (#flexible-start)',
      (tester) async {
        // A student arrives having already memorized through level 1 and part of
        // level 2, and is placed directly on the Sard of hizb 53. The app taught
        // them none of it — they hold zero session records — and the supervisor
        // must still be able to assess them.
        const instituteId = 'placed_institute';
        final supervisor = env
            .createSupervisor()
            .copyWith(instituteId: instituteId);
        await env.setUp(authenticatedUser: supervisor);
        await env.addInstitute(id: instituteId);
        await env.assignSupervisorToInstitute(supervisor.id, instituteId);

        // The curriculum session they are placed on: level 2, juz 27, hizb 53,
        // session 35 (the Sard).
        await env.fakeFirestore
            .collection('sessions')
            .doc('L2_J27_H53_S35')
            .set({
              'session_number': 35,
              'level_id': 2,
              'juz_number': 27,
              'hizb_number': 53,
              'session_type': 'sard',
              'current_level_content': {
                'from_surah': 'الزمر',
                'from_verse': 1,
                'to_surah': 'الزمر',
                'to_verse': 31,
              },
              'recent_review_content': {
                'from_surah': 'ص',
                'from_verse': 1,
                'to_surah': 'ص',
                'to_verse': 88,
              },
              'distant_review_content': {
                'from_surah': 'يس',
                'from_verse': 1,
                'to_surah': 'يس',
                'to_verse': 83,
              },
            });

        // Place the student through the production path, not a seeded document.
        final container = ProviderContainer(overrides: env.overrides.cast());
        addTearDown(container.dispose);
        final created = await container
            .read(studentRepositoryProvider)
            .createStudent(
              name: 'طالب حافظ',
              username: 'placed_student',
              password: 'secret123',
              instituteId: instituteId,
              // teacher_id stays null: an institute-scoped student (AgDR-0003).
              startingPosition: const CurriculumPosition(
                level: 2,
                hizb: 53,
                session: 35,
              ),
            );

        // The anchor and the credit it implies are persisted.
        final doc = await env.fakeFirestore
            .collection('students')
            .doc(created.student.id)
            .get();
        expect(doc.data()?['current_level'], 2);
        expect(doc.data()?['current_hizb'], 53);
        expect(doc.data()?['current_juz'], 27);
        expect(doc.data()?['current_session'], 35);
        expect(doc.data()?['completed_levels'], [1]);
        expect(doc.data()?['enrollment_position'], {
          'level': 2,
          'juz': 27,
          'hizb': 53,
          'session': 35,
        });

        // They hold no session records at all — nothing was taught in the app.
        final records = await env.fakeFirestore
            .collection('session_records')
            .where('student_id', isEqualTo: created.student.id)
            .get();
        expect(records.docs, isEmpty);

        // The supervisor conducts their Sard end-to-end regardless.
        await tester.pumpWidget(TestApp(overrides: env.overrides));
        supervisorRobot = SupervisorRobot(tester);

        await supervisorRobot.verifyDashboard();
        await supervisorRobot.goToStudents();
        await supervisorRobot.verifyStudentsScreen();
        await supervisorRobot.tapStudent('طالب حافظ');
        await supervisorRobot.verifySessionOverview();
        await supervisorRobot.verifySardAvailableForSupervisor();

        await supervisorRobot.startSard();
        await supervisorRobot.verifySardSession();
        await supervisorRobot.enterSardErrors(2);
        await supervisorRobot.finishSard();
        await supervisorRobot.verifySardResult();
        await supervisorRobot.saveSardResult();

        await supervisorRobot.verifySardSaved();
      },
    );
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test integration_test/supervisor_flow_test.dart --plain-name "placed on a Sard"`
Expected: FAIL — before Tasks 1-7 exist, on `startingPosition` not being a parameter. With them
in place it should pass. If it fails for a *different* reason (for example the Sard screen
assumes prior session records), that is a real defect the feature must fix: correct it in `lib/`,
never by weakening the test.

- [ ] **Step 3: Run the whole integration file**

Run: `flutter test integration_test/supervisor_flow_test.dart`
Expected: PASS — the new test and the existing ones, including the Sard E2E at line 173.

- [ ] **Step 4: Commit**

```bash
git add integration_test/supervisor_flow_test.dart
git commit -m "test(student): a placed student is assessed with no prior sessions"
```

---

### Task 9: Close out

- [ ] **Step 1: Confirm the Firestore rules need no change**

The spec assumes `enrollment_position` needs no rule change — student creation is already allowed
for teachers and institute-scoped supervisors, and the rules do not validate document schema.
Confirm rather than assume:

```bash
grep -n -A20 "match /students" firestore.rules
flutter test test/rules
```

Expected: the `create` rule gates on role and institute only (no field allowlist), and the rules
tests pass. If a field allowlist does exist, add `enrollment_position` to it and re-run.

- [ ] **Step 2: Run every gate**

```bash
flutter analyze
flutter test
```

Expected: no analyzer issues, all tests pass.

- [ ] **Step 3: File the deferred follow-up**

The spec defers repositioning an existing student. File it so it is not lost:

```bash
bd create --title="Reposition an enrolled student in the curriculum" \
  --description="Flexible placement (docs/superpowers/specs/2026-07-13-flexible-student-starting-point-design.md) sets the enrollment anchor at creation only. Allow an authorized role to move an existing student to a different curriculum position afterwards: move the anchor, recompute completed_levels/unlocked_levels, and decide what happens to their existing session records." \
  --type=feature --priority=2
```

- [ ] **Step 4: Push**

```bash
git pull --rebase
bd dolt push
git push
git status  # must show "up to date with origin"
```
