# Fast Startup via Optimistic Session Restore — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open a returning user's dashboard instantly from a locally cached session, refresh from Firestore in the background, and replace the blank white launch screen with a branded splash.

**Architecture:** `AuthRepository.build()` seeds `appUser` synchronously from a Hive-backed `SessionCache` so the router can route before any network call. `authStateChanges` (local, offline-capable) then triggers a background Firestore refresh that reconciles role/profile changes and hard-fails to `/login` on genuine auth loss. Routing keys off `appUser != null`; Firestore security rules remain the true data gate.

**Tech Stack:** Flutter, flutter_riverpod (Notifier), Hive, cloud_firestore, firebase_auth, go_router, flutter_native_splash. Tests: flutter_test, mocktail, fake_cloud_firestore.

## Global Constraints

- DDD / Clean Architecture per `CLAUDE.md`: domain has no framework deps; repository/infra details stay out of domain; behavior methods over setters.
- Ubiquitous language: `UserModel`, `SessionCache`, `role`.
- Brand color: `AppColors.primary` = `Color(0xFF1B5E20)`; background `Color(0xFFF5F5F5)` (`lib/core/constants/app_colors.dart`).
- Role string values are canonical: `super_admin`, `supervisor`, `teacher`, `student`, `guardian` (`UserRoleExtension`).
- TDD: failing test first, minimal impl, frequent commits.
- Commit style (user preference): one commit per workable milestone — each task ends in one commit.
- Cached data is profile-only (name/role/institute); never tokens or secrets.

## File Structure

- `lib/data/models/user_model.dart` — add framework-free `toJson()` / `fromJson()` (domain serialization for cache).
- `lib/data/services/session_cache.dart` — **new** infra: `SessionCache` wrapper over a Hive box + `sessionBoxProvider` / `sessionCacheProvider`.
- `lib/data/repositories/auth_repository.dart` — seed-from-cache in `build()`, background reconcile, cache writes on login/logout.
- `lib/shared/providers/user_provider.dart` — `isAuthenticatedProvider` keyed on `appUser != null`.
- `lib/core/constants/app_constants.dart` — add `boxSession` / `keyCachedUser` constants.
- `lib/main.dart` — open the Hive session box before `runApp`, parallelize local inits, override `sessionBoxProvider`.
- `pubspec.yaml` + `flutter_native_splash.yaml` — splash config.
- `assets/images/logo.png` (+ SVG source) — designed logo.
- Tests: `test/unit/models/user_model_json_test.dart`, `test/unit/services/session_cache_test.dart`, `test/unit/providers/auth_repository_test.dart`.

---

### Task 1: `UserModel` JSON serialization (domain)

**Files:**
- Modify: `lib/data/models/user_model.dart` (add `toJson`/`fromJson` after `toFirestore`, ~line 152)
- Test: `test/unit/models/user_model_json_test.dart`

**Interfaces:**
- Produces: `Map<String, dynamic> UserModel.toJson()` and `factory UserModel.fromJson(Map<String, dynamic> json)`. Dates are ISO-8601 strings; `id` is included; no `Timestamp` dependency.

- [ ] **Step 1: Write the failing test**

Create `test/unit/models/user_model_json_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';

void main() {
  test('UserModel survives a toJson/fromJson round-trip with all fields', () {
    final original = UserModel(
      id: 'user-123',
      username: 'ustadh',
      email: 'ustadh@alrasikhoon.local',
      phone: '0500000000',
      name: 'الأستاذ',
      role: UserRole.teacher,
      authProvider: UserAuthProvider.emailPassword,
      instituteId: 'inst-9',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime.utc(2026, 6, 7, 8, 9, 10),
      isActive: true,
    );

    final restored = UserModel.fromJson(original.toJson());

    expect(restored.id, 'user-123');
    expect(restored.username, 'ustadh');
    expect(restored.email, 'ustadh@alrasikhoon.local');
    expect(restored.phone, '0500000000');
    expect(restored.name, 'الأستاذ');
    expect(restored.role, UserRole.teacher);
    expect(restored.authProvider, UserAuthProvider.emailPassword);
    expect(restored.instituteId, 'inst-9');
    expect(restored.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(restored.updatedAt, DateTime.utc(2026, 6, 7, 8, 9, 10));
    expect(restored.isActive, true);
  });

  test('fromJson tolerates a null updatedAt and defaults isActive to true', () {
    final json = {
      'id': 'u1',
      'username': 's',
      'email': 's@x.local',
      'phone': null,
      'name': 'n',
      'role': 'student',
      'auth_provider': 'pending',
      'institute_id': null,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updated_at': null,
    };

    final user = UserModel.fromJson(json);

    expect(user.updatedAt, isNull);
    expect(user.isActive, true);
    expect(user.role, UserRole.student);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/models/user_model_json_test.dart`
Expected: FAIL — `The method 'fromJson' isn't defined for the type 'UserModel'`.

- [ ] **Step 3: Add `toJson`/`fromJson` to `UserModel`**

In `lib/data/models/user_model.dart`, immediately after the `toFirestore()` method (after line 152), add:

```dart
  /// Framework-free JSON for the local session cache. Unlike [toFirestore],
  /// this includes the [id] and uses ISO-8601 date strings (no Firestore
  /// Timestamp), so it round-trips through plain storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role.value,
      'auth_provider': authProvider.value,
      'institute_id': instituteId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      name: (json['name'] as String?) ?? '',
      role: UserRoleExtension.fromString((json['role'] as String?) ?? 'student'),
      authProvider: UserAuthProviderExtension.fromString(
        json['auth_provider'] as String?,
      ),
      instituteId: json['institute_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/models/user_model_json_test.dart`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/user_model.dart test/unit/models/user_model_json_test.dart
git commit -m "feat(user): add framework-free toJson/fromJson for session cache"
```

---

### Task 2: `SessionCache` infrastructure (Hive box wrapper)

**Files:**
- Modify: `lib/core/constants/app_constants.dart` (add two constants near the local-storage keys, ~line 78)
- Create: `lib/data/services/session_cache.dart`
- Test: `test/unit/services/session_cache_test.dart`

**Interfaces:**
- Consumes: `UserModel.toJson()` / `UserModel.fromJson()` (Task 1).
- Produces:
  - `class SessionCache` with `SessionCache(Box box)`, `UserModel? readUser()` (synchronous), `Future<void> cacheUser(UserModel user)`, `Future<void> clear()`.
  - `final sessionBoxProvider = Provider<Box>((ref) => throw UnimplementedError(...))` — overridden in `main()`.
  - `final sessionCacheProvider = Provider<SessionCache>((ref) => SessionCache(ref.watch(sessionBoxProvider)))`.
  - `AppConstants.boxSession = 'session'`, `AppConstants.keyCachedUser = 'current_user'`.

- [ ] **Step 1: Add constants**

In `lib/core/constants/app_constants.dart`, after the local storage keys block (after `keyFirstLaunch`, ~line 78), add:

```dart
  // Session cache (Hive)
  static const String boxSession = 'session';
  static const String keyCachedUser = 'current_user';
```

- [ ] **Step 2: Write the failing test**

Create `test/unit/services/session_cache_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:al_rasikhoon/core/constants/app_constants.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';

UserModel _user({String id = 'u1', UserRole role = UserRole.teacher}) {
  return UserModel(
    id: id,
    username: 'ustadh',
    email: 'u@x.local',
    name: 'الأستاذ',
    role: role,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  late Directory tempDir;
  late Box box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_cache_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox(AppConstants.boxSession);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('readUser returns null when nothing is cached', () {
    final cache = SessionCache(box);
    expect(cache.readUser(), isNull);
  });

  test('cacheUser then readUser round-trips the user', () async {
    final cache = SessionCache(box);
    await cache.cacheUser(_user(id: 'abc', role: UserRole.supervisor));

    final restored = cache.readUser();
    expect(restored, isNotNull);
    expect(restored!.id, 'abc');
    expect(restored.role, UserRole.supervisor);
  });

  test('clear removes the cached user', () async {
    final cache = SessionCache(box);
    await cache.cacheUser(_user());
    await cache.clear();
    expect(cache.readUser(), isNull);
  });

  test('readUser returns null on corrupt cached data', () async {
    await box.put(AppConstants.keyCachedUser, 'not-json');
    final cache = SessionCache(box);
    expect(cache.readUser(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/unit/services/session_cache_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../session_cache.dart'`.

- [ ] **Step 4: Create `SessionCache`**

Create `lib/data/services/session_cache.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Local, synchronous cache of the signed-in user's profile.
///
/// Backed by an already-open Hive box so [readUser] can run synchronously
/// during app boot (before the first frame). This is what lets the router
/// route a returning user optimistically, without waiting on Firestore.
class SessionCache {
  final Box _box;

  SessionCache(this._box);

  /// The cached user, or null if none is stored or the data is unreadable.
  UserModel? readUser() {
    final raw = _box.get(AppConstants.keyCachedUser);
    if (raw is! String) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUser(UserModel user) async {
    await _box.put(AppConstants.keyCachedUser, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _box.delete(AppConstants.keyCachedUser);
  }
}

/// Overridden in `main()` with the box opened before `runApp`.
final sessionBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('session box not opened');
});

final sessionCacheProvider = Provider<SessionCache>((ref) {
  return SessionCache(ref.watch(sessionBoxProvider));
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/unit/services/session_cache_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/app_constants.dart lib/data/services/session_cache.dart test/unit/services/session_cache_test.dart
git commit -m "feat(session): add Hive-backed SessionCache for optimistic startup"
```

---

### Task 3: `AuthRepository` seed-from-cache + background reconcile + routing signal

**Files:**
- Modify: `lib/data/repositories/auth_repository.dart`
- Modify: `lib/shared/providers/user_provider.dart:18-21` (`isAuthenticatedProvider`)
- Test: `test/unit/providers/auth_repository_test.dart`

**Interfaces:**
- Consumes: `SessionCache` (`readUser`/`cacheUser`/`clear`), `sessionCacheProvider` (Task 2); `FirebaseService.authStateChanges` (`Stream<User?>`), `FirebaseService.signOut()`; `UserRepository.getUserById`.
- Produces: `AuthRepository.build()` returns `AuthState(appUser: cachedUser)`; `isAuthenticatedProvider` returns `authState.appUser != null`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/providers/auth_repository_test.dart`:

```dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockSessionCache extends Mock implements SessionCache {}

class MockUser extends Mock implements User {}

UserModel _user({String id = 'u1', UserRole role = UserRole.teacher, bool isActive = true}) {
  return UserModel(
    id: id,
    username: 'ustadh',
    email: 'u@x.local',
    name: 'الأستاذ',
    role: role,
    isActive: isActive,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  late MockFirebaseService firebaseService;
  late MockUserRepository userRepository;
  late MockSessionCache sessionCache;
  late StreamController<User?> authStateController;

  setUp(() {
    firebaseService = MockFirebaseService();
    userRepository = MockUserRepository();
    sessionCache = MockSessionCache();
    authStateController = StreamController<User?>.broadcast();

    when(() => firebaseService.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
    when(() => firebaseService.signOut()).thenAnswer((_) async {});
    when(() => sessionCache.cacheUser(any())).thenAnswer((_) async {});
    when(() => sessionCache.clear()).thenAnswer((_) async {});
  });

  tearDown(() => authStateController.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        firebaseServiceProvider.overrideWithValue(firebaseService),
        userRepositoryProvider.overrideWithValue(userRepository),
        sessionCacheProvider.overrideWithValue(sessionCache),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('build seeds appUser from the cache (optimistic, no network)', () {
    when(() => sessionCache.readUser()).thenReturn(_user(role: UserRole.teacher));

    final container = makeContainer();
    final state = container.read(authRepositoryProvider);

    expect(state.appUser, isNotNull);
    expect(state.appUser!.role, UserRole.teacher);
    verifyNever(() => userRepository.getUserById(any()));
  });

  test('authStateChanges(null) clears the cache and resets state', () async {
    when(() => sessionCache.readUser()).thenReturn(_user());
    final container = makeContainer();
    container.read(authRepositoryProvider); // instantiate

    authStateController.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authRepositoryProvider).appUser, isNull);
    verify(() => sessionCache.clear()).called(1);
  });

  test('background refresh reconciles a changed role and re-caches', () async {
    when(() => sessionCache.readUser()).thenReturn(_user(role: UserRole.teacher));
    when(() => userRepository.getUserById('u1'))
        .thenAnswer((_) async => _user(role: UserRole.supervisor));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authRepositoryProvider).appUser!.role, UserRole.supervisor);
    verify(() => sessionCache.cacheUser(any())).called(1);
  });

  test('refresh finding a disabled account signs out', () async {
    when(() => sessionCache.readUser()).thenReturn(_user());
    when(() => userRepository.getUserById('u1'))
        .thenAnswer((_) async => _user(isActive: false));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    verify(() => firebaseService.signOut()).called(1);
    expect(container.read(authRepositoryProvider).appUser, isNull);
  });

  test('refresh failure keeps the cached optimistic state', () async {
    when(() => sessionCache.readUser()).thenReturn(_user(role: UserRole.teacher));
    when(() => userRepository.getUserById('u1')).thenThrow(Exception('offline'));
    final user = MockUser();
    when(() => user.uid).thenReturn('u1');

    final container = makeContainer();
    container.read(authRepositoryProvider);

    authStateController.add(user);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authRepositoryProvider).appUser!.role, UserRole.teacher);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/providers/auth_repository_test.dart`
Expected: FAIL — `build` still depends on `localStorageServiceProvider` (not overridden) and does not read `sessionCache`, so the container throws / assertions fail.

- [ ] **Step 3: Rewrite `AuthRepository` boot + reconcile path**

In `lib/data/repositories/auth_repository.dart`:

Replace the imports block (lines 1-8) — drop `local_storage_service.dart`, add `session_cache.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/session_cache.dart';
import '../../core/constants/app_constants.dart';
import 'user_repository.dart';
import '../models/user_model.dart';
```

Replace the fields + `build` + `_init` + `_loadAppUser` (lines 39-74) with:

```dart
  late final FirebaseService _firebaseService;
  late final UserRepository _userRepository;
  late final SessionCache _sessionCache;

  @override
  AuthState build() {
    _firebaseService = ref.watch(firebaseServiceProvider);
    _userRepository = ref.watch(userRepositoryProvider);
    _sessionCache = ref.watch(sessionCacheProvider);

    // Optimistic seed: route the returning user from the locally cached
    // profile before any network call. The authStateChanges listener below
    // refreshes and reconciles in the background.
    final cachedUser = _sessionCache.readUser();

    _init();

    return AuthState(appUser: cachedUser);
  }

  void _init() {
    _firebaseService.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(firebaseUser: user);
        // Fire-and-forget: never blocks the UI-visible state.
        _refreshAppUser(user.uid);
      } else {
        // Genuine auth loss (no persisted session or revoked): drop the
        // optimistic cache and fall back to login.
        _sessionCache.clear();
        state = const AuthState();
      }
    });
  }

  /// Background refresh + reconcile against Firestore. The server is the
  /// source of truth; a role/profile change updates state (and the router
  /// re-routes), a deleted/disabled account signs out, and an offline
  /// failure leaves the cached optimistic state intact.
  Future<void> _refreshAppUser(String uid) async {
    try {
      final appUser = await _userRepository.getUserById(uid);
      if (appUser == null || !appUser.isActive) {
        await signOut();
        return;
      }
      state = state.copyWith(appUser: appUser);
      await _sessionCache.cacheUser(appUser);
    } catch (_) {
      // Offline / transient: keep showing the cached profile.
    }
  }
```

In `signInWithUsernameAndPassword`, replace the two local-storage writes (lines 114-115):

```dart
      state = state.copyWith(isLoading: false, appUser: appUser);
      await _localStorage.setUserId(appUser.id);
      await _localStorage.setUserRole(appUser.role.value);
      return appUser;
```

with:

```dart
      state = state.copyWith(isLoading: false, appUser: appUser);
      await _sessionCache.cacheUser(appUser);
      return appUser;
```

Replace `signOut` (lines 142-146):

```dart
  Future<void> signOut() async {
    await _firebaseService.signOut();
    await _sessionCache.clear();
    state = const AuthState();
  }
```

Update the `isAuthenticated` getter (line 169-170) to the new routing signal:

```dart
  bool get isAuthenticated => state.appUser != null;
```

- [ ] **Step 4: Point the routing provider at `appUser`**

In `lib/shared/providers/user_provider.dart`, replace `isAuthenticatedProvider` (lines 18-21):

```dart
/// Provider to check if user is authenticated (routing signal).
///
/// Keyed on [appUser] alone — which is only ever populated by a prior real
/// login (cached) or a live Firestore load — so a returning user routes
/// optimistically without waiting on the Firebase session to re-restore.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  return authState.appUser != null;
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/unit/providers/auth_repository_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Verify nothing else broke**

Run: `flutter analyze lib/data/repositories/auth_repository.dart lib/shared/providers/user_provider.dart`
Expected: No errors (a warning about the now-unused `LocalStorageService` import elsewhere is not expected — this file no longer imports it).

- [ ] **Step 7: Commit**

```bash
git add lib/data/repositories/auth_repository.dart lib/shared/providers/user_provider.dart test/unit/providers/auth_repository_test.dart
git commit -m "feat(auth): seed session from cache and reconcile in background"
```

---

### Task 4: `main()` — open the session box before `runApp`, parallelize local inits

**Files:**
- Modify: `lib/main.dart:44-57`

**Interfaces:**
- Consumes: `sessionBoxProvider` (Task 2). Provides the opened `Box` via override so `AuthRepository.build()` can read it synchronously.

- [ ] **Step 1: Add the import**

In `lib/main.dart`, add alongside the other imports (after line 10):

```dart
import 'package:hive/hive.dart';
import 'data/services/session_cache.dart';
```

(`hive_flutter` is already imported for `Hive.initFlutter`; `hive` gives the `Box` type.)

- [ ] **Step 2: Replace the init + runApp block**

Replace lines 44-57 (`// Initialize Hive ...` through the end of `runApp(...)`) with:

```dart
  // Initialize Hive and open the session box BEFORE runApp so
  // AuthRepository.build() can read the cached user synchronously and route
  // the returning user before the first frame.
  await Hive.initFlutter();

  // The remaining local inits are independent — run them concurrently to
  // shrink the pre-first-frame window.
  final results = await Future.wait([
    Hive.openBox(AppConstants.boxSession),
    SharedPreferences.getInstance(),
  ]);
  final sessionBox = results[0] as Box;
  final sharedPreferences = results[1] as SharedPreferences;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionBoxProvider.overrideWithValue(sessionBox),
      ],
      child: const AlRasikhoonApp(),
    ),
  );
```

- [ ] **Step 3: Add the `AppConstants` import if missing**

Confirm `lib/main.dart` imports `AppConstants`. If not present, add:

```dart
import 'core/constants/app_constants.dart';
```

- [ ] **Step 4: Verify the app compiles and the suite is green**

Run: `flutter analyze lib/main.dart`
Expected: No errors.

Run: `flutter test`
Expected: PASS — full suite green (existing tests unaffected; new unit tests pass).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "perf(startup): open session box before runApp and parallelize local init"
```

---

### Task 5: Branded native splash + designed logo

**Files:**
- Create: `assets/branding/logo.svg` (editable source)
- Create: `assets/images/logo.png` (exported, ~1152×1152 transparent PNG)
- Create: `flutter_native_splash.yaml`
- Modify: `pubspec.yaml` (add `flutter_native_splash` dev dependency)

**Interfaces:** none (asset + native config only).

- [ ] **Step 1: Design the logo — CHECKPOINT (human approval required)**

Produce logo concept(s) for the الراسخون ("deeply-rooted") direction: a rootedness / firm-foundation motif combined with a Qur'anic / Arabic-calligraphic element, in brand green `#1B5E20` on transparent. Deliver an SVG source at `assets/branding/logo.svg`. **Present the concept(s) to the user and get explicit approval before proceeding.** If approval slips, fall back to a color-only splash (skip the logo `image:` line in Step 4).

- [ ] **Step 2: Export the PNG**

Export the approved SVG to `assets/images/logo.png` at ~1152×1152 with a transparent background (the size `flutter_native_splash` recommends for the center image). Any SVG→PNG tool (e.g. `rsvg-convert -w 1152 -h 1152 assets/branding/logo.svg -o assets/images/logo.png`).

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add --dev flutter_native_splash`
Expected: `pubspec.yaml` gains `flutter_native_splash:` under `dev_dependencies`; `flutter pub get` runs.

- [ ] **Step 4: Configure the splash**

Create `flutter_native_splash.yaml`:

```yaml
flutter_native_splash:
  color: "#1B5E20"
  image: assets/images/logo.png
  android_12:
    color: "#1B5E20"
    image: assets/images/logo.png
  fullscreen: true
  android: true
  ios: true
```

- [ ] **Step 5: Generate the native launch screens**

Run: `dart run flutter_native_splash:create`
Expected: Android (`launch_background.xml` / `values-v31`) and iOS `LaunchScreen.storyboard` assets regenerated with the brand color + logo. The white `@android:color/white` in `android/app/src/main/res/drawable/launch_background.xml` is replaced.

- [ ] **Step 6: Verify build**

Run: `flutter analyze`
Expected: No errors.

Run: `flutter build apk --debug` (or `flutter run` on a device/emulator)
Expected: Builds; on launch the splash shows brand green + logo instead of blank white, and a returning user lands on their dashboard without a white/login pause.

- [ ] **Step 7: Commit**

```bash
git add assets/branding/logo.svg assets/images/logo.png flutter_native_splash.yaml pubspec.yaml pubspec.lock android/ ios/
git commit -m "feat(splash): branded native launch screen with app logo"
```

---

## Manual verification (whole feature)

1. Log in as a teacher; fully close the app.
2. Turn the device to airplane mode (or throttle to Edge/2G) and cold-start.
   - **Expected:** brand splash → teacher dashboard **immediately**, no white pause, no `/login` flash.
3. Restore network; the dashboard content refreshes silently.
4. Server-side, change the user's role (or set `is_active: false`) and cold-start with network:
   - Role change → app re-routes to the new role's dashboard silently.
   - Disabled → app bounces to `/login`.
5. Sign out → cold-start:
   - **Expected:** goes to `/login` (cache cleared).

## Self-Review Notes

- **Spec coverage:** core mechanism (T3), reconciliation table incl. offline/disabled/deleted (T3 tests), layers domain/infra/application (T1/T2/T3), `main()` box-open + parallel init (T4), splash (T5), logo design with checkpoint (T5 Step 1), tests by layer (T1/T2/T3). All covered.
- **Type consistency:** `SessionCache.readUser/cacheUser/clear`, `sessionBoxProvider`, `sessionCacheProvider`, `UserModel.toJson/fromJson`, `AppConstants.boxSession/keyCachedUser` used identically across tasks.
- **Security:** routing keys on `appUser != null`; Firestore rules remain the data gate (unchanged); cache holds profile only.
