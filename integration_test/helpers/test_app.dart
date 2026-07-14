import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/l10n/app_localizations.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

/// Test app wrapper that provides mocked dependencies
class TestApp extends StatelessWidget {
  final List<dynamic> overrides;
  final Widget? child;
  final String? initialRoute;

  const TestApp({
    super.key,
    this.overrides = const [],
    this.child,
    this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: child ?? const _TestAppContent(),
    );
  }
}

class _TestAppContent extends ConsumerWidget {
  const _TestAppContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'الراسخون - Test',
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
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}

/// Helper class to set up test environment
class TestEnvironment {
  late FakeFirebaseFirestore fakeFirestore;
  late SharedPreferences sharedPreferences;
  late List<dynamic> overrides;

  /// Monotonic counter used to mint unique ids when callers don't supply one.
  /// DateTime.now().millisecondsSinceEpoch can collide across rapid calls in
  /// a single test, which silently overwrites Firestore docs.
  int _idSeq = 0;
  String _nextId(String prefix) {
    _idSeq += 1;
    return '${prefix}_$_idSeq';
  }

  Future<void> setUp({UserModel? authenticatedUser}) async {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    overrides = [
      firestoreProvider.overrideWithValue(fakeFirestore),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      firebaseServiceProvider.overrideWithValue(
        _TestFirebaseService(firestore: fakeFirestore),
      ),
    ];

    if (authenticatedUser != null) {
      await _setupAuthenticatedUser(authenticatedUser);
    } else {
      _setupUnauthenticatedState();
    }

    // Seed curriculum data needed for session/sard/exam screens
    await seedCurriculumData();
  }

  void _setupUnauthenticatedState() {
    // Override all auth-dependent providers to avoid Firebase initialization
    overrides.addAll([
      authRepositoryProvider.overrideWith(() => _TestAuthRepository()),
      currentUserProvider.overrideWith((ref) => null),
      isAuthenticatedProvider.overrideWith((ref) => false),
      currentUserRoleProvider.overrideWith((ref) => null),
    ]);
  }

  Future<void> _setupAuthenticatedUser(UserModel user) async {
    overrides.addAll(await _authOverridesFor(user));
  }

  /// Auth-dependent provider overrides for [user], plus the two fixture
  /// writes (`users/{uid}` doc, sharedPreferences session) every authenticated
  /// user needs — WITHOUT touching `overrides` or recreating [fakeFirestore].
  ///
  /// Used both by [_setupAuthenticatedUser] (the normal single-user setup)
  /// and by [overridesForUser] (switching identity mid-test on the SAME
  /// fixture data — e.g. asserting that a supervisor's action becomes visible
  /// to a teacher, al_rasikhoon-6bw) — the two must stay in lockstep or the
  /// second identity would silently behave differently from the first.
  Future<List<dynamic>> _authOverridesFor(UserModel user) async {
    await fakeFirestore
        .collection('users')
        .doc(user.id)
        .set(user.toFirestore());

    await sharedPreferences.setString('user_id', user.id);
    await sharedPreferences.setString('user_role', user.role.value);

    return [
      authRepositoryProvider.overrideWith(
        () => _TestAuthRepository(appUser: user),
      ),
      currentUserProvider.overrideWith((ref) => user),
      isAuthenticatedProvider.overrideWith((ref) => true),
      currentUserRoleProvider.overrideWith((ref) => user.role),
    ];
  }

  /// A full set of provider overrides — Firestore/SharedPreferences plumbing
  /// included — for a DIFFERENT authenticated user, reusing this
  /// environment's existing [fakeFirestore] and [sharedPreferences] rather
  /// than recreating them. Pump a NEW [TestApp] with a fresh [Key] and these
  /// overrides to switch identity mid-test: `ProviderScope` only diffs
  /// overrides on an EXISTING container when the same widget is rebuilt
  /// (`didUpdateWidget`), which would leave the router's own navigation stack
  /// stale — a fresh key forces a full remount instead, exactly as a real
  /// re-login would.
  Future<List<dynamic>> overridesForUser(UserModel user) async {
    return [
      firestoreProvider.overrideWithValue(fakeFirestore),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      firebaseServiceProvider.overrideWithValue(
        _TestFirebaseService(firestore: fakeFirestore),
      ),
      ...await _authOverridesFor(user),
    ];
  }

  /// Create a test super admin user
  UserModel createSuperAdmin({String? id, String? name, String? email}) {
    return UserModel(
      id: id ?? 'admin_test_id',
      email: email ?? 'admin@test.com',
      phone: '+966512345678',
      name: name ?? 'مدير النظام',
      role: UserRole.superAdmin,
      createdAt: DateTime.now(),
    );
  }

  /// Create a test teacher user
  UserModel createTeacher({String? id, String? name, String? email}) {
    return UserModel(
      id: id ?? 'teacher_test_id',
      email: email ?? 'teacher@test.com',
      phone: '+966512345679',
      name: name ?? 'معلم تجريبي',
      role: UserRole.teacher,
      createdAt: DateTime.now(),
    );
  }

  /// Create a test supervisor user
  UserModel createSupervisor({String? id, String? name, String? email}) {
    return UserModel(
      id: id ?? 'supervisor_test_id',
      email: email ?? 'supervisor@test.com',
      phone: '+966512345680',
      name: name ?? 'مشرف تجريبي',
      role: UserRole.supervisor,
      createdAt: DateTime.now(),
    );
  }

  /// Create a test student user
  UserModel createStudent({String? id, String? name, String? email}) {
    return UserModel(
      id: id ?? 'student_test_id',
      email: email ?? 'student@test.com',
      phone: '+966512345681',
      name: name ?? 'طالب تجريبي',
      role: UserRole.student,
      createdAt: DateTime.now(),
    );
  }

  /// Add an institute to fake Firestore
  Future<String> addInstitute({
    String? id,
    String? name,
    String? location,
  }) async {
    final instituteId = id ?? _nextId('institute');
    await fakeFirestore.collection('institutes').doc(instituteId).set({
      'name': name ?? 'معهد تجريبي',
      'location': location ?? 'الرياض',
      'created_by': 'admin_test_id',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return instituteId;
  }

  /// Add a student record to fake Firestore, standing on the curriculum session
  /// [sessionId] (`L{level}_J{juz}_S{n}` — one of those seeded by
  /// [seedCurriculumData]).
  ///
  /// The student's position is COPIED from that session document, exactly as
  /// production does: what the student is standing on (`current_session_kind`,
  /// its tier and its verbatim Arabic label) is the curriculum's word for it,
  /// never an inference from the session number. A fixture that says
  /// "session 35 ⇒ سرد" is the very bug this rework removes.
  Future<String> addStudent({
    String? id,
    required String userId,
    required String instituteId,
    String? teacherId,
    String sessionId = 'L1_J30_S1',
  }) async {
    final studentId = id ?? _nextId('student');
    final doc = await fakeFirestore.collection('sessions').doc(sessionId).get();
    if (!doc.exists) {
      throw StateError(
        'No curriculum session "$sessionId" is seeded — a student cannot stand '
        'on a session the curriculum does not contain.',
      );
    }
    final session = SessionModel.fromFirestore(doc);

    await fakeFirestore.collection('students').doc(studentId).set({
      'user_id': userId,
      'institute_id': instituteId,
      'teacher_id': teacherId,
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
      'unlocked_levels': [for (var l = 1; l <= session.levelId; l++) l],
      'completed_levels': [for (var l = 1; l < session.levelId; l++) l],
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return studentId;
  }

  /// Assign teacher to institute
  Future<void> assignTeacherToInstitute(
    String teacherId,
    String instituteId,
  ) async {
    await fakeFirestore.collection('teacher_institutes').add({
      'teacher_id': teacherId,
      'institute_id': instituteId,
      'is_active': true,
      'assigned_at': Timestamp.now(),
    });
  }

  /// Seed a small, REAL-shaped slice of the curriculum.
  ///
  /// The old fixtures WERE the old bug: they synthesized session ids of the form
  /// `L1_J30_H59_S35` and declared `session 35 ⇒ سرد, 36 ⇒ اختبار`. In the real
  /// curriculum a session's identity is `L{level}_J{juz}_S{n}`, its kind is DATA
  /// (`kind`), session numbers run 1..N continuously across a whole juz (70 in
  /// juz 30 of level 1), and assessments come at three tiers, each carrying the
  /// source's verbatim Arabic label. Every unit also opens with a تلقين: the
  /// teacher reads the next lesson's passage to the student, who memorizes and
  /// recites nothing.
  ///
  /// Seeded (level 1, juz 30 unless noted):
  /// - S1 — the تلقين that opens hizb 59; S5 / S10 — lessons;
  /// - S31 — the hizb-59 سرد (unit tier), S32 its اختبار;
  /// - S69 — the juz-30 سرد (juz tier), S70 its اختبار — the session the
  ///   supervisor's exam queue really finds (never "36");
  /// - juz 28: S68 the level's cumulative سرد (juz 28-29-30), S69 its اختبار.
  Future<void> seedCurriculumData() async {
    await fakeFirestore.collection('levels').doc('level_1').set({
      'id': 1,
      'name_ar': 'المستوى الأول',
      'name_en': 'Level 1',
      // Levels 1-9 teach their juz DESCENDING; the order is read, never
      // computed (level 10 ascends).
      'juz_numbers': [30, 29, 28],
      'session_count': 210,
      'order': 1,
    });

    Future<void> lesson({
      required int juz,
      required int session,
      required int orderInLevel,
      int? hizb,
      String surah = 'النبأ',
    }) {
      return fakeFirestore
          .collection('sessions')
          .doc('L1_J${juz}_S$session')
          .set({
            'level_id': 1,
            'juz_number': juz,
            'session_number': session,
            'order_in_level': orderInLevel,
            'kind': 'lesson',
            'hizb_number': hizb,
            'current_level_content': {
              'from_surah': surah,
              'from_verse': 1,
              'to_surah': surah,
              'to_verse': 11,
            },
          });
    }

    Future<void> talqeen({
      required int juz,
      required int session,
      required int orderInLevel,
      required int unitIndex,
      int? hizb,
      String surah = 'النبأ',
    }) {
      return fakeFirestore
          .collection('sessions')
          .doc('L1_J${juz}_S$session')
          .set({
            'level_id': 1,
            'juz_number': juz,
            'session_number': session,
            'order_in_level': orderInLevel,
            'kind': 'talqeen',
            'unit_index': unitIndex,
            'hizb_number': hizb,
            'current_level_content': {
              'from_surah': surah,
              'from_verse': 1,
              'to_surah': surah,
              'to_verse': 11,
            },
          });
    }

    Future<void> assessment({
      required int juz,
      required int session,
      required int orderInLevel,
      required String kind,
      required String tier,
      required String labelAr,
      int? hizb,
      required List<int> juzNumbers,
    }) {
      return fakeFirestore
          .collection('sessions')
          .doc('L1_J${juz}_S$session')
          .set({
            'level_id': 1,
            'juz_number': juz,
            'session_number': session,
            'order_in_level': orderInLevel,
            'kind': kind,
            'assessed_by': kind == 'sard' ? 'teacher' : 'supervisor',
            'hizb_number': hizb,
            'scope': {
              'tier': tier,
              'label_ar': labelAr,
              'hizb_number': hizb,
              'juz_numbers': juzNumbers,
            },
          });
    }

    await talqeen(juz: 30, session: 1, orderInLevel: 1, unitIndex: 1, hizb: 59);
    await lesson(juz: 30, session: 5, orderInLevel: 5, hizb: 59);
    await lesson(juz: 30, session: 10, orderInLevel: 10, hizb: 59);

    // The unit-tier pair for hizb 59 — سرد at session 31, اختبار at 32.
    await assessment(
      juz: 30,
      session: 31,
      orderInLevel: 31,
      kind: 'sard',
      tier: 'unit',
      labelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
      hizb: 59,
      juzNumbers: const [30],
    );
    await assessment(
      juz: 30,
      session: 32,
      orderInLevel: 32,
      kind: 'exam',
      tier: 'unit',
      labelAr: 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
      hizb: 59,
      juzNumbers: const [30],
    );

    // The juz-tier pair — the last two sessions of juz 30. Neither has a hizb.
    await assessment(
      juz: 30,
      session: 69,
      orderInLevel: 69,
      kind: 'sard',
      tier: 'juz',
      labelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
      juzNumbers: const [30],
    );
    await assessment(
      juz: 30,
      session: 70,
      orderInLevel: 70,
      kind: 'exam',
      tier: 'juz',
      labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
      juzNumbers: const [30],
    );

    // The first session of juz 29 opens with its own تلقين and continues the
    // level's ordering at 71 — a juz boundary crossed by `order_in_level` alone.
    await talqeen(
      juz: 29,
      session: 1,
      orderInLevel: 71,
      unitIndex: 1,
      hizb: 57,
      surah: 'الملك',
    );

    // The cumulative pair — the last two sessions of the LEVEL, covering all
    // three of its juz.
    await assessment(
      juz: 28,
      session: 68,
      orderInLevel: 209,
      kind: 'sard',
      tier: 'cumulative',
      labelAr:
          'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
      juzNumbers: const [28, 29, 30],
    );
    await assessment(
      juz: 28,
      session: 69,
      orderInLevel: 210,
      kind: 'exam',
      tier: 'cumulative',
      labelAr:
          'اختبار في المستوى كاملًا  الأجزاء رقم 28 ــ  29 ــ 30 من قِبل إدارة الحلقات',
      juzNumbers: const [28, 29, 30],
    );
  }

  /// Assign supervisor to institute
  Future<void> assignSupervisorToInstitute(
    String supervisorId,
    String instituteId,
  ) async {
    await fakeFirestore.collection('supervisor_institutes').add({
      'supervisor_id': supervisorId,
      'institute_id': instituteId,
      'is_active': true,
      'assigned_at': Timestamp.now(),
    });
  }
}

/// Fake FirebaseService that doesn't require FirebaseAuth initialization.
/// Only provides Firestore access for screens that use firebaseService.firestore.
///
/// `authStateChanges` is overridden to return a *finite, completing* stream
/// instead of delegating to the unstubbed `_MockFirebaseAuth` mock. A mocktail
/// mock's unstubbed `authStateChanges()` yields a stream that never closes;
/// any subscriber (e.g. `AuthRepository._init()`) then keeps a live
/// subscription open for the lifetime of the widget tree. On the Android-9
/// (API 28) scheduler this open subscription keeps the frame ticker from ever
/// reaching an idle state, so `pumpAndSettle()` spins forever (issue #5). The
/// iOS scheduler tolerates the never-closing stream, which is why the iOS
/// simulator passed 69/69 while the physical Galaxy Note 8 hung at +0.
///
/// Returning `Stream<User?>.empty()` (unauthenticated) or a single-shot
/// `Stream<User?>.value(user)` (authenticated) makes the stream complete
/// immediately, so the binding can reach idle. Test authentication state is
/// driven entirely through the overridden `authRepositoryProvider` /
/// `currentUserProvider` (see `_setupAuthenticatedUser`), so this stream is
/// never the source of truth in tests — behaviour is unchanged, the hang is
/// removed.
class _TestFirebaseService extends FirebaseService {
  _TestFirebaseService({
    required FirebaseFirestore firestore,
    User? authenticatedUser,
  }) : _authenticatedUser = authenticatedUser,
       super(auth: _MockFirebaseAuth(), firestore: firestore);

  final User? _authenticatedUser;

  /// Monotonic counter so each provisioned account gets a unique uid.
  int _provisionSeq = 0;

  @override
  Stream<User?> get authStateChanges => _authenticatedUser == null
      ? const Stream<User?>.empty()
      : Stream<User?>.value(_authenticatedUser);

  /// In production this calls the `createUserAccount` Cloud Function, which
  /// provisions both the Auth user and the `users/{uid}` profile server-side.
  /// There is no Functions backend (and no initialised Firebase app) in the
  /// integration tests, so the real call throws and the add-teacher flow
  /// never wrote the profile — the teacher never appeared in the list (#46).
  ///
  /// Here we emulate the Cloud Function's *observable effect*: write the
  /// `users/{uid}` profile to the fake Firestore with the fields the teachers
  /// query relies on (`role`, `is_active: true`, `created_at`) and return the
  /// uid, exactly as the real function does. The subsequent
  /// `getTeachersConfirmingUid` read-after-write confirmation then finds the
  /// new doc and the list refresh shows the teacher — the same path prod takes.
  @override
  Future<String> provisionUserAccount({
    required String email,
    required String password,
    required String role,
    required String name,
    required String username,
    String? phone,
    String? instituteId,
  }) async {
    _provisionSeq += 1;
    final uid = 'provisioned_${role}_$_provisionSeq';
    await firestore.collection('users').doc(uid).set({
      'username': username,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role,
      'auth_provider': 'email_password',
      'institute_id': instituteId,
      'created_at': Timestamp.now(),
      'updated_at': null,
      'is_active': true,
    });
    return uid;
  }
}

/// Fake AuthRepository that doesn't depend on Firebase Auth
class _TestAuthRepository extends AuthRepository {
  final UserModel? appUser;

  _TestAuthRepository({this.appUser});

  @override
  AuthState build() {
    return AuthState(appUser: appUser);
  }

  @override
  Future<void> signOut() async {
    state = const AuthState();
  }
}
