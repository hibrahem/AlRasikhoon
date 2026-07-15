class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'الراسخون';
  static const String appNameEn = 'Al-Rasikhoon';
  static const String version = '1.0.0';

  // Curriculum
  // Session counts are DATA — they vary per juz and per level, and live in the
  // levels catalog (`levels.json` / the `levels` collection). Nothing here may
  // pretend to know them, and a session's kind is NEVER inferred from its
  // number: the old `sessionsPerHizb = 36`, `sardSessionNumber = 35`,
  // `examSessionNumber = 36` were exactly that mistake.
  static const int totalLevels = 10;

  // Session kinds
  static const String sessionKindTalqeen = 'talqeen';
  static const String sessionKindLesson = 'lesson';
  static const String sessionKindSard = 'sard';
  static const String sessionKindExam = 'exam';

  // Grading thresholds (per spec)
  // راسخ: 0 errors, متقن: 1-2, حافظ: 3-4, مجتهد: 5-6, محب: 7+
  static const int maxErrorsToPass = 6; // Up to mujtahid passes
  static const int errorsForRasikh = 0; // 5 stars - exactly 0 errors
  static const int maxErrorsForMutqin = 2; // 4 stars - 1-2 errors
  static const int maxErrorsForHafiz = 4; // 3 stars - 3-4 errors
  static const int maxErrorsForMujtahid = 6; // 2 stars - 5-6 errors
  // 7+ errors = Muhib (1 star, fail)

  // Attempt limits
  // Lessons only. Assessments (سرد and اختبار, at every tier) may be retried
  // without limit — a student who cannot yet recite a juz keeps working at it.
  static const int maxSessionAttempts = 3;

  // User roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleSupervisor = 'supervisor';
  static const String roleTeacher = 'teacher';
  static const String roleStudent = 'student';
  static const String roleGuardian = 'guardian';

  // Firebase collections
  static const String collectionUsers = 'users';
  static const String collectionInstitutes = 'institutes';
  static const String collectionStudents = 'students';
  static const String collectionTeacherInstitutes = 'teacher_institutes';
  static const String collectionSupervisorInstitutes = 'supervisor_institutes';
  static const String collectionLevels = 'levels';
  static const String collectionSessions = 'sessions';
  static const String collectionSessionRecords = 'session_records';
  static const String collectionSardRecords = 'sard_records';
  static const String collectionExamRecords = 'exam_records';

  // Phone validation
  static const String saudiCountryCode = '+966';
  static const int saudiPhoneLength = 9;
  static const String phonePattern = r'^5[0-9]{8}$';

  // OTP
  static const int otpLength = 6;
  static const int otpTimeoutSeconds = 60;

  // Animation durations
  static const int shortAnimationMs = 200;
  static const int mediumAnimationMs = 300;
  static const int longAnimationMs = 500;

  // Pagination
  static const int defaultPageSize = 20;

  // Local storage keys
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyLanguage = 'language';
  static const String keyTheme = 'theme';
  static const String keyFirstLaunch = 'first_launch';

  // Session cache (Hive)
  static const String boxSession = 'session';
  static const String keyCachedUser = 'current_user';

  /// Domain used to synthesize a Firebase Auth email from a username.
  /// Format: `<username>@alrasikhoon.local`. RFC-6762 reserves '.local',
  /// so this can never collide with a real deliverable domain.
  static const String synthesizedEmailDomain = 'alrasikhoon.local';
}
