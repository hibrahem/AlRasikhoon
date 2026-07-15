# Fast Startup via Optimistic Session Restore — Design

**Date:** 2026-07-15
**Status:** Approved for planning
**Author:** brainstormed with Claude

## Problem

Cold start is slow and shows a blank white screen "stuck for long sometimes."
The delay is intermittent and correlates with network quality.

Root cause (traced, not guessed):

1. **The native launch screen is blank white.**
   `android/app/src/main/res/drawable/launch_background.xml` is
   `@android:color/white` — no logo, no spinner. Anything that delays the first
   Flutter frame is perceived as "stuck on white."

2. **Routing a returning user is gated on a live network round-trip.**
   - The router's `initialLocation` is `/login`.
   - `isAuthenticatedProvider` requires `firebaseUser != null && appUser != null`.
   - `appUser` is only populated after `AuthRepository._loadAppUser()` runs a
     **live Firestore fetch** (`UserRepository.getUserById` → `.doc(uid).get()`).
   - So a returning, already-logged-in user cannot be routed to their dashboard
     until that Firestore `.get()` returns. On slow/flaky networks it blocks for
     seconds. **The first screen cannot resolve without a network reply.**

3. **The session cache is half-built.**
   `LocalStorageService.setUserId` / `setUserRole` are written at login but
   **never read at startup**. `getUserId()` / `getUserRole()` exist and are never
   called on the boot path. Every cold start re-pays the full
   Firebase-Auth-restore + Firestore-fetch cost.

## Goal

Open the correct screen **immediately** from a locally cached session, then
refresh from Firestore **in the background** and reconcile. Respect the project's
DDD / Clean Architecture rules. Keep the server as the real security gate.

## Non-Goals

- Changing Firestore security rules (they remain the true backstop).
- Encrypting cached profile data (no secrets/tokens are cached).
- Offline-first for feature data beyond what Firestore's own cache already gives.

---

## Design

### 1. Core mechanism — seed from cache, verify in background

Remove the Firestore fetch from the critical path:

- **Seed `appUser` synchronously in `AuthRepository.build()`** from the session
  cache. If a cached user exists, `appUser` is populated *before the first frame*.
- **Change the routing signal to `appUser != null`.** `appUser` is only ever
  non-null because of a prior real login (cached) or a live load, so it is a
  sufficient routing signal. The real Firebase session is validated by the
  background reconcile, not by blocking the UI.
- **`_loadAppUser` moves fully to the background.** `authStateChanges` emits the
  restored Firebase user from local persistence (offline-capable, no network).
  On emission we refresh the profile from Firestore, update the cache, and
  reconcile.

Result: a returning user lands on their dashboard shell instantly, with zero
network dependency on the boot path.

### 2. Reconciliation (trust model)

The background `authStateChanges` + refresh handles every disagreement between
cache and server:

| Situation | Behavior |
|-----------|----------|
| Role or profile changed | State updates → router re-routes / UI re-renders silently to the fresh truth |
| `authStateChanges` emits `null` (session revoked) | Sign out, clear cache → `/login` (hard fail) |
| Refreshed `isActive == false` (account disabled) | Sign out, clear cache → `/login` (hard fail) |
| User doc missing on refresh (account deleted) | Sign out, clear cache → `/login` (hard fail) |
| Refresh fails (offline) | Keep showing cached UI; Firestore rules still guard all data |

**Why safe:** the cached role only decides *which shell renders*. Every actual
data read is enforced server-side by Firestore security rules. A stale or
tampered cache can at worst show an empty/erroring shell for a moment until
reconcile bounces the user. Cached data is name/role/institute only — no secrets;
the Firebase auth token stays in its own secure storage.

### 3. Layers (DDD / Clean Architecture)

**Domain — `UserModel`**
- Add framework-free `toJson()` / `fromJson()`:
  - Includes `id`.
  - ISO-8601 strings for dates (no `Timestamp` / Firestore dependency — this
    *reduces* coupling relative to the existing `toFirestore`).
- Existing `fromFirestore` / `toFirestore` unchanged.

**Infrastructure — `SessionCache` (new)**
- Thin wrapper around a Hive box named `session`.
- API:
  - `Future<void> cacheUser(UserModel user)` — stores `user.toJson()`.
  - `UserModel? readUser()` — **synchronous** read from the already-open box.
  - `Future<void> clear()` — removes the cached user.
- Provider-injected (`sessionCacheProvider`).
- Requires the box to be opened in `main()` before `runApp` (see §4).

**Application — `AuthRepository`**
- `build()`:
  - Reads `sessionCache.readUser()` synchronously and seeds initial
    `AuthState(appUser: cachedUser)` (optimistic).
  - Starts `_init()` (the `authStateChanges` listener) as today.
- `_init()` listener:
  - `user != null` → set `firebaseUser`; run `_refreshAppUser(user.uid)` in the
    background (no `await` blocking any UI-visible state).
  - `user == null` → clear state **and** `sessionCache.clear()` → `/login`.
- `_refreshAppUser(uid)`:
  - Fetch from Firestore. On success: update state, `sessionCache.cacheUser`,
    reconcile role. If `isActive == false` → sign out. If doc missing → sign out.
  - On failure (offline): keep existing (cached) state.
- `signOut()` / login success paths also call `sessionCache` so the cache stays
  authoritative for the *next* boot.
- The now-redundant `LocalStorageService.setUserId` / `setUserRole` calls are
  removed (superseded by `SessionCache`). `clearUserData` semantics preserved via
  `SessionCache.clear()`.

**Providers**
- `isAuthenticatedProvider` → `appUser != null`.
- Audit other usages of `isAuthenticatedProvider` during implementation (expected
  to be router-only; semantics barely change since `appUser` only exists after a
  real login).

### 4. `main()` startup

Open the Hive session box before `runApp`, and parallelize the independent local
inits:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
await FirebaseEmulatorConfig.configureEmulators();
await Hive.initFlutter();
await Future.wait([
  Hive.openBox('session'),
  SharedPreferences.getInstance(),
]);
```

(`SharedPreferences.getInstance()` result is captured for the existing provider
override.) The box being open before `runApp` is what lets
`AuthRepository.build()` read it synchronously.

### 5. Native splash

- Add `flutter_native_splash`, configured with the brand color + a logo, and
  regenerate Android + iOS launch screens (replaces the blank white).

### 6. Logo design (new asset)

No logo asset exists yet (`assets/images` holds only `.gitkeep`). As part of this
work, design an app logo:

- **Concept direction:** الراسخون — "the deeply-rooted." A Qur'an-memorization
  app. Visual motif: rootedness / firm foundation combined with a Qur'anic /
  Arabic-calligraphic element, in the app's brand color (from `AppTheme`).
- **Deliverable:** an SVG source (editable, in-repo) exported to PNG at the
  resolutions `flutter_native_splash` needs.
- **Checkpoint:** logo concept(s) presented for approval **before** wiring into
  the splash. Splash color-only fallback is available if the logo slips.

---

## Testing (by layer)

- **Domain:** `UserModel.toJson()` / `fromJson()` round-trip preserves all fields
  incl. `id` and dates.
- **Infrastructure:** `SessionCache.cacheUser` then `readUser` round-trips;
  `clear()` empties it; `readUser()` on an empty box returns `null`.
- **Application (`AuthRepository`, mocked deps):**
  - `build()` seeds `appUser` from a populated cache.
  - `authStateChanges(null)` clears cache and state.
  - background refresh with a changed role updates state.
  - refreshed `isActive == false` → signs out + clears cache.
  - refresh failure (offline) keeps cached state.
- **Routing (widget/integration, optional):** with a seeded cache, a returning
  user resolves to their role dashboard without awaiting a Firestore fetch.

## Risks & Mitigations

- **Stale cached role briefly shown** → mitigated by immediate background
  reconcile + Firestore rules as the true gate.
- **`isAuthenticatedProvider` semantics change** → audit usages; behavior is
  effectively unchanged because `appUser` implies a prior real login.
- **Hive box not open when `build()` reads it** → box opened in `main()` before
  `runApp`; add a defensive null-return if absent.

## Open Inputs

- Brand color value from `AppTheme` (read during implementation).
- Logo concept approval (checkpoint during implementation).
