class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'الراسخون';
  static const String appNameEn = 'Al-Rasikhoon';
  static const String version = '1.0.0';

  // Curriculum
  static const int totalLevels = 10;
  static const int totalSessions = 1453;
  static const int hizbsPerLevel = 6;
  static const int sessionsPerHizb = 36; // 34 regular + sard + exam

  // Session types
  static const String sessionTypeRegular = 'regular';
  static const String sessionTypeSard = 'sard';
  static const String sessionTypeExam = 'exam';

  // Session numbers
  static const int sardSessionNumber = 35;
  static const int examSessionNumber = 36;

  // Grading thresholds (per spec)
  // راسخ: 0 errors, متقن: 1-2, حافظ: 3-4, مجتهد: 5-6, محب: 7+
  static const int maxErrorsToPass = 6; // Up to mujtahid passes
  static const int errorsForRasikh = 0; // 5 stars - exactly 0 errors
  static const int maxErrorsForMutqin = 2; // 4 stars - 1-2 errors
  static const int maxErrorsForHafiz = 4; // 3 stars - 3-4 errors
  static const int maxErrorsForMujtahid = 6; // 2 stars - 5-6 errors
  // 7+ errors = Muhib (1 star, fail)

  // Attempt limits
  static const int maxSessionAttempts = 3;
  static const int maxSardAttempts = 3;
  static const int maxExamAttempts = 3;

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

  /// Domain used to synthesize a Firebase Auth email from a username.
  /// Format: '<username>@alrasikhoon.local'. RFC-6762 reserves '.local',
  /// so this can never collide with a real deliverable domain.
  static const String synthesizedEmailDomain = 'alrasikhoon.local';
}
