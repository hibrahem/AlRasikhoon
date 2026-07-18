// Design-preview harness: renders the redesigned screens with mock data and
// NO Firebase, so the visual direction can be reviewed on
// `flutter run -d web-server -t lib/preview_main.dart`.
//
// Role screens are real screens rendered inside their own ProviderScope with
// value overrides. Dark mode follows the platform (ThemeMode.system), so the
// browser's prefers-color-scheme toggles it without preview-only chrome.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/models/level_model.dart';
import 'data/models/session_model.dart';
import 'data/models/student_model.dart';
import 'data/models/user_model.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/curriculum_repository.dart';
import 'data/repositories/student_repository.dart';
import 'domain/curriculum/completion_forecast.dart';
import 'domain/curriculum/curriculum_pace.dart';
import 'domain/curriculum/paced_session.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/student/widgets/home_practice_card.dart';
import 'features/student/widgets/home_practice_view.dart';
import 'features/student/widgets/student_dashboard_view.dart';
import 'features/supervisor/providers/supervisor_provider.dart';
import 'features/supervisor/screens/supervisor_dashboard_screen.dart';
import 'features/teacher/providers/teacher_provider.dart';
import 'features/teacher/screens/recitation_screen.dart';
import 'features/teacher/screens/student_profile_screen.dart';
import 'features/teacher/screens/teacher_students_screen.dart';
import 'shared/providers/completion_forecast_provider.dart';
import 'shared/providers/institute_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/widgets/completion_forecast_card.dart';
import 'shared/widgets/splash/splash_overlay.dart';

void main() {
  runApp(const DesignPreviewApp());
}

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الراسخون — معاينة التصميم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _PreviewShell(),
    );
  }
}

class _PreviewShell extends StatefulWidget {
  const _PreviewShell();

  @override
  State<_PreviewShell> createState() => _PreviewShellState();
}

class _PreviewShellState extends State<_PreviewShell> {
  // Deep-linkable for screenshots: /?tab=3 opens tab 3. (A #fragment would
  // fight Flutter's hash URL strategy and stall the engine boot.)
  int _index = int.tryParse(Uri.base.queryParameters['tab'] ?? '') ?? 0;

  static const _tabs = <String>[
    'طالب',
    'تكرار',
    'معلم',
    'ملف طالب',
    'تسميع ١',
    'تسميع ٢',
    'تسميع ٣',
    'مشرف',
    'مدير',
    'شاشة البداية',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_index) {
        0 => const _DashboardPreview(),
        1 => const _HomePracticePreview(),
        2 => const _TeacherPreview(),
        3 => const _StudentProfilePreview(),
        4 => const _RecitationPreview(part: 1),
        5 => const _RecitationPreview(part: 2),
        6 => const _RecitationPreview(part: 3),
        7 => const _SupervisorPreview(),
        8 => const _AdminPreview(),
        _ => const _SplashPreview(),
      },
      bottomNavigationBar: SafeArea(
        child: SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => ChoiceChip(
              label: Text(_tabs[i]),
              selected: _index == i,
              onSelected: (_) => setState(() => _index = i),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared mock data ────────────────────────────────────────────────────

const _mockBeads = [true, true, false, true, true, true, true];

/// A plausible remainder for the mock level-2 student: 130 standalone rows
/// (تلقين/سرد/اختبار) and 96 lesson runs of 4..8 — ~700 rows ahead, shaped
/// like the real curriculum so every slider detent changes the forecast.
final _mockRemaining = RemainingCurriculum(
  standaloneCount: 130,
  lessonRuns: List.generate(96, (i) => 4 + i % 5),
);

UserModel _user(String id, String name, UserRole role) => UserModel(
  id: id,
  email: '$id@example.com',
  name: name,
  role: role,
  createdAt: DateTime(2026, 1, 1),
);

StudentModel _student(
  String id, {
  int level = 2,
  int juz = 29,
  int session = 12,
  int order = 12,
  SessionKind kind = SessionKind.lesson,
  int pace = 2,
}) => StudentModel(
  id: id,
  userId: 'u-$id',
  instituteId: 'inst1',
  currentLevel: level,
  currentJuz: juz,
  currentSession: session,
  currentSessionId: 'L${level}_J${juz}_S$session',
  currentSessionKind: kind,
  currentOrderInLevel: order,
  pace: CurriculumPace(pace),
  createdAt: DateTime(2026, 1, 1),
);

/// A fake auth notifier: never touches Firebase; the teacher list only
/// watches it for reactivity.
class _FakeAuthRepository extends AuthRepository {
  @override
  AuthState build() => const AuthState();
}

// ─── Student ─────────────────────────────────────────────────────────────

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  @override
  Widget build(BuildContext context) {
    return StudentDashboardView(
      data: const StudentDashboardData(
        name: 'أحمد عبد الرحمن',
        percent: 34,
        fraction: 0.34,
        juzMemorized: 4,
        currentLevel: 3,
        streakDays: 5,
        weekBeads: _mockBeads,
        passedSessions: 41,
        totalSessions: 47,
        unlockedLevels: [1, 2, 3],
        completedLevels: [1, 2],
        session: DashboardSessionInfo(
          kind: DashboardSessionKind.talqeen,
          title: 'تلقين',
          subtitle: 'الجزء 30',
          passage: 'سورة النبأ ١–١٦',
          note:
              'سيقرأ المعلّم هذا المقطع معك ويكرره معك. لا حفظ عليك ولا '
              'تسميع ولا تقييم في هذه الحلقة.',
        ),
      ),
      practiceCard: HomePracticeCardBody(
        assignmentDone: 6,
        assignmentRequired: 10,
        todayRepetitions: 3,
        streakDays: 5,
        totalRepetitions: 214,
        onLog: () {},
      ),
      forecastCard: ProviderScope(
        overrides: [
          remainingCurriculumProvider((
            level: 2,
            order: 12,
            completed: false,
          )).overrideWith((ref) async => _mockRemaining),
        ],
        child: CompletionForecastCard(
          student: _student('s1'),
          margin: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _HomePracticePreview extends StatelessWidget {
  const _HomePracticePreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التكرار في المنزل')),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: HomePracticeView(
          data: const HomePracticeData(
            assignmentDone: 6,
            assignmentRequired: 10,
            todayRepetitions: 3,
            streakDays: 5,
            totalRepetitions: 214,
            weekBeads: _mockBeads,
            sessionTitle: 'الحلقة 12',
            sessionSubtitle: 'المستوى 3 - الجزء 30',
            history: [
              PracticeHistoryEntry(
                repetitions: 3,
                title: 'الحلقة 12',
                dateLabel: 'الأربعاء، 15 يوليو 2026',
              ),
              PracticeHistoryEntry(
                repetitions: 5,
                title: 'الحلقة 12',
                dateLabel: 'الثلاثاء، 14 يوليو 2026',
              ),
              PracticeHistoryEntry(
                repetitions: 4,
                title: 'الحلقة 11',
                dateLabel: 'الاثنين، 13 يوليو 2026',
              ),
            ],
          ),
          onSubmit: (repetitions, notes) async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            return true;
          },
        ),
      ),
    );
  }
}

// ─── Teacher ─────────────────────────────────────────────────────────────

class _TeacherPreview extends StatelessWidget {
  const _TeacherPreview();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith(_FakeAuthRepository.new),
        teacherInstitutesProvider.overrideWith((ref) async => []),
        filteredTeacherStudentsProvider.overrideWith(
          (ref) async => [
            StudentWithUser(
              student: _student('s1', kind: SessionKind.lesson),
              user: _user('s1', 'أحمد عبد الرحمن', UserRole.student),
            ),
            StudentWithUser(
              student: _student(
                's2',
                level: 1,
                juz: 30,
                session: 68,
                order: 68,
                kind: SessionKind.exam,
              ),
              user: _user('s2', 'يوسف الحسن', UserRole.student),
            ),
            StudentWithUser(
              student: _student(
                's3',
                level: 2,
                juz: 28,
                session: 31,
                order: 31,
                kind: SessionKind.sard,
              ),
              user: _user('s3', 'عمر خالد', UserRole.student),
            ),
          ],
        ),
        levelProvider.overrideWith(
          (ref, int level) async => LevelModel(
            id: 'level_$level',
            levelNumber: level,
            nameAr: 'المستوى $level',
            nameEn: 'Level $level',
            juzNumbers: const [29, 28],
            sessionCount: 142,
            juz: const [],
            order: level,
          ),
        ),
      ],
      child: const TeacherStudentsScreen(),
    );
  }
}

PacedSession _mockMeeting() {
  const session = SessionModel(
    id: 'L2_J29_S12',
    levelId: 2,
    juzNumber: 29,
    sessionNumber: 12,
    orderInLevel: 12,
    kind: SessionKind.lesson,
    unitIndex: 1,
    hizbNumber: 57,
    currentLevelContent: QuranContent(
      fromSurah: 'الملك',
      fromVerse: 1,
      toSurah: 'الملك',
      toVerse: 15,
    ),
    recentReviewContent: QuranContent(
      fromSurah: 'القلم',
      fromVerse: 1,
      toSurah: 'القلم',
      toVerse: 30,
    ),
    distantReviewContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'المرسلات',
      toVerse: 50,
    ),
  );
  return PacedSession(
    sessions: [session],
    newContent: [session.currentLevelContent!],
    recentReview: [session.recentReviewContent!],
    distantReview: [session.distantReviewContent!],
  );
}

class _StudentProfilePreview extends StatelessWidget {
  const _StudentProfilePreview();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        studentProvider('s1').overrideWith(
          (ref) async => StudentWithUser(
            student: _student('s1', kind: SessionKind.lesson),
            user: _user('s1', 'أحمد عبد الرحمن', UserRole.student),
          ),
        ),
        studentCurrentMeetingProvider(
          's1',
        ).overrideWith((ref) async => _mockMeeting()),
        teacherStudentSessionHistoryProvider(
          's1',
        ).overrideWith((ref) async => []),
        remainingCurriculumProvider((
          level: 2,
          order: 12,
          completed: false,
        )).overrideWith((ref) async => _mockRemaining),
      ],
      child: const StudentProfileScreen(studentId: 's1'),
    );
  }
}

class _RecitationPreview extends StatelessWidget {
  final int part;

  const _RecitationPreview({required this.part});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        studentCurrentMeetingProvider(
          's1',
        ).overrideWith((ref) async => _mockMeeting()),
      ],
      child: RecitationScreen(studentId: 's1', part: part),
    );
  }
}

// ─── Supervisor ──────────────────────────────────────────────────────────

class _SupervisorPreview extends StatelessWidget {
  const _SupervisorPreview();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          _user('sup1', 'خالد المصري', UserRole.supervisor),
        ),
        supervisorStatsProvider.overrideWith(
          (ref) async => const SupervisorStats(
            pendingExams: 7,
            completedToday: 12,
            passedToday: 9,
            failedToday: 3,
          ),
        ),
      ],
      child: const SupervisorDashboardScreen(),
    );
  }
}

// ─── Admin ───────────────────────────────────────────────────────────────

// ─── Splash ──────────────────────────────────────────────────────────────

/// The brand splash, scrubbable: `/?tab=9&p=0.5` renders the choreography
/// frozen at progress 0.5 for deterministic screenshots; the slider scrubs
/// it live and «تشغيل» replays the real self-dismissing overlay.
class _SplashPreview extends StatefulWidget {
  const _SplashPreview();

  @override
  State<_SplashPreview> createState() => _SplashPreviewState();
}

class _SplashPreviewState extends State<_SplashPreview> {
  double _progress =
      double.tryParse(Uri.base.queryParameters['p'] ?? '') ?? 1.0;
  int _replayKey = 0;
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    if (_playing) {
      return SplashOverlay(
        key: ValueKey(_replayKey),
        child: Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => setState(() {
                _replayKey++;
                _playing = true;
              }),
              child: const Text('إعادة التشغيل'),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: BrandSplashView(progress: _progress)),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => setState(() {
                    _replayKey++;
                    _playing = true;
                  }),
                  child: const Text('تشغيل'),
                ),
                Expanded(
                  child: Slider(
                    value: _progress,
                    onChanged: (v) => setState(() => _progress = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminPreview extends StatelessWidget {
  const _AdminPreview();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        adminStatsProvider.overrideWith(
          (ref) async => const AdminStats(
            institutesCount: 3,
            teachersCount: 14,
            supervisorsCount: 4,
            studentsCount: 87,
          ),
        ),
      ],
      child: const AdminDashboardScreen(),
    );
  }
}
