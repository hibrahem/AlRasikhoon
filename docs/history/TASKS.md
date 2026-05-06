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
| #2 | Verify 3 retry attempts logic for sessions | [x] | **VERIFIED + FIXED** - Tracking works. Added `hasReachedMaxAttempts` check and UI blocking |
| #3 | Verify Sard flow triggers after Session 34 | [x] | **VERIFIED** - Fully implemented with SardSessionScreen, proper routing, 3 attempts max |
| #4 | Verify grading calculation matches spec | [x] | **FIXED** - Corrected thresholds: راسخ(0), متقن(1-2), حافظ(3-4), مجتهد(5-6), محب(7+) |
| #5 | Verify curriculum data imported for all 10 levels | [x] | **VERIFIED** - All 1,453 sessions across 10 levels with verse info |

---

## High Priority - Missing MVP Features

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #6 | Implement student home practice tracking (التكرار في المنزل) | [x] | **IMPLEMENTED** - Added HomePracticeModel, repository, providers, and HomePracticeScreen |

---

## Medium Priority - Verification Tasks

| ID | Task | Status | Notes |
|----|------|--------|-------|
| #7 | Verify teacher institute selection for multi-institute | [x] | **PARTIAL** - AddStudentScreen has institute dropdown. No filter in TeacherStudentsScreen |
| #8 | Verify guardian role access and features | [x] | **PARTIAL + SECURITY GAP** - Role exists but no filtering to own children. See notes |
| #9 | Verify account not found flow for unregistered users | [x] | **VERIFIED** - Full implementation with dedicated screen and proper routing |

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
| #13 | Test end-to-end student flow | [ ] | Login → dashboard → practice → history |
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

1. ~~**Phase 1**: High-priority verifications (#1, #2, #3, #4, #5)~~ ✅ COMPLETE
2. ~~**Phase 2**: Missing MVP feature (#6 - Home practice tracking)~~ ✅ COMPLETE
3. **Phase 3**: End-to-end testing (#11, #12, #13, #14)
4. ~~**Phase 4**: Medium-priority verifications (#7, #8, #9)~~ ✅ COMPLETE
5. **Phase 5**: Offline support (#10) - can be deferred if not launch-critical

---

## Completed Tasks Log

| ID | Task | Completed Date | Notes |
|----|------|----------------|-------|
| #1 | Verify level locking UI in student view | 2026-01-30 | Was missing. Implemented LevelProgressionWidget with visual grid showing locked/unlocked/current/completed levels |
| BUG | Teachers can't login after admin creates them | 2026-01-30 | **Root cause**: Document ID mismatch (timestamp vs Firebase UID). **Fix**: Look up by phone if UID not found, then migrate document ID |
| #15 | Write test cases documentation | 2026-01-30 | Created TEST_CASES.md with 150+ comprehensive test cases |
| #16 | Implement unit tests | 2026-01-30 | Created unit tests for models (UserModel, StudentModel), utils (Validators, GradeCalculator), and repositories (UserRepository) |
| #17 | Implement E2E integration tests | 2026-01-30 | Created E2E tests with test helpers/robots for Admin, Teacher, Student, Supervisor flows |
| #2 | Verify 3 retry attempts logic | 2026-01-30 | Tracking implemented but enforcement missing. Added `hasReachedMaxAttempts`, `canStartSession`, and UI blocking in SessionOverviewScreen |
| #3 | Verify Sard flow triggers | 2026-01-30 | Fully implemented - Session 35 identified, SardSessionScreen exists, proper grading and advancement |
| #4 | Verify grading calculation | 2026-01-30 | **FIXED** thresholds in app_constants.dart and grade_calculator.dart. Updated tests to match spec |
| #5 | Verify curriculum data | 2026-01-30 | All 10 levels with 1,453 sessions verified. Proper verse ranges for all session types |
| #6 | Implement home practice tracking | 2026-01-30 | Created HomePracticeModel, HomePracticeRepository, providers, HomePracticeScreen, updated student dashboard and nav |
| #7 | Verify teacher multi-institute | 2026-01-30 | Partially implemented. AddStudentScreen has institute selection. TeacherStudentsScreen lacks filtering |
| #8 | Verify guardian role | 2026-01-30 | Partially implemented with security gap. Guardians route to student dashboard but can see ALL student data, not just their children |
| #9 | Verify account not found flow | 2026-01-30 | Fully implemented. AccountNotFoundScreen exists with proper routing and error handling |
| BUG | Student progress not showing from database | 2026-01-30 | **Root cause**: User migration didn't update student.user_id. **Fix**: Updated migration to also update student records, added fallback repair in getStudentByUserId |
| BUG | Home practice permission denied | 2026-01-30 | **Fix**: Added Firestore rules and indexes for home_practices collection |
| BUG | Pull to refresh not working | 2026-01-30 | **Fix**: Added Future.wait() to await provider reloads before hiding indicator |
| BUG | Missing bottom nav on home practice screen | 2026-01-30 | **Fix**: Added AppBottomNavBar to HomePracticeScreen |
| BUG | Session history showing raw ID | 2026-01-30 | **Fix**: Added levelId, hizbNumber, sessionNumber to SessionRecordModel, updated UI to show "الحلقة X" |
| FIX | Guardian data access security | 2026-01-30 | Added getStudentsByGuardianId, updated currentStudentProvider to filter for guardians |

---

## Known Issues / Future Improvements

### Security Issues
1. ~~**Guardian Data Access**: Guardians can read all student records instead of just their children.~~ **FIXED** - Added `getStudentsByGuardianId` and `getFirstStudentByGuardianId` methods. Updated `currentStudentProvider` to fetch guardian's children only.

### Missing Features (Non-blocking for MVP)
1. **Teacher Institute Filter**: TeacherStudentsScreen should have institute dropdown for teachers with multiple assignments
2. **Guardian Multi-child Support**: No UI for guardians to select between multiple children (provider `guardianChildrenProvider` added but UI not implemented)
3. **Offline Support**: Hive caching and sync queue not implemented

---

## Notes & Decisions

- Grading thresholds per spec: راسخ (0 errors), متقن (1-2), حافظ (3-4), مجتهد (5-6), محب (7+)
- Session flow: Sessions 1-34 (regular) → Session 35 (Sard) → Session 36 (Exam)
- Max retry attempts: 3 per session before blocking (enforcement added)
- Home practice: Students can self-report repetitions, track streak and stats
- Guardian role uses same dashboard as students (read-only view intended but not enforced)
