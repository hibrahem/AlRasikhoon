# Al Rasikhoon - Implementation Tasks

Last updated: 2026-01-30

## Task Status Legend
- [ ] Pending
- [~] In Progress
- [x] Completed
- [-] Skipped/Deferred

---

## High Priority - Verification Tasks

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #1 | Verify level locking UI in student view | [x] | **IMPLEMENTED** - Added LevelProgressionWidget to dashboard |
| #2 | Verify 3 retry attempts logic for sessions | [ ] | Check `currentAttempt` field usage, max 3 retries |
| #3 | Verify Sard flow triggers after Session 34 | [ ] | Session 35 should auto-trigger after 34 |
| #4 | Verify grading calculation matches spec | [ ] | راسخ(0), متقن(1-2), حافظ(3-4), مجتهد(5-6), محب(7+) |
| #5 | Verify curriculum data imported for all 10 levels | [ ] | All sessions with proper verse/page definitions |

---

## High Priority - Missing MVP Features

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #6 | Implement student home practice tracking (التكرار في المنزل) | [ ] | Self-reporting UI for home repetitions |

---

## Medium Priority - Verification Tasks

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #7 | Verify teacher institute selection for multi-institute | [ ] | UI for teachers with multiple assignments |
| #8 | Verify guardian role access and features | [ ] | Read-only access to children's progress |
| #9 | Verify account not found flow for unregistered users | [ ] | Proper error screen vs generic error |

---

## Medium Priority - Missing Features

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #10 | Implement offline support with sync queue | [ ] | Hive caching, sync queue, status indicator |

---

## Testing Tasks - Manual End-to-End Flows

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #11 | Test end-to-end admin flow | [ ] | Login → dashboard → institutes → curriculum |
| #12 | Test end-to-end teacher flow | [ ] | Login → students → session → grading |
| #13 | Test end-to-end student flow | [ ] | Login → dashboard → progress → history |
| #14 | Test supervisor exam flow | [ ] | Login → queue → exam → results |

---

## Automated Testing Tasks

| ID | Task | Status | Blocked By | Notes |
|----|------|--------|------------|-------|
| #15 | Write test cases documentation | [x] | - | Created TEST_CASES.md with 150+ test cases |
| #16 | Implement unit tests | [x] | #15 | Created tests for UserModel, StudentModel, Validators, GradeCalculator, UserRepository |
| #17 | Implement E2E integration tests | [x] | #16 | Created E2E tests for Admin, Teacher, Student, Supervisor flows |

---

## Execution Order

1. **Phase 1**: High-priority verifications (#1, #2, #3, #4, #5)
2. **Phase 2**: Missing MVP feature (#6 - Home practice tracking)
3. **Phase 3**: End-to-end testing (#11, #12, #13, #14)
4. **Phase 4**: Medium-priority verifications (#7, #8, #9)
5. **Phase 5**: Offline support (#10) - can be deferred if not launch-critical

---

## Completed Tasks Log

| ID | Task | Completed Date | Notes |
|----|------|----------------|-------|
| #1 | Verify level locking UI in student view | 2026-01-30 | Was missing. Implemented LevelProgressionWidget with visual grid showing locked/unlocked/current/completed levels |
| BUG | Teachers can't login after admin creates them | 2026-01-30 | **Root cause**: Document ID mismatch (timestamp vs Firebase UID). **Fix**: Look up by phone if UID not found, then migrate document ID |
| #15 | Write test cases documentation | 2026-01-30 | Created TEST_CASES.md with 150+ comprehensive test cases |
| #16 | Implement unit tests | 2026-01-30 | Created unit tests for models (UserModel, StudentModel), utils (Validators, GradeCalculator), and repositories (UserRepository) |
| #17 | Implement E2E integration tests | 2026-01-30 | Created E2E tests with test helpers/robots for Admin, Teacher, Student, and Supervisor flows |

---

## Notes & Decisions

- Grading thresholds per spec: راسخ (0 errors), متقن (1-2), حافظ (3-4), مجتهد (5-6), محب (7+)
- Session flow: Sessions 1-34 (regular) → Session 35 (Sard) → Session 36 (Exam)
- Max retry attempts: 3 per session before level lock
