# Firestore security-rules tests

Emulator-backed unit tests for `firestore.rules`, covering the privilege-boundary
findings from Shield's security review of PR #35 (#28 supervisor scoping).

## Run

```bash
cd test/rules
npm install
npm test          # firebase emulators:exec --only firestore  → mocha
```

Requires `firebase-tools` and a JDK (the Firestore emulator runs on the JVM).

## Coverage

- Supervisor self-promote to `super_admin` → DENIED
- Supervisor changing own `institute_id` → DENIED
- Supervisor editing other profile fields on own doc → ALLOWED
- SuperAdmin changing any user's role/institute → ALLOWED
- Supervisor repointing a `session_records` `student_id` to another institute → DENIED
- Supervisor in-institute session_record update / create → ALLOWED
- Supervisor write to an out-of-institute student → DENIED
- Student / record missing `institute_id` → fail-closed DENIED
- Supervisor in-institute student create → ALLOWED
- Teacher creating / updating a `sard_records` doc → ALLOWED (سرد is teacher-conducted, al_rasikhoon-801)
- Supervisor creating / updating a `sard_records` doc → DENIED, even in-institute
- Supervisor listing their OWN `exam_records` by `supervisor_id` (home stats / سجل queries, incl. date range) → ALLOWED (al_rasikhoon-or1)
- Teacher listing / `count()`-ing their OWN `session_records` by `teacher_id` (profile stats) → ALLOWED (al_rasikhoon-or1)
- Author-scoped queries for ANOTHER author's uid, or unfiltered sweeps → DENIED (al_rasikhoon-or1)
