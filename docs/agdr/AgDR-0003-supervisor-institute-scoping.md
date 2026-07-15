# AgDR-0003 — Canonical source of truth for supervisor institute scoping

> **⚠️ SUPERSEDED by [AgDR-0004](./AgDR-0004-supervisor-multi-institute-membership.md) (al_rasikhoon-3n6).**
> The core premise below — "one institute per supervisor", with
> `users/{uid}.institute_id` as the single scalar source of truth — no longer
> holds. Supervisors now have teacher parity: freely assigned/unassigned to
> institutes and may supervise SEVERAL at once. The source of truth moved to the
> `supervisor_institutes/{uid}_{instituteId}` membership docs (admin-write-only).
> This document is retained for history; read AgDR-0004 for the current model.

> In the context of enforcing that a supervisor can only act within their institute (issue #28, epic #26), facing two places that store a supervisor's institute after #27 (`users/{uid}.institute_id` and the `supervisor_institutes/{uid}_{instituteId}` join doc), I decided to make **`users/{uid}.institute_id` the single canonical source of truth** for scoping/authorization and treat `supervisor_institutes` as a **derived read-model**, to achieve simple, cheap, drift-free permission checks, accepting that the derived doc must be kept in sync by a single writer.

## Context

- Confirmed scope decision (epic #26): **one institute per supervisor**, multiple supervisors per institute. A supervisor's institute is therefore a single scalar value, not a set.
- #27 (PR #33, merged) persists the institute in **two** places, written atomically in one batch by the `createUserAccount` Cloud Function:
  - `users/{uid}.institute_id` — scalar on the account doc (loaded with the user).
  - `supervisor_institutes/{uid}_{instituteId}` — a join doc the **existing** supervisor experience already reads (`getInstitutesForSupervisor` → `examQueueProvider` / `supervisorStatsProvider`).
- #28 must enforce scoping in **both** Firestore security rules and client providers. It needs one authoritative field to check against, or the two stores can drift and rules/UI could disagree (the exact risk Rex flagged on #33).

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **A. `users.institute_id` = SoT; join doc = derived read-model** (chosen) | One scalar, already loaded with the user → rules do a single `get(/users/$uid)` with no extra query; matches one-institute-per-supervisor exactly; cheapest + simplest checks | Two stores to keep in sync; any future reassignment must update both |
| B. `supervisor_institutes` join doc = SoT | Models many-to-many natively; existing supervisor queries already read it | Over-models a 1:1 fact; rules need a collection `get`/query (more complex, extra read); `users.institute_id` becomes redundant/ambiguous |
| C. Keep only one store (drop the other) | No drift | Breaks an existing consumer (supervisor experience reads the join doc) OR forces rules to do collection queries; net worse than A |

## Decision

Chosen: **Option A.** `users/{uid}.institute_id` is the **canonical** institute for a supervisor and the field all scoping/authorization (Firestore rules + client provider filters) reads. `supervisor_institutes` is a **derived projection** maintained from the canonical field, used only by the pre-existing supervisor-experience queries that already expect it.

Rules for #28 (and beyond):
- **Read scoping from `users/{uid}.institute_id`.** Do not authorize off the join doc.
- **Single writer**: `supervisor_institutes` is written only alongside `users.institute_id`, atomically (as `createUserAccount` already does). Never written independently.
- If supervisor reassignment is ever added, it updates `users.institute_id` and re-derives the join doc in the same transaction.
- Student records a supervisor manages should carry/inherit an `institute_id` so rules can compare `student.institute_id == supervisor users.institute_id` without multi-hop reads (denormalize onto student docs — flagged for #28).

## Consequences

- #28 enforces teacher-parity student management filtered by the supervisor's `users.institute_id`, in both rules and providers; a supervisor cannot read/write outside it.
- The two stores stay consistent because only the create path (and any future reassign path) writes them together — no independent writer.
- Slight denormalization cost (institute stored on the user and projected to the join doc, and to be denormalized onto student docs) accepted for read/rule simplicity.
- #29 (Sard gating) layers on top: supervisor-only + same institute scope, reading the same canonical field.

### Accepted risk / follow-up — read scoping is client-side only (Shield finding #3, MEDIUM)

The security review of PR #35 flagged that all collections currently use `allow read: if isAuthenticated()` — write paths are institute-scoped in the rules, but **reads are not**. Any authenticated user can read any student / record document via a direct SDK query; institute filtering on reads happens only in the client providers.

**Accepted for now.** Per-document read-scoping in security rules (e.g. gating `students`/`session_records`/`sard_records` reads on `resource.data.institute_id == callerInstituteId()`) is **deferred to a follow-up ticket**. Rationale: it is a larger change (touches every read path and the existing query shapes / indexes, and the existing supervisor-experience queries assume open reads), it is independent of the write-side privilege boundaries this PR closes, and the data is not externally exposed beyond authenticated app users. Current posture: **authenticated-read + client-side institute filtering**; the hardened write rules (findings #1/#2) prevent cross-institute mutation regardless. A separate ticket should add rule-level read scoping and re-validate the affected indexes.

The two write-side BLOCKING findings (#1 self-promote / institute self-change; #2 record repoint to another institute) ARE fixed in this PR and covered by emulator rules tests in `test/rules/`.

## Artifacts

- Issue #28 (hibrahem/AlRasikhoon), epic #26.
- Builds on #27 / PR #33 (merge `6054be7`) which introduced both stores.
- Supersedes the ambiguity Rex flagged in the PR #33 review.
