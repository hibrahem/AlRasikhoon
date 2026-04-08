import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/l10n/app_localizations.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/routing/app_router.dart';
import 'package:al_rasikhoon/data/repositories/auth_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/data/services/deep_link_service.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}

/// Helper class to set up test environment
class TestEnvironment {
  late FakeFirebaseFirestore fakeFirestore;
  late SharedPreferences sharedPreferences;
  late List<dynamic> overrides;

  Future<void> setUp({
    UserModel? authenticatedUser,
  }) async {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();

    final deepLinkService = DeepLinkService();

    overrides = [
      firestoreProvider.overrideWithValue(fakeFirestore),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      deepLinkServiceProvider.overrideWithValue(deepLinkService),
    ];

    if (authenticatedUser != null) {
      await _setupAuthenticatedUser(authenticatedUser);
    } else {
      _setupUnauthenticatedState();
    }
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
    // Add user to fake Firestore
    await fakeFirestore.collection('users').doc(user.id).set(user.toFirestore());

    // Set user ID in shared preferences
    await sharedPreferences.setString('user_id', user.id);
    await sharedPreferences.setString('user_role', user.role.value);

    // Override all auth-dependent providers with test values
    overrides.addAll([
      authRepositoryProvider.overrideWith(() => _TestAuthRepository(appUser: user)),
      currentUserProvider.overrideWith((ref) => user),
      isAuthenticatedProvider.overrideWith((ref) => true),
      currentUserRoleProvider.overrideWith((ref) => user.role),
    ]);
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
    final instituteId = id ?? 'institute_${DateTime.now().millisecondsSinceEpoch}';
    await fakeFirestore.collection('institutes').doc(instituteId).set({
      'name': name ?? 'معهد تجريبي',
      'location': location ?? 'الرياض',
      'created_by': 'admin_test_id',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return instituteId;
  }

  /// Add a student record to fake Firestore
  Future<String> addStudent({
    String? id,
    required String userId,
    required String instituteId,
    String? teacherId,
    int currentSession = 1,
    int currentLevel = 1,
  }) async {
    final studentId = id ?? 'student_${DateTime.now().millisecondsSinceEpoch}';
    await fakeFirestore.collection('students').doc(studentId).set({
      'user_id': userId,
      'institute_id': instituteId,
      'teacher_id': teacherId,
      'current_level': currentLevel,
      'current_juz': 30,
      'current_hizb': 59,
      'current_session': currentSession,
      'current_attempt': 1,
      'unlocked_levels': [1],
      'completed_levels': [],
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return studentId;
  }

  /// Assign teacher to institute
  Future<void> assignTeacherToInstitute(String teacherId, String instituteId) async {
    await fakeFirestore.collection('teacher_institutes').add({
      'teacher_id': teacherId,
      'institute_id': instituteId,
      'is_active': true,
      'assigned_at': Timestamp.now(),
    });
  }

  /// Assign supervisor to institute
  Future<void> assignSupervisorToInstitute(String supervisorId, String instituteId) async {
    await fakeFirestore.collection('supervisor_institutes').add({
      'supervisor_id': supervisorId,
      'institute_id': instituteId,
      'is_active': true,
      'assigned_at': Timestamp.now(),
    });
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
