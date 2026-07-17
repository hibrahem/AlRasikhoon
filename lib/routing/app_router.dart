import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/models/user_model.dart';
import '../domain/assessment/assessment_evaluation.dart';
import '../shared/providers/user_provider.dart';
import '../shared/widgets/role_shell.dart';
import '../shared/widgets/student_pace_control.dart';
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
import '../features/admin/screens/supervisors_screen.dart';
import '../features/admin/screens/supervisor_detail_screen.dart';
import '../features/admin/screens/teacher_detail_screen.dart';
import '../features/admin/screens/curriculum_screen.dart';
import '../features/admin/screens/level_detail_screen.dart';
import '../features/admin/screens/all_students_screen.dart';
import '../features/admin/providers/admin_provider.dart';
import '../features/admin/widgets/student_institute_badge.dart';
import '../shared/screens/student_progress_screen.dart';
import '../features/supervisor/screens/supervisor_dashboard_screen.dart';
import '../features/supervisor/screens/exam_queue_screen.dart';
import '../features/supervisor/screens/exam_session_screen.dart';
import '../features/supervisor/screens/exam_result_screen.dart';
import '../features/supervisor/screens/supervisor_students_screen.dart';
import '../features/supervisor/providers/supervisor_provider.dart';
import '../features/supervisor/widgets/reposition_starting_point_section.dart';
import '../features/teacher/screens/sard_session_screen.dart';
import '../features/teacher/screens/sard_result_screen.dart';
import '../features/teacher/screens/teacher_students_screen.dart';
import '../features/teacher/screens/student_profile_screen.dart';
import '../features/teacher/screens/recitation_screen.dart';
import '../features/teacher/screens/new_memorization_screen.dart';
import '../features/teacher/screens/session_summary_screen.dart';
import '../features/teacher/screens/talqeen_session_screen.dart';
import '../features/teacher/screens/next_content_talqeen_screen.dart';
import '../features/teacher/screens/add_student_screen.dart';
import '../features/student/screens/student_dashboard_screen.dart';
import '../features/student/screens/session_history_screen.dart';
import '../features/student/screens/assessment_detail_screen.dart';
import '../features/student/screens/session_detail_screen.dart';
import '../features/student/screens/home_practice_screen.dart';
import '../features/settings/screens/settings_screen.dart';

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
  static const String supervisors = '/admin/supervisors';
  static const String supervisorDetail = '/admin/supervisors/:id';
  static const String teacherDetail = '/admin/teachers/:id';
  static const String curriculum = '/admin/curriculum';
  static const String levelDetail = '/admin/curriculum/:levelNumber';
  static const String adminStudents = '/admin/students';
  static const String adminStudentProgress = '/admin/students/:id';
  // A past record opened from a student's progress view. Same screen as the
  // student's own session detail, but registered in the ADMIN shell so opening
  // it never crosses a shell boundary (#45 duplicate-page-key crash) and never
  // jumps into the student shell (al_rasikhoon-3hn). 4 segments, so it never
  // collides with the 3-segment `:id` progress route.
  static const String adminStudentSessionDetail =
      '/admin/students/history/:recordId';
  // A past سرد/اختبار record (al_rasikhoon-nyp) — the assessment twin of
  // adminStudentSessionDetail; `:kind` is `sard` or `exam`.
  static const String adminStudentAssessmentDetail =
      '/admin/students/assessment/:kind/:recordId';
  static const String adminSettings = '/admin/settings';

  // Supervisor
  static const String supervisorDashboard = '/supervisor';
  static const String examQueue = '/supervisor/exams';
  static const String examSession = '/supervisor/exams/:studentId';
  static const String examResult = '/supervisor/exams/:studentId/result';
  // Supervisor student management (teacher-parity, institute-scoped — #28)
  static const String supervisorStudents = '/supervisor/students';
  static const String supervisorAddStudent = '/supervisor/students/add';
  // Supervisor student detail — READ-ONLY progress (al_rasikhoon-801). The
  // session-overview twin that used to live here existed only as the doorway
  // into Sard; سرد is teacher-conducted now, so the supervisor gets progress,
  // never an action.
  static const String supervisorStudentProgress =
      '/supervisor/students/:studentId';
  // Supervisor twin of adminStudentSessionDetail — shell-local so opening a
  // record from a student's progress view stays in the supervisor shell
  // (al_rasikhoon-3hn). 4 segments, so no collision with the 3-segment
  // `:studentId` progress route or the literal `add` route.
  static const String supervisorStudentSessionDetail =
      '/supervisor/students/history/:recordId';
  // A past سرد/اختبار record (al_rasikhoon-nyp) — shell-local like the
  // session-detail twin above; `:kind` is `sard` or `exam`.
  static const String supervisorStudentAssessmentDetail =
      '/supervisor/students/assessment/:kind/:recordId';
  static const String supervisorSettings = '/supervisor/settings';

  // Teacher
  static const String teacherStudents = '/teacher';
  static const String addStudent = '/teacher/students/add';
  // The student PROFILE screen — identity, level, progress, pace, current
  // session (startable from here), and that student's embedded session history
  // (al_rasikhoon-pb7). Opened when a teacher taps a student. Path is kept as
  // `/teacher/session/:studentId` so the whole session flow (recitation,
  // summary, سرد, ...) still hangs off it as a sub-path.
  static const String studentProfile = '/teacher/session/:studentId';
  static const String recitation =
      '/teacher/session/:studentId/recitation/:part';
  static const String newMemorization = '/teacher/session/:studentId/new';
  static const String sessionSummary = '/teacher/session/:studentId/summary';
  static const String nextContentTalqeen =
      '/teacher/session/:studentId/next-content';
  static const String talqeenSession = '/teacher/session/:studentId/talqeen';
  // Sard (السرد) — TEACHER-conducted (al_rasikhoon-801, reversing #29). Lives
  // in the teacher shell alongside the rest of the session flow, so the whole
  // الطلاب → session-overview → السرد path is ONE shell (no #45 cross-shell
  // duplicate-page-key crash). The router redirect guards it; Firestore rules
  // are the true backstop.
  static const String sardSession = '/teacher/session/:studentId/sard';
  static const String sardResult = '/teacher/session/:studentId/sard/result';
  // A past record the teacher heard, opened from a student's embedded session
  // history on the profile screen (al_rasikhoon-pb7 folded the teacher-wide
  // السجل tab into the profile). Same screen as the student's session detail,
  // but registered in the teacher shell's Students branch — alongside the
  // profile that opens it — so the push never crosses a shell boundary (#45
  // duplicate-page-key crash).
  static const String teacherSessionDetail = '/teacher/history/:recordId';
  // A past سرد/اختبار record the teacher opens from the same embedded history
  // (al_rasikhoon-nyp); `:kind` is `sard` or `exam`. NOT under
  // `/teacher/session/`, whose `/sard` segment the redirect guard watches.
  static const String teacherAssessmentDetail =
      '/teacher/assessment/:kind/:recordId';
  static const String teacherSettings = '/teacher/settings';

  // Student
  static const String studentDashboard = '/student';
  static const String sessionHistory = '/student/history';
  static const String sessionDetail = '/student/history/:recordId';
  // A past سرد/اختبار record from the student's own log (al_rasikhoon-nyp);
  // `:kind` is `sard` or `exam`.
  static const String assessmentDetail = '/student/assessment/:kind/:recordId';
  static const String homePractice = '/student/practice';
  static const String studentSettings = '/student/settings';
}

// Matches the literal `/sard` PATH SEGMENT (followed by `/` or end-of-string),
// not any substring occurrence. `matchedLocation` carries substituted path
// params, so a naive `.contains('/sard')` also fires for e.g. a student whose
// doc id merely begins with "sard" (`/supervisor/students/sardOoPs123`),
// bouncing legitimate navigation. Anchoring to a real path segment excludes
// that false positive while still catching both real Sard routes
// (`/teacher/session/:studentId/sard` and `.../sard/result`).
final RegExp _sardPathSegment = RegExp(r'/sard(?:/|$)');

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

      // Sard (السرد) is teacher-only (al_rasikhoon-801). Block any non-teacher
      // that reaches a teacher Sard path (e.g. a supervisor crafting the URL):
      // bounce them to their own dashboard. UI hides the entry point; this is
      // the navigation-level backstop. Firestore rules are the true backstop.
      if (_sardPathSegment.hasMatch(state.matchedLocation) &&
          userRole != UserRole.teacher) {
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

      // Admin shell — Management / Curriculum / Profile. Management (branch 0)
      // is the hub: it hosts the dashboard plus every management sub-screen
      // (institutes, teachers, supervisors, students) so navigation between
      // them never crosses a shell boundary (#45).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RoleShell(
          navigationShell: navigationShell,
          role: UserRole.superAdmin,
        ),
        branches: [
          // Branch 0: Management hub (dashboard + institutes + teachers +
          // supervisors + students).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminDashboard,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
              // Institutes
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
              // Teachers
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
              // Supervisors. `add` is registered BEFORE `:id` so the literal
              // segment still matches AddSupervisorScreen.
              GoRoute(
                path: AppRoutes.supervisors,
                builder: (context, state) => const SupervisorsScreen(),
              ),
              GoRoute(
                path: AppRoutes.addSupervisor,
                builder: (context, state) => const AddSupervisorScreen(),
              ),
              GoRoute(
                path: AppRoutes.supervisorDetail,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SupervisorDetailScreen(supervisorId: id);
                },
              ),
              // Students
              GoRoute(
                path: AppRoutes.adminStudents,
                builder: (context, state) => const AllStudentsScreen(),
              ),
              GoRoute(
                path: AppRoutes.adminStudentProgress,
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StudentProgressScreen(
                    studentId: id,
                    studentProvider: adminStudentProvider,
                    currentMeetingProvider: adminStudentCurrentMeetingProvider,
                    sessionHistoryProvider: adminStudentSessionHistoryProvider,
                    sessionDetailRoute: AppRoutes.adminStudentSessionDetail,
                    assessmentDetailRoute:
                        AppRoutes.adminStudentAssessmentDetail,
                    // Admin-only: an admin sees students across every
                    // institute, so the header names the student's — the
                    // teacher/supervisor shells are institute-scoped and
                    // pass nothing here.
                    instituteBadge: (student) =>
                        StudentInstituteBadge(instituteId: student.instituteId),
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.adminStudentSessionDetail,
                builder: (context, state) {
                  final recordId = state.pathParameters['recordId']!;
                  return SessionDetailScreen(recordId: recordId);
                },
              ),
              GoRoute(
                path: AppRoutes.adminStudentAssessmentDetail,
                builder: (context, state) {
                  return AssessmentDetailScreen(
                    kind: assessmentKindFromPath(state.pathParameters['kind']!),
                    recordId: state.pathParameters['recordId']!,
                  );
                },
              ),
            ],
          ),
          // Branch 1: Curriculum
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.curriculum,
                builder: (context, state) => const CurriculumScreen(),
              ),
              GoRoute(
                path: AppRoutes.levelDetail,
                builder: (context, state) {
                  final levelNumber = int.parse(
                    state.pathParameters['levelNumber']!,
                  );
                  return LevelDetailScreen(levelNumber: levelNumber);
                },
              ),
            ],
          ),
          // Branch 2: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Supervisor shell — Home / Exams / Students / Settings
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
                  final args =
                      state.extra
                          as ({
                            List<RecitationErrorTally> questions,
                            DateTime startedAt,
                          })?;
                  return ExamResultScreen(
                    studentId: studentId,
                    // No extra (deep link) ⇒ a clean sheet: five empty
                    // questions, the same blank state the session starts on.
                    questions:
                        args?.questions ??
                        List.filled(
                          ExamEvaluation.questionCount,
                          RecitationErrorTally.empty,
                        ),
                    startedAt: args?.startedAt,
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
              // Read-only progress — registered AFTER the literal `add` route so
              // `/supervisor/students/add` still matches AddStudentScreen.
              GoRoute(
                path: AppRoutes.supervisorStudentProgress,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return StudentProgressScreen(
                    studentId: studentId,
                    studentProvider: supervisorStudentProvider,
                    currentMeetingProvider:
                        supervisorStudentCurrentMeetingProvider,
                    sessionHistoryProvider:
                        supervisorStudentSessionHistoryProvider,
                    sessionDetailRoute:
                        AppRoutes.supervisorStudentSessionDetail,
                    assessmentDetailRoute:
                        AppRoutes.supervisorStudentAssessmentDetail,
                    // Supervisor-only affordance to move a not-yet-started
                    // student's starting point (al_rasikhoon-sne). It hides
                    // itself once the student has started; the admin shell
                    // passes nothing here.
                    repositionSection: RepositionStartingPointSection(
                      studentId: studentId,
                    ),
                    // A supervisor scoped to the student's institute may set
                    // pace (firestore.rules authorises it); the admin shell
                    // passes nothing here and stays read-only. Built with the
                    // loaded student so the control shows the current pace, and
                    // refreshing the supervisor's own caches on a change.
                    paceSection: (student) => StudentPaceControl(
                      student: student,
                      onPlanChanged: (ref) {
                        ref.invalidate(supervisorStudentProvider(student.id));
                        ref.invalidate(
                          supervisorStudentCurrentMeetingProvider(student.id),
                        );
                      },
                    ),
                  );
                },
              ),
              GoRoute(
                path: AppRoutes.supervisorStudentSessionDetail,
                builder: (context, state) {
                  final recordId = state.pathParameters['recordId']!;
                  return SessionDetailScreen(recordId: recordId);
                },
              ),
              GoRoute(
                path: AppRoutes.supervisorStudentAssessmentDetail,
                builder: (context, state) {
                  return AssessmentDetailScreen(
                    kind: assessmentKindFromPath(state.pathParameters['kind']!),
                    recordId: state.pathParameters['recordId']!,
                  );
                },
              ),
            ],
          ),
          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.supervisorSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Teacher shell — Students / History / Settings
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RoleShell(navigationShell: navigationShell, role: UserRole.teacher),
        branches: [
          // Branch 0: Students
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
                path: AppRoutes.studentProfile,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return StudentProfileScreen(studentId: studentId);
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
                path: AppRoutes.nextContentTalqeen,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return NextContentTalqeenScreen(studentId: studentId);
                },
              ),
              GoRoute(
                path: AppRoutes.talqeenSession,
                builder: (context, state) {
                  final studentId = state.pathParameters['studentId']!;
                  return TalqeenSessionScreen(studentId: studentId);
                },
              ),
              // Sard (السرد) — teacher-conducted (al_rasikhoon-801). Registered
              // in the teacher shell's Students branch, so the push from the
              // session overview never crosses a shell boundary.
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
                  final args =
                      state.extra
                          as ({
                            List<RecitationErrorTally> faces,
                            DateTime startedAt,
                          })?;
                  return SardResultScreen(
                    studentId: studentId,
                    // No extra (deep link) ⇒ a clean sheet: one empty face,
                    // the same blank state the session starts on.
                    faces: args?.faces ?? const [RecitationErrorTally.empty],
                    startedAt: args?.startedAt,
                  );
                },
              ),
              // A past record, opened from a student's embedded history on the
              // profile screen (al_rasikhoon-pb7). Registered in THIS (Students)
              // branch — the one the profile lives in — so tapping a record
              // stays shell-local and never triggers a cross-shell
              // duplicate-page-key crash (al_rasikhoon-3hn / #45).
              GoRoute(
                path: AppRoutes.teacherSessionDetail,
                builder: (context, state) {
                  final recordId = state.pathParameters['recordId']!;
                  return SessionDetailScreen(recordId: recordId);
                },
              ),
              // A past سرد/اختبار from the same embedded history
              // (al_rasikhoon-nyp) — registered in the same Students branch
              // for the same shell-locality reason.
              GoRoute(
                path: AppRoutes.teacherAssessmentDetail,
                builder: (context, state) {
                  return AssessmentDetailScreen(
                    kind: assessmentKindFromPath(state.pathParameters['kind']!),
                    recordId: state.pathParameters['recordId']!,
                  );
                },
              ),
            ],
          ),
          // Branch 1: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.teacherSettings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Student shell — Home / Practice / History / Settings
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
              GoRoute(
                path: AppRoutes.assessmentDetail,
                builder: (context, state) {
                  return AssessmentDetailScreen(
                    kind: assessmentKindFromPath(state.pathParameters['kind']!),
                    recordId: state.pathParameters['recordId']!,
                  );
                },
              ),
            ],
          ),
          // Branch 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.studentSettings,
                builder: (context, state) => const SettingsScreen(),
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
