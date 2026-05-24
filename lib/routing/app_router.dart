import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/user_model.dart';
import '../shared/providers/user_provider.dart';
import '../shared/widgets/role_shell.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/account_not_found_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/institutes_screen.dart';
import '../features/admin/screens/create_institute_screen.dart';
import '../features/admin/screens/institute_detail_screen.dart';
import '../features/admin/screens/edit_institute_screen.dart';
import '../features/admin/screens/teachers_screen.dart';
import '../features/admin/screens/add_teacher_screen.dart';
import '../features/admin/screens/add_supervisor_screen.dart';
import '../features/admin/screens/teacher_detail_screen.dart';
import '../features/admin/screens/curriculum_screen.dart';
import '../features/admin/screens/level_detail_screen.dart';
import '../features/admin/screens/all_students_screen.dart';
import '../features/admin/screens/admin_student_progress_screen.dart';
import '../features/supervisor/screens/supervisor_dashboard_screen.dart';
import '../features/supervisor/screens/exam_queue_screen.dart';
import '../features/supervisor/screens/exam_session_screen.dart';
import '../features/supervisor/screens/exam_result_screen.dart';
import '../features/supervisor/screens/supervisor_students_screen.dart';
import '../features/supervisor/screens/sard_session_screen.dart';
import '../features/supervisor/screens/sard_result_screen.dart';
import '../features/teacher/screens/teacher_students_screen.dart';
import '../features/teacher/screens/session_overview_screen.dart';
import '../features/teacher/screens/recitation_screen.dart';
import '../features/teacher/screens/recitation_result_screen.dart';
import '../features/teacher/screens/new_memorization_screen.dart';
import '../features/teacher/screens/session_summary_screen.dart';
import '../features/teacher/screens/add_student_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/session_history_screen.dart';
import '../features/student/screens/session_detail_screen.dart';
import '../features/student/screens/home_practice_screen.dart';

// Route names
class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String accountNotFound = '/account-not-found';

  // Admin
  static const String adminDashboard = '/admin';
  static const String institutes = '/admin/institutes';
  static const String createInstitute = '/admin/institutes/create';
  static const String instituteDetail = '/admin/institutes/:id';
  static const String editInstitute = '/admin/institutes/:id/edit';
  static const String teachers = '/admin/teachers';
  static const String addTeacher = '/admin/teachers/add';
  static const String addSupervisor = '/admin/supervisors/add';
  static const String teacherDetail = '/admin/teachers/:id';
  static const String curriculum = '/admin/curriculum';
  static const String levelDetail = '/admin/curriculum/:levelNumber';
  static const String adminStudents = '/admin/students';
  static const String adminStudentProgress = '/admin/students/:id';

  // Supervisor
  static const String supervisorDashboard = '/supervisor';
  static const String examQueue = '/supervisor/exams';
  static const String examSession = '/supervisor/exams/:studentId';
  static const String examResult = '/supervisor/exams/:studentId/result';
  // Supervisor student management (teacher-parity, institute-scoped — #28)
  static const String supervisorStudents = '/supervisor/students';
  static const String supervisorAddStudent = '/supervisor/students/add';
  // Sard (السرد) — supervisor-only (#29). Lives under /supervisor so a teacher
  // (in the teacher shell) cannot reach it; the router redirect guards it too.
  static const String sardSession = '/supervisor/sard/:studentId';
  static const String sardResult = '/supervisor/sard/:studentId/result';

  // Teacher
  static const String teacherStudents = '/teacher';
  static const String addStudent = '/teacher/students/add';
  static const String sessionOverview = '/teacher/session/:studentId';
  static const String recitation =
      '/teacher/session/:studentId/recitation/:part';
  static const String recitationResult =
      '/teacher/session/:studentId/recitation/:part/result';
  static const String newMemorization = '/teacher/session/:studentId/new';
  static const String sessionSummary = '/teacher/session/:studentId/summary';

  // Student
  static const String studentDashboard = '/student';
  static const String sessionHistory = '/student/history';
  static const String sessionDetail = '/student/history/:recordId';
  static const String homePractice = '/student/practice';
}

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final userRole = ref.watch(currentUserRoleProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggingIn =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.accountNotFound;

      // Not authenticated - redirect to login
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }

      // Authenticated but on login page - redirect to appropriate dashboard
      if (isAuthenticated && isLoggingIn) {
        return _getDashboardRoute(userRole);
      }

      // Sard (السرد) is supervisor-only (#29). Block any non-supervisor that
      // reaches a /supervisor/sard/* path (e.g. a teacher crafting the URL):
      // bounce them to their own dashboard. UI hides the entry point; this is
      // the navigation-level backstop. Firestore rules are the true backstop.
      if (state.matchedLocation.startsWith('/supervisor/sard') &&
          userRole != UserRole.supervisor) {
        return _getDashboardRoute(userRole);
      }

      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountNotFound,
        builder: (context, state) => const AccountNotFoundScreen(),
      ),

      // Admin shell — Home / Institutes / Teachers / Curriculum
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          role: UserRole.superAdmin,
        ),
        branches: [
          // Branch 0: Home (also hosts students list/detail pushed from dashboard)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminDashboard,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminStudents,
                builder: (context, state) => const AllStudentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminStudentProgress,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return AdminStudentProgressScreen(studentId: id);
                },
              ),
            ],
          ),
          // Branch 1: Institutes
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.institutes,
                builder: (context, state) => const InstitutesScreen(),
              ),
              GoRoute(
                path: AppRoutes.createInstitute,
                builder: (context, state) => const CreateInstituteScreen(),
              ),
              GoRoute(
                path: AppRoutes.instituteDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return InstituteDetailScreen(instituteId: id);
                },
              ),
              GoRoute(
                path: AppRoutes.editInstitute,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return EditInstituteScreen(instituteId: id);
                },
              ),
            ],
          ),
          // Branch 2: Teachers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teachers,
                builder: (context, state) => const TeachersScreen(),
              ),
              GoRoute(
                path: AppRoutes.addTeacher,
                builder: (context, state) => const AddTeacherScreen(),
              ),
              GoRoute(
                path: AppRoutes.addSupervisor,
                builder: (context, state) => const AddSupervisorScreen(),
              ),
              GoRoute(
                path: AppRoutes.teacherDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return TeacherDetailScreen(teacherId: id);
                },
              ),
            ],
          ),
          // Branch 3: Curriculum
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.curriculum,
                builder: (context, state) => const CurriculumScreen(),
              ),
              GoRoute(
                path: AppRoutes.levelDetail,
                builder: (context, state) {
                  final levelNumber =
                      int.parse(state.pathParameters['levelNumber']!);
                  return LevelDetailScreen(levelNumber: levelNumber);
                },
              ),
            ],
          ),
        ],
      ),

      // Supervisor shell — Home / Exams (Students & Settings tabs are stubs)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          role: UserRole.supervisor,
        ),
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisorDashboard,
                builder: (context, state) => const SupervisorDashboardScreen(),
              ),
            ],
          ),
          // Branch 1: Exams
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.examQueue,
                builder: (context, state) => const ExamQueueScreen(),
              ),
              GoRoute(
                path: AppRoutes.examSession,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return ExamSessionScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.examResult,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final errorCount = state.extra as int? ?? 0;
                  return ExamResultScreen(
                    studentId: studentId,
                    errorCount: errorCount,
                  );
                },
              ),
            ],
          ),
          // Branch 2: Students — institute-scoped teacher-parity student
          // management (#28 / AgDR-0003).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisorStudents,
                builder: (context, state) => const SupervisorStudentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.supervisorAddStudent,
                builder: (context, state) =>
                    const AddStudentScreen(asSupervisor: true),
              ),
              // Sard (السرد) — supervisor-only (#29). Relocated here from the
              // teacher shell so a teacher cannot navigate to it; the router
              // redirect below blocks any non-supervisor that crafts the path.
              GoRoute(
                path: AppRoutes.sardSession,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return SardSessionScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.sardResult,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final errorCount = state.extra as int? ?? 0;
                  return SardResultScreen(
                    studentId: studentId,
                    errorCount: errorCount,
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // Teacher shell — single Students branch (Session/History/Settings stubs)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RoleShell(navigationShell: navigationShell, role: UserRole.teacher),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherStudents,
                builder: (context, state) => const TeacherStudentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.addStudent,
                builder: (context, state) => const AddStudentScreen(),
              ),
              GoRoute(
                path: AppRoutes.sessionOverview,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return SessionOverviewScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.recitation,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final part = int.parse(state.pathParameters['part']!);
                  return RecitationScreen(studentId: studentId, part: part);
                },
              ),
              GoRoute(
                path: AppRoutes.recitationResult,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  final part = int.parse(state.pathParameters['part']!);
                  final errorCount = state.extra as int? ?? 0;
                  return RecitationResultScreen(
                    studentId: studentId,
                    part: part,
                    errorCount: errorCount,
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.newMemorization,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return NewMemorizationScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.sessionSummary,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return SessionSummaryScreen(studentId: studentId);
                },
              ),
            ],
          ),
        ],
      ),

      // Student shell — Home / Practice / History (Settings stub)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RoleShell(navigationShell: navigationShell, role: UserRole.student),
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentDashboard,
                builder: (context, state) => const StudentDashboardScreen(),
              ),
            ],
          ),
          // Branch 1: Practice
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.homePractice,
                builder: (context, state) => const HomePracticeScreen(),
              ),
            ],
          ),
          // Branch 2: History
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sessionHistory,
                builder: (context, state) => const SessionHistoryScreen(),
              ),
              GoRoute(
                path: AppRoutes.sessionDetail,
                builder: (context, state) {
                  final recordId = state.pathParameters['recordId']!;
                  return SessionDetailScreen(recordId: recordId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
});

String _getDashboardRoute(UserRole? role) {
  switch (role) {
    case UserRole.superAdmin:
      return AppRoutes.adminDashboard;
    case UserRole.supervisor:
      return AppRoutes.supervisorDashboard;
    case UserRole.teacher:
      return AppRoutes.teacherStudents;
    case UserRole.student:
    case UserRole.guardian:
      return AppRoutes.studentDashboard;
    default:
      return AppRoutes.login;
  }
}
