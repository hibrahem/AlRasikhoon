# User Profile Management & Password Reset — Design

**Issue:** al_rasikhoon-1nw · **Date:** 2026-07-17

## Problem

1. No user (admin, supervisor, teacher, student, guardian) can change their own
   profile (name, phone) or their own password.
2. The admin cannot reset a supervisor's or student's password from the admin
   screens, and cannot edit anyone's name/phone. (Teacher password reset by
   admin already exists.)

## Existing infrastructure (reused, not rebuilt)

- **Cloud Function `setUserPassword`** already authorizes: super_admin → any
  user; teacher → own students/guardians; supervisor → students/guardians in
  their institutes. No server changes needed for admin resets.
- **`ResetPasswordDialog`** (features/auth/widgets) already wired into: admin
  teacher detail, teacher students list, supervisor students list.
- **Firestore rules** already allow: super_admin updates any `users/{uid}` doc;
  a user updates their own doc with `role`/`institute_id` frozen.
- **Login model:** username + password over a synthesized email
  `<username>@alrasikhoon.local`. There is no real mailbox, so email-based
  password reset links are impossible — self-service password change must be
  reauth-with-current-password.

## Approaches considered

**Self password change**
- A (chosen): client-side `reauthenticateWithCredential` (synthesized email +
  current password) then `User.updatePassword`. No server change; proves
  knowledge of the current password; works for every role including admin.
- B: a self-reset Cloud Function — extra moving part, and would need to verify
  the current password manually. Rejected.
- C: email reset links — impossible with synthesized emails. Rejected.

**Profile edits (name, phone)**
- A (chosen): direct Firestore partial update via `UserRepository`; the rules
  already authorize both the self and super_admin paths.
- B: Cloud Function — unnecessary ceremony for fields the rules already govern.

## Design

### Rules fix (prerequisite)

`users` self-update currently compares
`request.resource.data.institute_id == resource.data.institute_id`. For docs
without an `institute_id` key (every teacher/student/guardian provisioned by
`createUserAccount`), the missing-key access errors and the branch denies.
Replace with the error-free idiom:

```
allow update: if isSuperAdmin() ||
  (request.auth.uid == userId &&
   !request.resource.data.diff(resource.data).affectedKeys()
     .hasAny(['role', 'institute_id']));
```

Covered by new cases in `test/rules/firestore.rules.test.js`.

### Data layer

- `UserRepository.updateProfileFields({userId, name, phone})` — targeted
  `update()` of `name`, `phone`, `updated_at` (server timestamp) only. A
  partial update keeps `role`/`institute_id` untouched so the frozen-fields
  rule passes for self-edits.

### Application layer (AuthRepository)

- `updateOwnProfile({name, phone})` — delegates to the repository, then
  reconciles `state.appUser` and the session cache so the UI reflects the new
  name immediately (same reconcile duty it already owns for sign-in).
- `changeOwnPassword({currentPassword, newPassword})` — reauthenticate with
  the synthesized email + current password, then `updatePassword`. Maps
  `wrong-password`/`invalid-credential` and `weak-password` to the existing
  Arabic error copy.

### UI

**Shared widgets** (features/auth/widgets, beside ResetPasswordDialog):
- `EditProfileDialog(user, onSave)` — name (required, `Validators.validateName`)
  + phone (optional, `AppPhoneField`, `formatPhoneWithCountryCode`), prefilled.
  Persistence is injected by the caller so the same dialog serves the
  self-service and admin flows.
- `ChangePasswordDialog` — current password, new password, confirm; calls
  `AuthRepository.changeOwnPassword`.

**Self-service** — `SettingsScreen` (الملف الشخصي; used by admin, supervisor,
teacher, and student shells):
- Edit affordance on the profile card → `EditProfileDialog` (writes via
  `updateOwnProfile`).
- A "تغيير كلمة المرور" action → `ChangePasswordDialog`.

**Admin**:
- `SupervisorDetailScreen`: AppBar gains lock-reset (existing
  `ResetPasswordDialog` — the CF already permits it) and edit-profile actions;
  invalidates supervisor providers on save.
- `TeacherDetailScreen`: AppBar gains edit-profile beside the existing reset;
  invalidates teacher providers on save.
- `AllStudentsScreen`: each row gains a menu with edit-profile and
  reset-password (targeting the student's linked user account), mirroring the
  teacher students list pattern.

Student names live only on `users/{uid}` (the `students` doc has no name
field), so a single write updates every surface.

## Error handling

- Dialogs stay open on failure and surface Arabic SnackBars (existing
  `ResetPasswordDialog` conventions: capture messenger/token colors before
  awaits, `context.mounted` guards).
- `changeOwnPassword` distinguishes wrong current password from weak new
  password from transient failures.

## Testing

- **Rules:** self-update of name/phone on a doc *without* `institute_id`
  (regression for the fix); self role-escalation still denied; super_admin
  update of another user's name allowed.
- **Unit:** `AuthRepository.changeOwnPassword` / `updateOwnProfile` (mocked
  FirebaseAuth/Firestore per existing unit-test patterns).
- **Widget:** dialog validation (empty name, password mismatch), settings
  screen affordances, supervisor detail new actions.

## Out of scope

- Changing username/email, role, or institute bindings.
- Password strength policy beyond the existing 6-char minimum.
- Guardian-specific admin screens (guardians have no admin detail screen today).
