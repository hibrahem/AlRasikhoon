// Design-preview harness: renders the redesigned student screens with mock
// data and NO Firebase, so the visual direction can be reviewed on
// `flutter run -d web-server -t lib/preview_main.dart`.
//
// Dark mode follows the platform (ThemeMode.system), so the browser's
// prefers-color-scheme toggles it without any preview-only chrome.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/student/widgets/home_practice_card.dart';
import 'features/student/widgets/home_practice_view.dart';
import 'features/student/widgets/student_dashboard_view.dart';

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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_index) {
        0 => const _DashboardPreview(),
        _ => const _HomePracticePreview(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(icon: Icon(Icons.repeat), label: 'التكرار'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

const _mockBeads = [true, true, false, true, true, true, true];

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
