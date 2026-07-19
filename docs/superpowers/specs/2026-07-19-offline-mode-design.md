# Offline Mode Support — Design

**Date:** 2026-07-19
**Status:** Approved pending final review
**Approach:** Lean on Firestore's built-in offline engine (Approach A)

## Problem

The institute often has no or very slow internet, but teachers must still sit
with students and run memorization sessions. Today the app is unusable offline:

- Nothing guarantees the data a teacher needs (students, curriculum, history)
  is in Firestore's local cache when connectivity drops.
- Saving a session performs `await`ed Firestore writes; offline, those futures
  never resolve until the server acknowledges them, so the teacher is stuck on
  a spinner forever even though the write is safely queued locally.
- The session save is **two independent writes** (create the record in
  `session_records`, then update the `students` doc to advance curriculum
  position) with no batch — a partial sync could record a session without
  advancing the student, or vice versa.
- No UI reflects connectivity or pending-sync state anywhere in the app.

## Goals

1. **All roles** (teacher, supervisor, admin, student, parent) can browse their
   last-fetched data with no connection.
2. Teachers can run and save memorization / تلقين / سرد sessions offline;
   supervisors can run and save exams offline. Saves are instant, atomic, and
   sync automatically when connectivity returns.
3. The user always knows the app is offline (banner) and which records have
   not yet reached the server (pending-sync badge). Sync is automatic — no
   manual buttons.

## Non-goals

- No custom local database or sync engine. Firestore's persistence layer *is*
  the offline store and the write queue.
- No offline support for student management, repositioning, institute/user
  edits, or account creation — these stay online-only (see write classes).
- No conflict resolution beyond last-write-wins. Per product decision, each
  student belongs to one teacher on one device and concurrent edits are
  practically nonexistent. Worst case (a supervisor repositions a student
  while the teacher's device is offline with a queued advancement) resolves
  last-write-wins; this is a documented, accepted limitation.
- No sync-queue management screen (can evolve later without rework).

## Decisions made during brainstorming

| Question | Decision |
| --- | --- |
| Offline write scope | Memorization/تلقين/سرد sessions + exams. Nothing else. |
| Conflict model | Last-write-wins; concurrent edits practically never happen. |
| Sync UX | Offline banner + per-record pending badge; silent automatic sync. |
| Admin "add institute" offline | Kept online-only in v1; isolated follow-up if ever needed. |

## Design

### 1. Foundations

- `main.dart` configures Firestore explicitly:
  `persistenceEnabled: true`, `cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED`.
  Today the app silently relies on platform defaults; unlimited cache stops
  Firestore's LRU eviction from dropping the curriculum catalog.
- The existing, currently-unused providers in
  `lib/shared/providers/connectivity_provider.dart` (`connectivityProvider`,
  `isConnectedProvider`) become the single source of truth for "are we
  online". No new connectivity plumbing.

### 2. Role-aware cache priming

New application service `OfflineCachePrimer` (`lib/data/services/`), run in
the background (a) after login / app start when online and (b) on every
offline→online transition. It performs ordinary Firestore reads so the
documents land in Firestore's own disk cache — no second storage layer.

What each role primes, in order of importance:

- **Teacher:** active students + their `users` docs; curriculum catalog
  (`levels`, plus `sessions` for every level any of their students is in *and
  the next level*, so an advancement crossing a level boundary resolves
  offline); per student the latest session record (carries the current home
  assignment) and recent history (last ~20 across `session_records` /
  `sard_records` / `exam_records`).
- **Supervisor:** their institutes' students + `users` docs; the exam queue
  (`getStudentsReadyForExam`); curriculum catalog as above; recent sard/exam
  records.
- **Admin:** institutes, users, and students lists.
- **Student / parent:** own student record, history, current assignment.

Priming is opportunistic: failures are silent, re-runs are cheap (Firestore
only downloads changed documents).

### 3. Offline-safe save path

The core change, touching `SessionRepository`, `StudentRepository`, and
`ActiveSessionNotifier` (`lib/features/teacher/providers/teacher_provider.dart`),
plus the supervisor exam save path.

- **One atomic batch per save.** `completeSession` / `completeTalqeenSession`
  currently issue two sequential awaited writes. Repositories are restructured
  to *prepare* writes; a single `WriteBatch` commits the session-record
  creation together with the student advancement (pass) or attempt increment
  (fail). On sync, both land or neither.
- **Never await server acknowledgement.** The batch is committed
  fire-and-forget (`unawaited(batch.commit())` with a `.catchError` log).
  Firestore applies it to the local cache instantly and queues it. The method
  returns the locally-built `SessionRecordModel` immediately: online, sync
  follows within milliseconds; offline, the teacher gets an instant "saved"
  and moves to the next student.
- **Reads in the save path are unchanged.** `advanceStudentSession`'s
  curriculum walk (`getSessionByOrderInLevel`, `getLevelByNumber`) and the
  student re-read are served from the warmed cache offline. Firestore's cache
  includes locally-pending writes, so back-to-back offline sessions for the
  same student see each other's advancement correctly.
- **Assessments get the same treatment:** `createSardRecord` /
  `createExamRecord` and any paired student update go through the same
  batch + no-await pattern (exams are saved from the **supervisor** feature).

### 4. Sync UX

- **Offline banner:** one shared widget mounted in the root app shell (all
  roles), shown when `isConnectedProvider` is false. Copy:
  "أنت غير متصل — سيتم الحفظ محليًا والمزامنة لاحقًا".
- **Pending badge:** record reads propagate
  `snapshot.metadata.hasPendingWrites` into an `isPendingSync` flag on the
  record models. History lists and the session-summary screen show a
  "بانتظار المزامنة" chip on unsynced records.
- **Badge clearing:** on the offline→online transition, invalidate the
  history/student providers so chips disappear promptly without user action.
- **Save confirmation copy** adapts to connectivity: "تم الحفظ" when online
  vs "تم الحفظ محليًا — ستتم المزامنة عند عودة الاتصال" when offline.

### 5. Write classification

One principle, three classes, consistent UX:

| Class | Examples | Behavior |
| --- | --- | --- |
| Offline-capable | Memorization/تلقين/سرد sessions (teacher); exams (supervisor) | Batched, no-await save; pending badge; automatic sync |
| Online-only by policy | Student management, repositioning, institute/user edits, add institute | Action gated on `isConnectedProvider` with "يتطلب اتصالًا بالإنترنت" |
| Online-only by necessity | Account creation (Cloud Function `createUserAccount`) | Same gating |

### 6. Offline guard rails

- **`.count()` aggregations always hit the server** and fail offline. The five
  call sites (`curriculum_repository.dart:163`; four in
  `session_repository.dart` — lines ~317, ~413, ~531, ~562) get try/catch:
  fall back to a cached-query count where the number matters offline, degrade
  gracefully (hide the stat) where it is cosmetic. Per-call-site decision
  happens during implementation planning.
- **Cold start offline:** Firebase Auth's cached credential + the existing
  Hive user-profile cache (`lib/data/services/session_cache.dart`) already
  admit a returning user without internet. First-ever login still requires
  connectivity — acceptable; install/login happens once, online.
- **Empty cache offline** (fresh install, never primed): screens show their
  existing error/empty states plus the offline banner. No crash.

### 7. Edge cases

- `FieldValue.serverTimestamp()` works offline (locally estimated, corrected
  on sync) — record ordering stays sane.
- Firestore's write queue survives app restarts and device reboots; nothing
  is lost if the teacher closes the app before syncing.
- Security-rules violations in queued writes surface only at sync time and
  the write is dropped by the server. Inherent to Approach A; mitigated by
  the fact that the offline-capable writes are the app's most exercised,
  rules-stable paths.
- `connectivity_plus` reports network availability, not true internet
  reachability. Acceptable for banner/gating purposes; Firestore itself is
  the authority on actual sync.

### 8. Testing

- **Domain/application:** unit tests with `fake_cloud_firestore` asserting the
  batched save — record + advancement land atomically on pass; record +
  attempt increment atomically on fail.
- **Repository:** tests asserting save methods return immediately without
  awaiting server ack (fake with a never-completing commit).
- **Widget:** banner appears/disappears with connectivity changes; pending
  chip renders when `hasPendingWrites`; gated buttons disabled offline with
  the correct message.
- **Manual verification matrix (airplane-mode run-through):** open app online
  → enable airplane mode → browse students/curriculum/history → run a
  memorization session and a سرد for two students → history shows pending
  chips → disable airplane mode → records visible in Firestore console,
  chips cleared, student positions advanced correctly.

## Changelog entry (stakeholder-facing)

> The app now works without internet at the institute — everyone can browse
> the latest data offline, teachers can run memorization sessions, supervisors
> can run exams, and everything syncs automatically when the connection
> returns.
