/// Test scaffolding for E2E tests that run against the Firebase Emulator
/// instead of `fake_cloud_firestore`.
///
/// Why a separate helper from `test_app.dart`:
/// - `test_app.dart` swaps `FirebaseFirestore` for an in-memory fake. Useful for
///   speed but never exercises real serialization, query semantics, or rules.
/// - This helper keeps the real `cloud_firestore` client and points it at the
///   Firestore emulator, so reads/writes hit the same SDK code path as prod.
/// - Auth is still faked via `_TestAuthRepository` because driving the Auth
///   emulator from a UI test is out of scope for this E2E sweep.
///
/// Prerequisites for running tests that import this helper:
///   1. `firebase emulators:start --only firestore,auth`
///   2. `flutter test integration_test/firebase_emulator_flow_test.dart -d IOS_SIM_ID`
///      (iOS simulator + macOS reach the emulator at `localhost`. Android
///      emulator needs `--dart-define=EMULATOR_HOST=10.0.2.2`.)
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/firebase_options.dart';
import 'package:al_rasikhoon/l10n/app_localizations.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

const String _projectId = 'alrasikhoon-57151';

/// Host for reaching the emulator. iOS simulator + macOS use `localhost`;
/// Android emulator needs `10.0.2.2`. Override via `--dart-define=EMULATOR_HOST=...`.
String get _emulatorHost {
  const String override = String.fromEnvironment('EMULATOR_HOST');
  if (override.isNotEmpty) return override;
  return 'localhost';
}

bool _firebaseInitialized = false;

/// One-time Firebase init + emulator wiring. Call from `setUpAll`.
///
/// `useFirestoreEmulator` / `useAuthEmulator` must run before any
/// Firebase call, and only once per process — calling them twice throws.
///
/// We point Auth at the emulator too because the production `firestore.rules`
/// require `isAuthenticated()` for almost every read and `isSuperAdmin()` for
/// most writes. With no Auth token attached, every seed write fails with
/// `permission-denied`. Anonymous sign-in into the Auth emulator is enough
/// to give the SDK a valid token; we then promote that token's UID to
/// super_admin in the `users` collection so seeding can proceed.
Future<void> initEmulatorFirebase() async {
  if (_firebaseInitialized) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  _firebaseInitialized = true;
}

/// Wipes every document in the Firestore emulator for this project.
///
/// Uses the emulator's admin REST endpoint, which bypasses security rules.
/// Without this, tests leak state into each other.
Future<void> clearEmulatorFirestore() async {
  await _emulatorDelete(
    'http://$_emulatorHost:8080/emulator/v1/projects/$_projectId/databases/(default)/documents',
  );
}

/// Wipes every account in the Auth emulator for this project.
///
/// Without this, anonymous sign-ins from previous tests stick around and the
/// `users` collection ends up with stale role rows from prior runs.
Future<void> clearEmulatorAuth() async {
  await _emulatorDelete(
    'http://$_emulatorHost:9099/emulator/v1/projects/$_projectId/accounts',
  );
}

Future<void> _emulatorDelete(String url) async {
  final client = HttpClient();
  try {
    final req = await client.deleteUrl(Uri.parse(url));
    final resp = await req.close();
    await resp.drain<void>();
    if (resp.statusCode != 200) {
      throw StateError('Emulator DELETE $url returned HTTP ${resp.statusCode}');
    }
  } finally {
    client.close();
  }
}

/// Mirror of `TestApp` from `test_app.dart`, but without the fake Firestore.
/// Real `firestoreProvider` / `firebaseServiceProvider` defaults are used so
/// the app talks to the emulator-backed `FirebaseFirestore.instance`.
class EmulatorTestApp extends StatelessWidget {
  final List<dynamic> overrides;

  const EmulatorTestApp({super.key, this.overrides = const []});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: const _EmulatorTestAppContent(),
    );
  }
}

class _EmulatorTestAppContent extends ConsumerWidget {
  const _EmulatorTestAppContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'الراسخون - Emulator E2E',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
  }
}

/// Per-test environment for emulator-backed E2E. Counterpart of
/// `TestEnvironment` in `test_app.dart` for the fake-Firestore world.
class EmulatorTestEnvironment {
  late SharedPreferences sharedPreferences;
  late List<dynamic> overrides;

  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Clears the emulator, signs in the given user via faked auth, and seeds
  /// the curriculum data the dashboard reads on first paint.
  ///
  /// To satisfy `firestore.rules`, this also signs in anonymously to the Auth
  /// emulator and writes a `super_admin` role row at the anon UID. That gives
  /// every subsequent seed write a valid auth token AND a privileged role,
  /// without changing the role the *app* sees in Riverpod (which still maps
  /// to `authenticatedUser`).
  Future<void> setUp({UserModel? authenticatedUser}) async {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await FirebaseAuth.instance.signOut();

    final cred = await FirebaseAuth.instance.signInAnonymously();
    final anonUid = cred.user!.uid;
    // The user doc create rule allows `request.auth.uid == userId`, so this
    // first write goes through even before the role check is in place.
    await firestore.collection('users').doc(anonUid).set({
      'email': 'seed@test.local',
      'name': 'Seed Admin',
      'phone': '+966500000000',
      'role': 'super_admin',
      'created_at': Timestamp.now(),
    });

    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    overrides = <dynamic>[
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      // The default `firebaseServiceProvider` would build a service against
      // real `FirebaseAuth.instance`. The instance is now connected to the
      // Auth emulator, so we could pass it through — but the app's auth
      // listeners would react to our seed-time anonymous sign-in. Keeping a
      // mock auth here isolates the app's auth state from the seed UID.
      firebaseServiceProvider.overrideWithValue(
        _EmulatorFirebaseService(firestore: firestore),
      ),
    ];

    if (authenticatedUser != null) {
      await _setupAuthenticatedUser(authenticatedUser);
    } else {
      _setupUnauthenticatedState();
    }

    await _seedCurriculumData();
  }

  void _setupUnauthenticatedState() {
    overrides.addAll([
      authRepositoryProvider.overrideWith(_TestAuthRepository.new),
      currentUserProvider.overrideWith((ref) => null),
      isAuthenticatedProvider.overrideWith((ref) => false),
      currentUserRoleProvider.overrideWith((ref) => null),
    ]);
  }

  Future<void> _setupAuthenticatedUser(UserModel user) async {
    await firestore.collection('users').doc(user.id).set(user.toFirestore());
    await sharedPreferences.setString('user_id', user.id);
    await sharedPreferences.setString('user_role', user.role.value);

    overrides.addAll([
      authRepositoryProvider.overrideWith(
        () => _TestAuthRepository(appUser: user),
      ),
      currentUserProvider.overrideWith((ref) => user),
      isAuthenticatedProvider.overrideWith((ref) => true),
      currentUserRoleProvider.overrideWith((ref) => user.role),
    ]);
  }

  UserModel createStudent({
    String id = 'student_emu_id',
    String name = 'طالب الإصدار التجريبي',
    String email = 'student.emu@test.com',
  }) {
    return UserModel(
      id: id,
      email: email,
      phone: '+966512345681',
      name: name,
      role: UserRole.student,
      createdAt: DateTime.now(),
    );
  }

  Future<String> addInstitute({
    String id = 'institute_emu',
    String name = 'معهد تجريبي',
    String location = 'الرياض',
  }) async {
    await firestore.collection('institutes').doc(id).set({
      'name': name,
      'location': location,
      'created_by': 'admin_test_id',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return id;
  }

  /// Adds a student standing on the curriculum session [sessionId] — their
  /// position is copied from that session document, exactly as production does.
  Future<String> addStudentRecord({
    String id = 'student_record_emu',
    required String userId,
    required String instituteId,
    String sessionId = 'L1_J30_S1',
  }) async {
    final doc = await firestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) {
      throw StateError('No curriculum session "$sessionId" is seeded.');
    }
    final session = SessionModel.fromFirestore(doc);

    // Rules require `isTeacher()` to create student rows. The seed account
    // sits at role=super_admin so it can write institutes/levels/sessions;
    // flip to teacher just for this write, then flip back.
    await _withSeedRole('teacher', () async {
      await firestore.collection('students').doc(id).set({
        'user_id': userId,
        'institute_id': instituteId,
        'teacher_id': null,
        'current_level': session.levelId,
        'current_juz': session.juzNumber,
        'current_session': session.sessionNumber,
        'current_order_in_level': session.orderInLevel,
        'current_hizb': session.hizbNumber,
        'current_session_id': session.id,
        'current_session_kind': session.kind.value,
        'current_session_tier': session.scope?.tier.value,
        'current_session_label_ar': session.scope?.labelAr,
        'current_attempt': 1,
        'unlocked_levels': [1],
        'completed_levels': [],
        'is_active': true,
        'created_at': Timestamp.now(),
      });
    });
    return id;
  }

  /// Temporarily swaps the seed account's role for a single write that the
  /// default super_admin role can't satisfy. The `users.update` rule allows
  /// `request.auth.uid == userId`, so the seed account can re-role itself.
  Future<void> _withSeedRole(String role, Future<void> Function() body) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = firestore.collection('users').doc(uid);
    await ref.update({'role': role});
    try {
      await body();
    } finally {
      await ref.update({'role': 'super_admin'});
    }
  }

  /// Seeds the same real-shaped level / session docs that the fake-Firestore
  /// `TestEnvironment.seedCurriculumData` does: a session is identified by
  /// `L{level}_J{juz}_S{n}` and its KIND is data.
  Future<void> _seedCurriculumData() async {
    await firestore.collection('levels').doc('level_1').set({
      'id': 1,
      'name_ar': 'المستوى الأول',
      'name_en': 'Level 1',
      'juz_numbers': [30, 29, 28],
      'session_count': 204,
      'order': 1,
    });

    Future<void> lesson(int session, int orderInLevel, String surah) {
      return firestore.collection('sessions').doc('L1_J30_S$session').set({
        'level_id': 1,
        'juz_number': 30,
        'session_number': session,
        'order_in_level': orderInLevel,
        'kind': 'lesson',
        'hizb_number': 59,
        'current_level_content': {
          'from_surah': surah,
          'from_verse': 1,
          'to_surah': surah,
          'to_verse': 5,
        },
      });
    }

    await lesson(1, 1, 'الناس');
    await lesson(5, 5, 'النبأ');
  }
}

class _EmulatorFirebaseService extends FirebaseService {
  _EmulatorFirebaseService({required FirebaseFirestore firestore})
    : super(auth: _MockFirebaseAuth(), firestore: firestore);
}

class _TestAuthRepository extends AuthRepository {
  final UserModel? appUser;

  _TestAuthRepository({this.appUser});

  @override
  AuthState build() => AuthState(appUser: appUser);

  @override
  Future<void> signOut() async {
    state = const AuthState();
  }
}

/// Diagnostic helper: returns true if the Firestore emulator is reachable.
/// Useful inside `setUpAll` to fail fast with a clear message instead of
/// hanging on the first `set()` call.
Future<bool> isEmulatorReachable() async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('http://$_emulatorHost:8080/');
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 2));
    final resp = await req.close();
    await resp.drain<void>();
    return true;
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firestore emulator unreachable at $_emulatorHost:8080 — $e');
    }
    return false;
  }
}
