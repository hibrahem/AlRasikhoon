# AgDR-0004 — Supervisor multi-institute scoping via supervisor_institutes membership

> In the context of giving a supervisor full teacher parity (freely
> assigned/unassigned to institutes, and able to supervise SEVERAL at once),
> facing the single-institute assumption baked into AgDR-0003 (where
> `users/{uid}.institute_id` was the scalar source of truth), I decided to make
> **the `supervisor_institutes/{uid}_{instituteId}` membership docs the single
> source of truth** for supervisor scoping and authorization, to achieve a real
> many-to-many supervisor↔institute relationship, accepting that scoping checks
> now resolve a per-institute membership doc instead of reading one scalar.

## Context

- AgDR-0003 decided **one institute per supervisor**, with
  `users/{uid}.institute_id` as the canonical scalar and `supervisor_institutes`
  as a derived read-model. That premise is now retired: the product decision
  (al_rasikhoon-3n6) is that a supervisor has **teacher parity** — many
  institutes per supervisor, many supervisors per institute.
- The membership collection `supervisor_institutes/{uid}_{instituteId}` already
  existed (written by `createUserAccount` since #28, and by
  `assignSupervisorToInstitute` / `removeSupervisorFromInstitute`). It already
  models the many-to-many natively.
- Scoping is enforced in **both** Firestore rules and client providers, and the
  Cloud Functions (`createUserAccount`, `setUserPassword`). All three read the
  same source of truth or they can disagree.

## Decision

**The `supervisor_institutes` membership doc is THE source of truth.**
`users/{uid}.institute_id` is no longer authoritative for supervisor scoping.

- **Rules.** `supervisorInInstitute(instituteId)` replaces `callerInstituteId()`:
  a supervisor is scoped to institute `X` iff
  `supervisor_institutes/{uid}_{X}` exists **and** its `is_active == true`. The
  doc id is deterministic (`{uid}_{instituteId}`), so this is a single-doc lookup
  — **no collection query, no fan-out, no multi-hop read**. Both write-side and
  read-side supervisor helpers (`isSupervisorOfStudentInstitute`,
  `isSupervisorOfRecordStudent`) route through it, so read and write pick up
  multi-institute at once.
- **`is_active` matters.** `removeSupervisorFromInstitute` SOFT-deletes
  (`is_active:false`) rather than deleting the doc, so a bare `exists()` would
  keep granting a removed supervisor. Every check requires `is_active == true`.
- **Privilege boundary — THE escalation guard.** `supervisor_institutes` is
  **admin-write-only** (`create, update, delete: if isSuperAdmin()`). This is
  where the guard that used to freeze `users/{uid}.role`/`institute_id` for
  scoping now lives: if a supervisor could create
  `supervisor_institutes/{ownUid}_{anyInstitute}` — or flip `is_active` back to
  true on their own removed membership — they would self-grant that institute,
  the exact privilege escalation. `users/{uid}.role` remains frozen on
  self-update (self-promotion to `super_admin` is still blocked);
  `users/{uid}.institute_id` stays frozen too as belt-and-suspenders, but it is
  no longer the load-bearing boundary.
- **Cloud Functions.** `createUserAccount` and `setUserPassword` authorize a
  supervisor caller against their **membership set**
  (`supervisorInstituteIds(uid)` reads active memberships), not
  `users.institute_id`. `createUserAccount` still accepts an initial
  `instituteId` as a convenience and still writes both the membership doc and
  (legacy) `users.institute_id`.
- **Client.** `supervisorInstituteIdsProvider` exposes the SET (from
  `getInstitutesForSupervisor`); `supervisorStudentsProvider` UNIONS students
  across the set via `getStudentsForInstitutes`, which **chunks the Firestore
  `whereIn` at its 30-value cap**; teacher-pool providers are scoped to a single
  institute (the one a student belongs to / is created in), never a blur across
  the set.

## Consequences

- A supervisor can be assigned to any number of institutes and sees/acts on the
  union; removing a membership (soft-delete) immediately revokes that institute
  in rules, functions, and UI.
- Scoping now costs a single-doc membership read per check instead of a scalar
  field read; the deterministic doc id keeps it O(1) with no fan-out.
- `users/{uid}.institute_id` is **retained** (still used for non-supervisor
  purposes and as a legacy/convenience value on supervisor docs). **Dropping it
  is a separate, later, human-gated step**, only after confirming nothing reads
  it for scoping. Not done here.
- **Backfill (human-gated).** `scripts/backfill_supervisor_institutes.mjs`
  reconciles older supervisors whose legacy `institute_id` has no membership
  doc. It defaults to `--dry-run` (writes nothing), is idempotent, and must be
  run explicitly with `--write` by a human — it is NOT run as part of this
  change.

## Artifacts

- al_rasikhoon-3n6 (P1). Supersedes AgDR-0003.
- Rules + emulator tests: `firestore.rules`, `test/rules/firestore.rules.test.js`
  (escalation blocked, admin allowed, removed-supervisor denied despite stale
  `users.institute_id`, multi-institute allowed across the set / denied outside).
- Functions: `functions/src/index.ts` (`supervisorInstituteIds` helper).
- Client: `lib/features/supervisor/providers/supervisor_provider.dart`,
  `lib/data/repositories/student_repository.dart` (`getStudentsForInstitutes`).
