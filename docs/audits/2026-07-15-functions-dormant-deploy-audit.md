# Audit — dormant `functions/src` changes shipped unexercised on 2026-07-14

- **Issue:** `al_rasikhoon-fh2`
- **Root cause:** `al_rasikhoon-vep` (stale-deploy), related `al_rasikhoon-5j2` (missing post-deploy verification)
- **Date:** 2026-07-15
- **Author:** automated audit (Claude Opus 4.8)

> **This document does not touch production.** It is a written audit plus a
> manual verification checklist for the maintainer. Exercising production
> **remains a maintainer step** — see [Manual production-verification checklist](#manual-production-verification-checklist).

## What happened

`firebase deploy --only functions` ships whatever sits in the compiled
`functions/lib` on the deploying machine. Until 2026-07-14, `firebase.json` had
**no predeploy build hook**, so every deploy re-shipped a `lib` last built on
**2026-05-10**. TypeScript source (`functions/src`) was correct; the deployed
JavaScript was not. Three `functions/src` changes merged between 2026-05-10 and
2026-07-14 were therefore **never live**, then all went out **at once and
unexercised** when the predeploy hook was added and the function was redeployed
on 2026-07-14.

The dormant window is not cosmetic: the entire `createUserAccount` callable was
**new** in the earliest dormant commit, so for ~2 months it **did not exist in
production**. Any client build that called it received `NOT_FOUND` / `internal`.
This is what surfaced as `al_rasikhoon-vep` ("Super admin cannot create a
supervisor").

The three dormant commits (oldest → newest), all touching `functions/src/index.ts`:

| Commit | Date | Title |
| --- | --- | --- |
| `0645309` | 2026-05-10 | fix(auth): admin/teacher account creation no longer evicts caller session |
| `6054be7` | 2026-05-24 | feat(#27): admin create-supervisor flow (institute-bound account creation) |
| `51c0dcb` | 2026-05-24 | feat(#28): supervisor permission model + institute scoping |

All three land inside two Gen-2 callables: **`createUserAccount`** and
**`setUserPassword`** (region `us-central1`). A third export, `syncRoleClaim`
(a `users/{uid}` Firestore trigger that mirrors `role` into an Auth custom
claim), was already live and is unchanged by these commits — but note the
authorization in the callables **depends** on that claim.

---

## Per-commit analysis

### 1. `0645309` — server-side account provisioning (`createUserAccount` introduced)

**What the `functions/src` change did.** Added the brand-new `createUserAccount`
`onCall` handler (`functions/src/index.ts:73`). It creates a Firebase Auth user
**and** writes the `users/{uid}` Firestore profile in one server call, rolling
back the Auth user if the Firestore write fails. It replaces the client's
`createUserWithEmailAndPassword`, which auto-signs-in the new user and was
silently evicting the admin/teacher caller's session.

- **Callable affected:** `createUserAccount` (new).
- **Authorization matrix** (`ROLES_BY_CALLER`, `functions/src/index.ts:33`), keyed
  off the caller's `role` custom claim:
  - `super_admin` → may provision `teacher | student | guardian`
  - `teacher` → may provision `student | guardian`
- **Data writes:** `users/{uid}` with `username` (normalized lower-case), `email`,
  `name` (trimmed), `role`, `phone ?? null`, `auth_provider: "email_password"`,
  `is_active: true`, `created_at: serverTimestamp()`. Pre-checks username
  uniqueness (`already-exists / username-taken`). Maps auth errors to
  `email-already-in-use`, `invalid-email`, `weak-password`.
- **Client flow it powers:** `FirebaseService.provisionUserAccount`
  (`lib/data/services/firebase_service.dart:57`) → **Add Teacher** screen
  (`lib/features/admin/screens/add_teacher_screen.dart:78`) and
  **Add Student / guardian** (`lib/data/repositories/student_repository.dart:179,216`).

**Dormancy impact.** For ~2 months the callable **did not exist** in production.
Depending on which client build was in users' hands:
- If a client that calls `provisionUserAccount` was released → **all admin/teacher
  account creation failed** (missing function).
- If the pre-change client was still in the field → the **caller-session eviction
  bug the commit fixes was still occurring**.
Either way, the intended behavior was not live. It became live only on 2026-07-14.

**Risk rating: HIGH.** New authorization surface + new data-write path, both
touching account creation, unexercised in prod for two months and then switched
on wholesale. Authorization here fails **closed** (a missing/wrong claim →
`permission-denied`), which is safe, but the data-write shape (`users/{uid}`
fields above) must match what the client and Firestore rules expect or accounts
are created **silently malformed**.

### 2. `6054be7` — supervisor provisioning (institute-bound) inside `createUserAccount`

**What the `functions/src` change did.** Extended `createUserAccount` to
provision `role: "supervisor"`:
- Added `supervisor` to `super_admin`'s allowed set (`ROLES_BY_CALLER`,
  `functions/src/index.ts:33`).
- Requires a non-empty `instituteId` for supervisors, and validates the institute
  exists and is not `is_active === false` (`institute-not-found`,
  `functions/src/index.ts:157`).
- Writes `users/{uid}.institute_id`, **and** an atomic **batch** that also writes
  `supervisor_institutes/{uid}_{instituteId}`
  (`supervisor_id`, `institute_id`, `assigned_at`, `is_active`) so the existing
  `getInstitutesForSupervisor()` read resolves the binding
  (`functions/src/index.ts:213`). Auth-user rollback still covers a batch failure.

- **Callable affected:** `createUserAccount`.
- **Client flow it powers:** **Add Supervisor** screen
  (`lib/features/admin/screens/add_supervisor_screen.dart:98`), which passes a
  required `instituteId`.

**Dormancy impact.** This is the exact failure captured in `al_rasikhoon-vep`:
production ran the pre-`6054be7` matrix (no `supervisor` in `super_admin`'s set),
so create-supervisor returned `permission-denied: "Caller role 'super_admin'
cannot provision role 'supervisor'"`. The whole admin create-supervisor flow was
blocked for its entire existence until 2026-07-14.

**Risk rating: HIGH.** Adds a new authorized role to account creation **and** a
two-document atomic write (`users` + `supervisor_institutes`). If either the
`institutes` doc shape (`is_active`) or the `supervisor_institutes` shape drifts
from what the client reader expects, a created supervisor is either rejected or
resolves to **no institutes** (silently broken supervisor experience).

### 3. `51c0dcb` — supervisor-as-caller permission model (`createUserAccount` + `setUserPassword`)

**What the `functions/src` change did.** Two authorization extensions, giving a
supervisor teacher-parity student management **scoped to their own institute**:

1. **`createUserAccount`** — added `supervisor → {student, guardian}` to
   `ROLES_BY_CALLER` (`functions/src/index.ts:33`), gated on the supervisor caller
   having a bound `users/{caller}.institute_id`; otherwise
   `permission-denied: supervisor-has-no-institute` (`functions/src/index.ts:132`).
2. **`setUserPassword`** — added a `supervisor` branch
   (`functions/src/index.ts:360`): a supervisor may reset a **student/guardian**
   password only if that user belongs to a `students` doc whose `institute_id`
   equals the supervisor's own `institute_id` (guardian reached via
   `guardian_id`, student via `user_id`). Anything else → `permission-denied`.

- **Callables affected:** `createUserAccount`, `setUserPassword`.
- **Client flows it powers:** supervisor **Add Student** (`asSupervisor` mode) and
  the supervisor detail screen's password reset
  (`lib/data/repositories/auth_repository.dart:152`,
  `lib/features/auth/widgets/reset_password_dialog.dart`).

> **Note — the sibling firestore.rules changes deploy separately.** This commit
> also tightened `firestore.rules` (supervisor self-promotion denied, record
> repoint denied, missing `institute_id` fail-closed). **Firestore rules are NOT
> affected by the `functions/lib` staleness** — `firebase deploy` ships rules
> independently of the compiled functions artifact. Whether the rules half went
> live on its own merge is outside this audit's scope; the callable half was
> dormant with the rest of `lib`. Verifying the rules are live is worth a
> separate check (see checklist step 7).

**Risk rating: MEDIUM–HIGH.** Pure authorization changes that fail **closed**
(dormant → supervisors simply could not provision students or reset passwords;
no data was corrupted and nothing was over-permissioned). That caps the blast
radius versus commit 1/2. Rated up to HIGH because the `setUserPassword`
supervisor branch is a **cross-collection ownership check** (`students` filtered
by `institute_id` + `user_id`/`guardian_id`): if a `students` doc lacks
`institute_id` (pre-migration docs — the commit explicitly defers the backfill),
the check fails closed and a legitimate supervisor **cannot** reset a real
student's password. That is a latent correctness gap to confirm, not a security
hole.

---

## Manual production-verification checklist

These changes went live **unexercised**. Run the following against production
(maintainer step — the audit did not). Each authorization/data-write path is
called out because those failed closed (or silently wrong) for ~2 months.

Setup: have a `super_admin` account, one `teacher` account, and at least one
`is_active` institute with a supervisor bound to it. Watch
`firebase functions:log` (or `functions_get_logs`) alongside each step —
`createUserAccount` and `setUserPassword` emit structured `logger.info` lines on
success.

1. **Admin creates a teacher (data-write + no session eviction).**
   Sign in as `super_admin` → Add Teacher → submit valid details.
   - Expected: success; **you remain signed in as the admin** (no eviction).
   - Verify the new `users/{uid}` doc has `role: "teacher"`, `is_active: true`,
     `auth_provider: "email_password"`, lower-cased `username`, and `created_at`.
   - Confirm the new teacher's Auth custom claim becomes `{"role":"teacher"}`
     (via `syncRoleClaim`) within a few seconds.

2. **Admin creates a student and a guardian.** Same screen/flow for a student
   (and its guardian). Confirm both `users/{uid}` docs are well-formed and the
   admin session survives.

3. **Teacher creates a student (authorization: teacher → student).**
   Sign in as `teacher` → create a student.
   - Expected: success. Then confirm a teacher **cannot** create a teacher or
     supervisor (should be `permission-denied`).

4. **Admin creates a supervisor (the `al_rasikhoon-vep` flow — authorization +
   two-doc atomic write).** Sign in as `super_admin` → Add Supervisor → pick an
   institute → submit.
   - Expected: success (**not** `permission-denied`).
   - Verify `users/{uid}` has `role: "supervisor"` **and** `institute_id`.
   - Verify `supervisor_institutes/{uid}_{instituteId}` exists with
     `is_active: true`.
   - Negative: try an invalid/inactive `instituteId` → expect
     `institute-not-found`; omit institute → `invalid-argument`.

5. **Supervisor creates a student (authorization: supervisor → student, institute
   scoping).** Sign in as the bound supervisor → Add Student (`asSupervisor`).
   - Expected: success; the created student carries the supervisor's
     `institute_id`.
   - Negative: a supervisor with **no** bound institute must get
     `permission-denied: supervisor-has-no-institute`.

6. **Supervisor resets a student/guardian password (cross-collection ownership —
   the latent-bug hot spot).** As the supervisor, reset a password for a student
   **in their institute**.
   - Expected: success.
   - **Critical negatives:** resetting a student in **another** institute →
     `permission-denied`; resetting a `teacher`/`super_admin` → `permission-denied`.
   - **Watch for the pre-migration gap:** if resetting a *legitimate* in-institute
     student fails with `permission-denied`, that student's `students` doc is
     likely missing `institute_id` (the deferred backfill). That is a data gap,
     not a rules failure — see follow-ups.

7. **Confirm the sibling `firestore.rules` for `51c0dcb` are actually live.**
   Independently of functions, confirm a supervisor **cannot** self-promote
   (`role: "super_admin"`) or change their own `institute_id`, and cannot repoint
   a `session_records`/`sard_records` `student_id` across institutes. (These are
   rules, not functions, but they are the security half of the same feature and
   should be verified while you are here.)

8. **Regression sweep of the two callables.** Because the whole `lib` shipped at
   once, smoke-test any other path through `createUserAccount` / `setUserPassword`
   your app exercises (admin/teacher password resets) to confirm nothing else in
   the two-month backlog regressed.

---

## Risk summary

| Commit | Callable(s) | Nature | Failure mode while dormant | Risk |
| --- | --- | --- | --- | --- |
| `0645309` | `createUserAccount` (new) | New authz + `users/{uid}` write | Account creation broken **or** caller-session eviction unfixed | **HIGH** |
| `6054be7` | `createUserAccount` | New role + 2-doc atomic write | Create-supervisor blocked (`al_rasikhoon-vep`) | **HIGH** |
| `51c0dcb` | `createUserAccount`, `setUserPassword` | Supervisor authz + institute scoping | Supervisors could not provision/reset (fail-closed) | **MED–HIGH** |

## Prevention

The predeploy hook in `firebase.json` (`cd "$RESOURCE_DIR" && ./node_modules/.bin/tsc`)
now rebuilds before every deploy. This audit adds an **independent freshness
check**, `functions/scripts/verify-build-fresh.sh`
(npm: `npm run verify:build-fresh`), which rebuilds and fails if the compiled
`lib` differs from a clean build of `src`. See
[`functions/scripts/README.md`](../../functions/scripts/README.md) for wiring it
into CI and the deploy flow. It closes the "nothing verifies deployed functions
match HEAD" gap called out by `al_rasikhoon-fh2` and `al_rasikhoon-5j2`.
