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
- Supervisor repointing a `session_records` / `sard_records` `student_id` to
  another institute → DENIED
- Supervisor in-institute record update / create → ALLOWED
- Supervisor write to an out-of-institute student → DENIED
- Student / record missing `institute_id` → fail-closed DENIED
- Supervisor in-institute student create → ALLOWED
