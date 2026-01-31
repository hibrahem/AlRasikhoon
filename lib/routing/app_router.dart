import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/user_model.dart';
import '../shared/providers/user_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/account_not_found_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/admin/screens/institutes_screen.dart';
import '../features/admin/screens/create_institute_screen.dart';
import '../features/admin/screens/institute_detail_screen.dart';
import '../features/admin/screens/edit_institute_screen.dart';
import '../features/admin/screens/teachers_screen.dart';
import '../features/admin/screens/add_teacher_screen.dart';
import '../features/admin/screens/teacher_detail_screen.dart';
import '../features/admin/screens/curriculum_screen.dart';
import '../features/supervisor/screens/supervisor_dashboard_screen.dart';
import '../features/supervisor/screens/exam_queue_screen.dart';
import '../features/supervisor/screens/exam_session_screen.dart';
import '../features/supervisor/screens/exam_result_screen.dart';
import '../features/teacher/screens/teacher_students_screen.dart';
import '../features/teacher/screens/session_overview_screen.dart';
import '../features/teacher/screens/recitation_screen.dart';
import '../features/teacher/screens/recitation_result_screen.dart';
import '../features/teacher/screens/new_memorization_screen.dart';
import '../features/teacher/screens/session_summary_screen.dart';
import '../features/teacher/screens/sard_session_screen.dart';
import '../features/teacher/screens/sard_result_screen.dart';
import '../features/teacher/screens/add_student_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/session_history_screen.dart';
import '../features/student/screens/session_detail_screen.dart';
import '../features/student/screens/home_practice_screen.dart';

// Route names
class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String accountNotFound = '/account-not-found';

  // Admin
  static const String adminDashboard = '/admin';
  static const String institutes = '/admin/institutes';
  static const String createInstitute = '/admin/institutes/create';
  static const String instituteDetail = '/admin/institutes/:id';
  static const String editInstitute = '/admin/institutes/:id/edit';
  static const String teachers = '/admin/teachers';
  static const String addTeacher = '/admin/teachers/add';
  static const String teacherDetail = '/admin/teachers/:id';
  static const String curriculum = '/admin/curriculum';

  // Supervisor
  static const String supervisorDashboard = '/supervisor';
  static const String examQueue = '/supervisor/exams';
  static const String examSession = '/supervisor/exams/:studentId';
  static const String examResult = '/supervisor/exams/:studentId/result';

  // Teacher
  static const String teacherStudents = '/teacher';
  static const String addStudent = '/teacher/students/add';
  static const String sessionOverview = '/teacher/session/:studentId';
  static const String recitation = '/teacher/session/:studentId/recitation/:part';
  static const String recitationResult = '/teacher/session/:studentId/recitation/:part/result';
  static const String newMemorization = '/teacher/session/:studentId/new';
  static const String sessionSummary = '/teacher/session/:studentId/summary';
  static const String sardSession = '/teacher/sard/:studentId';
  static const String sardResult = '/teacher/sard/:studentId/result';

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
      final isLoggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.accountNotFound;

      // Not authenticated - redirect to login
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }

      // Authenticated but on login page - redirect to appropriate dashboard
      if (isAuthenticated && isLoggingIn) {
        return _getDashboardRoute(userRole);
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountNotFound,
        builder: (context, state) => const AccountNotFoundScreen(),
      ),

      // Admin routes
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.teachers,
        builder: (context, state) => const TeachersScreen(),
      ),
      GoRoute(
        path: AppRoutes.addTeacher,
        builder: (context, state) => const AddTeacherScreen(),
      ),
      GoRoute(
        path: AppRoutes.teacherDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TeacherDetailScreen(teacherId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.curriculum,
        builder: (context, state) => const CurriculumScreen(),
      ),

      // Supervisor routes
      GoRoute(
        path: AppRoutes.supervisorDashboard,
        builder: (context, state) => const SupervisorDashboardScreen(),
      ),
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
          return ExamResultScreen(studentId: studentId, errorCount: errorCount);
        },
      ),

      // Teacher routes
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
          return SardResultScreen(studentId: studentId, errorCount: errorCount);
        },
      ),

      // Student routes
      GoRoute(
        path: AppRoutes.studentDashboard,
        builder: (context, state) => const StudentDashboardScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.homePractice,
        builder: (context, state) => const HomePracticeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
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
