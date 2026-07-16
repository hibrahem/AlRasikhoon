import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../routing/app_router.dart';

/// One bottom-nav destination for a role, in branch order.
///
/// This is the single source of truth for a role's tabs. The nav bar renders
/// exactly this list, and `RoleShell` asserts it matches the role's shell
/// branches — so a tab can never exist without a route behind it
/// (al_rasikhoon-256).
///
/// The Nth destination here MUST correspond to the Nth `StatefulShellBranch`
/// of that role's `StatefulShellRoute` in `app_router.dart`. `rootPath` is that
/// branch's initial location, and is what keeps the correspondence checkable.
@immutable
class NavDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String rootPath;

  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.rootPath,
  });
}

List<NavDestination> destinationsFor(UserRole role) {
  switch (role) {
    case UserRole.superAdmin:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الإدارة',
          rootPath: AppRoutes.adminDashboard,
        ),
        NavDestination(
          icon: Icons.menu_book_outlined,
          activeIcon: Icons.menu_book,
          label: 'المنهج',
          rootPath: AppRoutes.curriculum,
        ),
        NavDestination(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
          rootPath: AppRoutes.adminSettings,
        ),
      ];

    case UserRole.supervisor:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الرئيسية',
          rootPath: AppRoutes.supervisorDashboard,
        ),
        NavDestination(
          icon: Icons.quiz_outlined,
          activeIcon: Icons.quiz,
          label: 'الاختبارات',
          rootPath: AppRoutes.examQueue,
        ),
        NavDestination(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'الطلاب',
          rootPath: AppRoutes.supervisorStudents,
        ),
        NavDestination(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
          rootPath: AppRoutes.supervisorSettings,
        ),
      ];

    // Two tabs: الطلاب and الملف الشخصي. There is no الحلقة tab (picking an
    // institute and seeing its students is already what الطلاب does via the
    // المعهد filter), and no السجل tab either: a student's session history now
    // lives INSIDE that student's profile screen, in context with their
    // identity, progress, pace, and current session (al_rasikhoon-pb7).
    case UserRole.teacher:
      return const [
        NavDestination(
          icon: Icons.school_outlined,
          activeIcon: Icons.school,
          label: 'الطلاب',
          rootPath: AppRoutes.teacherStudents,
        ),
        NavDestination(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
          rootPath: AppRoutes.teacherSettings,
        ),
      ];

    case UserRole.student:
    case UserRole.guardian:
      return const [
        NavDestination(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          label: 'الرئيسية',
          rootPath: AppRoutes.studentDashboard,
        ),
        NavDestination(
          icon: Icons.repeat_outlined,
          activeIcon: Icons.repeat,
          label: 'التكرار',
          rootPath: AppRoutes.homePractice,
        ),
        NavDestination(
          icon: Icons.history_outlined,
          activeIcon: Icons.history,
          label: 'السجل',
          rootPath: AppRoutes.sessionHistory,
        ),
        NavDestination(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'الملف الشخصي',
          rootPath: AppRoutes.studentSettings,
        ),
      ];
  }
}
