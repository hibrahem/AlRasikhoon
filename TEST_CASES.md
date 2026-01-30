# Al Rasikhoon - Test Cases Documentation

Last updated: 2026-01-30

## Table of Contents
1. [Domain Models](#1-domain-models)
2. [Utility Functions](#2-utility-functions)
3. [Repositories](#3-repositories)
4. [Feature Business Logic](#4-feature-business-logic)
5. [State Management](#5-state-management)
6. [Edge Cases](#6-edge-cases)
7. [Integration Scenarios](#7-integration-scenarios)
8. [Test Structure](#8-test-structure)

---

## 1. Domain Models

### 1.1 UserModel Tests
**File**: `lib/data/models/user_model.dart`

| Test Case | Description |
|-----------|-------------|
| `test_fromString_converts_valid_role_strings` | Test all role conversions (super_admin, supervisor, teacher, student, guardian) |
| `test_fromString_defaults_to_student_for_invalid_role` | Invalid role strings default to student |
| `test_value_property_returns_correct_string` | Role enum returns correct string value |
| `test_nameAr_and_nameEn_return_correct_translations` | Arabic and English role names |
| `test_toFirestore_returns_valid_map` | Serialization to Firestore format |
| `test_fromFirestore_deserializes_all_fields` | Deserialization from Firestore |
| `test_fromFirestore_handles_missing_optional_fields` | Handles null timestamps, etc. |
| `test_copyWith_updates_single_field` | CopyWith preserves other fields |
| `test_equality_based_on_id_only` | Two users with same ID are equal |

### 1.2 StudentModel Tests
**File**: `lib/data/models/student_model.dart`

| Test Case | Description |
|-----------|-------------|
| `test_levelProgressPercentage_at_session_1` | 0% progress at session 1 |
| `test_levelProgressPercentage_at_session_18` | ~50% progress at session 18 |
| `test_levelProgressPercentage_at_session_35` | ~97% progress at session 35 |
| `test_canTakeSard_true_only_at_session_35` | Sard only at session 35 |
| `test_canTakeSard_false_at_other_sessions` | Sard unavailable otherwise |
| `test_canTakeExam_true_only_at_session_36` | Exam only at session 36 |
| `test_default_level_is_1` | New student starts at level 1 |
| `test_default_juz_is_30` | New student starts at juz 30 |
| `test_default_hizb_is_59` | New student starts at hizb 59 |
| `test_default_session_is_1` | New student starts at session 1 |
| `test_default_attempt_is_1` | New student starts at attempt 1 |
| `test_default_unlocked_levels_contains_only_1` | Only level 1 unlocked initially |
| `test_default_completed_levels_is_empty` | No completed levels initially |

### 1.3 SessionModel Tests
**File**: `lib/data/models/session_model.dart`

| Test Case | Description |
|-----------|-------------|
| `test_empty_quran_content_has_isEmpty_true` | Empty QuranContent detection |
| `test_same_surah_range_formatting_ar` | "الفاتحة 1-7" format |
| `test_cross_surah_range_formatting_ar` | "البقرة 1 - آل عمران 10" format |
| `test_isSard_true_only_for_sard_type` | Session type detection |
| `test_isExam_true_only_for_exam_type` | Session type detection |
| `test_titleAr_sard_session_includes_hizb` | "سرد الحزب X" format |
| `test_titleAr_exam_session_includes_hizb` | "اختبار الحزب X" format |

### 1.4 SessionGrades Tests
**File**: `lib/data/models/session_record_model.dart`

| Test Case | Description |
|-----------|-------------|
| `test_totalErrors_sum_all_three_parts` | Sum of part1 + part2 + part3 errors |
| `test_allPartsPassed_true_when_each_part_lte_3` | All parts ≤3 errors = pass |
| `test_allPartsPassed_false_when_part1_exceeds_3` | Part1 >3 errors = fail |
| `test_allPartsPassed_false_when_part2_exceeds_3` | Part2 >3 errors = fail |
| `test_allPartsPassed_false_when_part3_exceeds_3` | Part3 >3 errors = fail |
| `test_zero_errors_all_parts_pass` | 0+0+0 = pass |
| `test_3_errors_each_part_all_pass` | 3+3+3 = pass (boundary) |
| `test_4_errors_in_one_part_fails` | 4+0+0 = fail (boundary) |

### 1.5 InstituteModel & LevelModel Tests

| Test Case | Description |
|-----------|-------------|
| `test_institute_active_by_default` | New institutes are active |
| `test_institute_soft_delete` | Soft delete sets is_active=false |
| `test_level_1_contains_juz_30_29_28` | Level 1 covers correct juz range |
| `test_level_contains_correct_hizb_count` | Each level has 6 hizbs |
| `test_juzRangeAr_formatting` | "الجزء 30-28" format |

---

## 2. Utility Functions

### 2.1 Validators Tests
**File**: `lib/core/utils/validators.dart`

| Test Case | Description |
|-----------|-------------|
| `test_validatePhone_rejects_empty` | Empty phone rejected |
| `test_validatePhone_accepts_9_digits_saudi` | "5xxxxxxxx" accepted |
| `test_validatePhone_removes_leading_zero` | "05xxx" → "5xxx" |
| `test_validatePhone_rejects_8_digits` | Too short rejected |
| `test_validatePhone_rejects_non_numeric` | Letters rejected |
| `test_validateOtp_requires_6_digits` | Exactly 6 digits required |
| `test_validateOtp_rejects_5_digits` | Too short rejected |
| `test_validateOtp_rejects_alphabetic` | Letters rejected |
| `test_validateName_rejects_empty` | Empty name rejected |
| `test_validateName_requires_min_2_chars` | Minimum length enforced |
| `test_validateErrorCount_accepts_0` | Zero errors valid |
| `test_validateErrorCount_accepts_positive` | Positive integers valid |
| `test_validateErrorCount_rejects_negative` | Negative numbers rejected |

### 2.2 GradeCalculator Tests
**File**: `lib/core/utils/grade_calculator.dart`

| Test Case | Description |
|-----------|-------------|
| `test_0_errors_returns_rasikh_5_stars` | راسخ grade |
| `test_1_error_returns_mutqin_4_stars` | متقن grade |
| `test_2_errors_returns_hafiz_3_stars` | حافظ grade |
| `test_3_errors_returns_mujtahid_2_stars` | مجتهد grade |
| `test_4_errors_returns_muhib_1_star_fail` | محب grade (fail) |
| `test_isPassed_true_for_0_to_3_errors` | Pass threshold |
| `test_isPassed_false_for_4_plus_errors` | Fail threshold |
| `test_getGradeNameAr_returns_arabic` | Arabic grade names |
| `test_getGradeNameEn_returns_english` | English grade names |
| `test_getStars_returns_correct_count` | 1-5 stars mapping |
| `test_calculateSessionGrade_all_parts_pass` | Combined grade calculation |
| `test_calculateSessionGrade_one_part_fails` | Fail overrides grade |

---

## 3. Repositories

### 3.1 AuthRepository Tests
**File**: `lib/data/repositories/auth_repository.dart`

| Test Case | Description |
|-----------|-------------|
| `test_sendOtp_starts_loading_state` | Loading state set |
| `test_sendOtp_with_valid_phone_succeeds` | OTP sent successfully |
| `test_sendOtp_sets_verification_id` | Verification ID stored |
| `test_sendOtp_invalid_phone_error` | "رقم الجوال غير صحيح" |
| `test_sendOtp_too_many_requests_error` | Rate limit message |
| `test_verifyOtp_fails_without_verification_id` | Requires prior sendOtp |
| `test_verifyOtp_valid_code_signs_in` | Successful auth |
| `test_verifyOtp_invalid_code_fails` | Wrong OTP rejected |
| `test_signIn_finds_user_by_firebase_uid` | Primary lookup method |
| `test_signIn_finds_user_by_phone_fallback` | Fallback for migration |
| `test_signIn_migrates_user_to_firebase_uid` | Document ID migration |
| `test_signIn_account_not_found_for_unregistered` | Unregistered user error |
| `test_signOut_clears_state` | Auth state cleared |
| `test_signOut_clears_local_storage` | Persisted data cleared |

### 3.2 StudentRepository Tests
**File**: `lib/data/repositories/student_repository.dart`

| Test Case | Description |
|-----------|-------------|
| `test_createStudent_creates_user_and_student` | Both records created |
| `test_createStudent_creates_guardian_if_not_exists` | Guardian auto-creation |
| `test_createStudent_reuses_existing_guardian` | Guardian lookup by phone |
| `test_getStudentsForTeacher_returns_active_only` | Excludes inactive |
| `test_getStudentsForTeacher_ordered_by_date` | Sorted descending |
| `test_getStudentsReadyForExam_session_36_only` | Exam queue filter |
| `test_advanceSession_increments_1_to_2` | Normal progression |
| `test_advanceSession_wraps_36_to_1_new_hizb` | Hizb transition |
| `test_advanceSession_resets_attempt_to_1` | Attempt reset on pass |
| `test_advanceSession_unlocks_next_level` | Level unlock logic |
| `test_advanceSession_prevents_past_level_10` | Max level enforced |
| `test_incrementAttempt_caps_at_max` | Max 3 attempts |

### 3.3 SessionRepository Tests
**File**: `lib/data/repositories/session_repository.dart`

| Test Case | Description |
|-----------|-------------|
| `test_createSessionRecord_all_parts_pass` | Passed flag set correctly |
| `test_createSessionRecord_one_part_fail` | Passed flag false |
| `test_createSessionRecord_stores_attempt` | Attempt number recorded |
| `test_getSessionRecordsForStudent_ordered` | Descending date order |
| `test_getSessionRecordsForStudent_limit` | Pagination works |
| `test_getAttemptCount_returns_correct` | Counts previous attempts |
| `test_createSardRecord_grade_calculation` | Single error count grade |
| `test_createExamRecord_includes_supervisor` | Supervisor ID stored |

### 3.4 UserRepository Tests
**File**: `lib/data/repositories/user_repository.dart`

| Test Case | Description |
|-----------|-------------|
| `test_createUser_stores_all_fields` | Complete data persisted |
| `test_getUserById_returns_correct` | ID lookup works |
| `test_getUserByPhone_searches_correctly` | Phone lookup works |
| `test_migrateUserToFirebaseUid_creates_new_doc` | New document created |
| `test_migrateUserToFirebaseUid_deletes_old_doc` | Old document removed |
| `test_migrateUserToFirebaseUid_same_id_noop` | No action if same ID |
| `test_getUsersByRole_filters` | Role-based filtering |

---

## 4. Feature Business Logic

### 4.1 Session Grading Rules

| Test Case | Description |
|-----------|-------------|
| `test_session_0_errors_each_part_passes` | Perfect session |
| `test_session_3_errors_each_part_passes` | Boundary pass |
| `test_session_4_errors_part1_fails` | Single part fail |
| `test_session_4_errors_part2_fails` | Single part fail |
| `test_session_4_errors_part3_fails` | Single part fail |
| `test_session_grade_name_and_stars` | Grade display |

### 4.2 Attempt Limiting Rules

| Test Case | Description |
|-----------|-------------|
| `test_retry_allowed_attempt_2` | Second attempt allowed |
| `test_retry_allowed_attempt_3` | Third attempt allowed |
| `test_blocked_after_3_failed_attempts` | No more retries |
| `test_attempt_resets_on_success` | Counter reset |

### 4.3 Level Progression Rules

| Test Case | Description |
|-----------|-------------|
| `test_level_1_starts_unlocked` | Initial state |
| `test_level_2_locked_until_level_1_complete` | Sequential unlock |
| `test_cannot_skip_levels` | No level skipping |
| `test_all_10_levels_chain` | Full progression |

### 4.4 Sard & Exam Rules

| Test Case | Description |
|-----------|-------------|
| `test_sard_available_only_session_35` | Sard restriction |
| `test_sard_0_errors_passes` | Sard pass threshold |
| `test_sard_4_errors_fails` | Sard fail threshold |
| `test_exam_available_only_session_36` | Exam restriction |
| `test_exam_forwarded_to_supervisor` | Supervisor handles exam |
| `test_passed_exam_advances_level` | Level progression |

---

## 5. State Management

### 5.1 Student Provider Tests

| Test Case | Description |
|-----------|-------------|
| `test_currentStudentProvider_returns_student` | Logged in student |
| `test_studentStatsProvider_calculates_stats` | Dashboard statistics |
| `test_studentStatsProvider_pass_rate` | Pass rate calculation |
| `test_studentStatsProvider_isLevelLocked` | Level status check |
| `test_studentStatsProvider_isLevelCompleted` | Completion check |

### 5.2 Teacher Provider Tests

| Test Case | Description |
|-----------|-------------|
| `test_teacherStudentsProvider_returns_assigned` | Teacher's students |
| `test_activeSessionState_tracks_errors` | Error count tracking |
| `test_activeSessionState_allPartsPassed` | Pass detection |
| `test_completeSession_advances_on_pass` | Progression |
| `test_completeSession_increments_on_fail` | Attempt increment |

### 5.3 Supervisor Provider Tests

| Test Case | Description |
|-----------|-------------|
| `test_examQueueProvider_returns_ready` | Session 36 students |
| `test_supervisorStatsProvider_pending_count` | Queue count |
| `test_supervisorStatsProvider_today_stats` | Daily statistics |

---

## 6. Edge Cases

### 6.1 Session Progression Edge Cases

| Test Case | Description |
|-----------|-------------|
| `test_cannot_advance_past_level_10` | Max level boundary |
| `test_hizb_order_reverses_through_levels` | Backward through Quran |
| `test_juz_progression_matches_level` | Juz/level consistency |
| `test_session_36_to_level_advance` | Level transition |

### 6.2 Grading Edge Cases

| Test Case | Description |
|-----------|-------------|
| `test_grade_boundary_0_errors` | Exact boundary |
| `test_grade_boundary_3_errors` | Pass/fail boundary |
| `test_grade_boundary_4_errors` | Fail boundary |
| `test_uneven_part_errors` | Mixed error counts |

### 6.3 Multi-Institute Scenarios

| Test Case | Description |
|-----------|-------------|
| `test_teacher_multiple_institutes` | Teacher assignment |
| `test_supervisor_multiple_institutes` | Supervisor scope |
| `test_student_single_institute` | Student constraint |

---

## 7. Integration Scenarios

### 7.1 Complete Student Journey

```
1. Unregistered user → Account not found
2. Registered student login → Dashboard level 1
3. Teacher records pass → Session 2
4. Teacher records fail → Attempt increments
5. Complete level 1 → Level 2 unlocks
6. Session 35 → Sard available
7. Sard pass → Session 36
8. Exam queue → Supervisor sees student
9. Exam pass → Level 2 begins
```

### 7.2 Complete Teacher Journey

```
1. Admin creates teacher
2. Admin assigns to institute
3. Teacher login → See students
4. Teacher adds student
5. Teacher records session
6. Teacher records sard (session 35)
7. Exam forwarded to supervisor
```

### 7.3 Complete Admin Journey

```
1. Super Admin login
2. Create institute
3. Create teacher
4. Assign teacher to institute
5. View curriculum
6. View dashboard stats
7. Edit institute
8. Remove teacher
```

---

## 8. Test Structure

### Directory Structure

```
test/
├── unit/
│   ├── data/
│   │   ├── models/
│   │   │   ├── user_model_test.dart
│   │   │   ├── student_model_test.dart
│   │   │   ├── session_model_test.dart
│   │   │   ├── session_record_model_test.dart
│   │   │   ├── institute_model_test.dart
│   │   │   └── level_model_test.dart
│   │   └── repositories/
│   │       ├── auth_repository_test.dart
│   │       ├── student_repository_test.dart
│   │       ├── session_repository_test.dart
│   │       ├── curriculum_repository_test.dart
│   │       ├── institute_repository_test.dart
│   │       └── user_repository_test.dart
│   └── core/
│       └── utils/
│           ├── validators_test.dart
│           └── grade_calculator_test.dart
├── widget/
│   ├── auth/
│   ├── student/
│   ├── teacher/
│   ├── supervisor/
│   └── admin/
└── integration/
    ├── auth_flow_test.dart
    ├── student_journey_test.dart
    ├── teacher_journey_test.dart
    ├── supervisor_journey_test.dart
    └── admin_journey_test.dart
```

### Testing Tools

- **Unit Tests**: `flutter_test` package
- **Mocking**: `mocktail` for Firebase mocking
- **Widget Tests**: `testWidgets()` with `WidgetTester`
- **Integration**: Full app flow tests

### Coverage Goals

- **Domain Models**: 100% coverage
- **Repositories**: 90% coverage
- **Providers**: 85% coverage
- **Widgets**: 70% coverage
- **Overall**: 80% minimum

---

## Critical Business Rules Summary

| Rule | Description |
|------|-------------|
| Session Order | Sessions 1-36 must be completed in order |
| Hizb Progression | After session 36, move to previous hizb |
| Level Unlock | Next level unlocks only after completing all hizbs |
| Part Pass | Each of 3 parts must have ≤3 errors to pass |
| Sard Session | Only at session 35, single error count |
| Exam Session | Only at session 36, supervisor handles |
| Max Attempts | 3 attempts per session/sard/exam |
| Grade Thresholds | 0=راسخ, 1-2=متقن, 3=حافظ, 4+=محب |
| Soft Deletes | Inactive records remain in DB |
| User Migration | First login migrates doc ID to Firebase UID |
