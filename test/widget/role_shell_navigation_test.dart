import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/app.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/data/services/local_storage_service.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';
import 'package:al_rasikhoon/features/settings/screens/settings_screen.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_history_screen.dart';
import 'package:al_rasikhoon/features/teacher/screens/teacher_students_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockLocalStorageService extends Mock implements LocalStorageService {}

class _MockSessionCache extends Mock implements SessionCache {}

void main() {
  testWidgets('every teacher nav tab actually changes the visible screen '
      '(al_rasikhoon-256)', (tester) async {
    final mockFirebaseService = _MockFirebaseService();
    when(
      () => mockFirebaseService.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());

    final mockSessionCache = _MockSessionCache();
    when(() => mockSessionCache.readUser()).thenReturn(null);

    final teacher = UserModel(
      id: 'teacher-1',
      username: 'teacher1',
      email: 'teacher1@example.com',
      name: 'أستاذ محمد',
      role: UserRole.teacher,
      createdAt: DateTime(2024),
    );

    // Drive the REAL routerProvider (not a hand-rolled onTap callback) so
    // this test exercises RoleShell + StatefulShellRoute exactly as the
    // teacher does. Auth/session providers are overridden directly so the
    // router's redirect logic treats us as a signed-in teacher without
    // touching Firebase; the teacher data providers are overridden with
    // empty results so each screen renders its empty state instead of
    // hitting Firestore.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseServiceProvider.overrideWithValue(mockFirebaseService),
          userRepositoryProvider.overrideWithValue(_MockUserRepository()),
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          sessionCacheProvider.overrideWithValue(mockSessionCache),
          isAuthenticatedProvider.overrideWithValue(true),
          currentUserRoleProvider.overrideWithValue(UserRole.teacher),
          currentUserProvider.overrideWithValue(teacher),
          teacherStudentsProvider.overrideWith((ref) async => []),
          filteredTeacherStudentsProvider.overrideWith((ref) async => []),
          teacherInstitutesProvider.overrideWith((ref) async => []),
          teacherHistoryProvider.overrideWith((ref) async => []),
        ],
        child: const AlRasikhoonApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Redirected straight to /teacher — branch 0, الطلاب (students).
    expect(find.byType(TeacherStudentsScreen), findsOneWidget);
    expect(find.byType(TeacherHistoryScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);

    // Tap السجل — this is the exact tab that used to do NOTHING, silently,
    // because the teacher shell had only one StatefulShellBranch behind
    // four (then three) nav tabs (al_rasikhoon-256).
    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherHistoryScreen), findsOneWidget);
    expect(find.byType(TeacherStudentsScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);

    // Tap الملف الشخصي.
    await tester.tap(find.text('الملف الشخصي'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(TeacherHistoryScreen), findsNothing);
    expect(find.byType(TeacherStudentsScreen), findsNothing);

    // And back to الطلاب — every tab, not just the first, must navigate.
    await tester.tap(find.text('الطلاب'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherStudentsScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(TeacherHistoryScreen), findsNothing);
  });
}
