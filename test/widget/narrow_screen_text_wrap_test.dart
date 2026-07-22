import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/theme/app_theme.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/assessment/assessment_evaluation.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/next_content_talqeen_screen.dart';
import 'package:al_rasikhoon/shared/widgets/assessment_error_counters.dart';
import 'package:al_rasikhoon/shared/widgets/assessment_outcome_display.dart';
import 'package:al_rasikhoon/shared/widgets/stat_card.dart';

/// Arabic labels must survive a narrow phone with the system font size turned
/// up (the low-DPI Android report): the closing-تلقين card title was wrapping
/// one glyph per line because the timer pill squeezed its Expanded to a
/// sliver, and the assessment table's header words (التنبيهات، التلقينات…)
/// were breaking mid-word inside their equal-width columns and reading as cut
/// off. These tests pump both layouts at 320dp with textScale 1.4 and assert
/// the labels stay readable.
void main() {
  /// A 320dp-wide phone with the system font size turned up — the shape of
  /// device the cutoff was reported on. (The test font renders Arabic much
  /// narrower than the real Cairo face, so [textScale] here is higher than
  /// what triggers the bug on a device.)
  void useNarrowLargeFontView(WidgetTester tester, {double textScale = 1.4}) {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  /// The height [text] takes when laid out on ONE unconstrained line, using
  /// the exact resolved style and scale of its rendered paragraph — so the
  /// assertion self-calibrates to whatever font the test environment serves.
  double singleLineHeight(WidgetTester tester, Finder finder, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final painter = TextPainter(
      text: TextSpan(text: text, style: paragraph.text.style),
      textDirection: TextDirection.rtl,
      textScaler: paragraph.textScaler,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  group('assessment breakdown table', () {
    Future<void> pumpTable(WidgetTester tester) async {
      // 2.0 — Android's largest font-size step. The real Cairo face is wide
      // enough that on-device the headers break at smaller scales already.
      useNarrowLargeFontView(tester, textScale: 2.0);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AssessmentBreakdownTable(
                  units: const [
                    RecitationErrorTally(tanbeehat: 1, talqeenat: 1),
                    RecitationErrorTally(tashkeel: 1, tajweed: 1),
                  ],
                  limits: ExamEvaluation.limits,
                  unitLabelAr: (i) => 'السؤال ${i + 1}',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('header words are never broken mid-word on a narrow phone', (
      tester,
    ) async {
      await pumpTable(tester);
      expect(tester.takeException(), isNull);

      // Each header word must render on ONE line: any taller than its own
      // unconstrained single-line height means it broke mid-word inside its
      // column and reads as clipped (التنبيها / ت).
      for (final type in RecitationErrorType.values) {
        final header = find.text(type.nameAr);
        expect(
          tester.getSize(header).height,
          moreOrLessEquals(
            singleLineHeight(tester, header, type.nameAr),
            epsilon: 1.0,
          ),
          reason: '${type.nameAr} wrapped onto more than one line',
        );
      }
    });
  });

  group('assessment error counter board', () {
    testWidgets('error names stay whole beside the counter buttons', (
      tester,
    ) async {
      useNarrowLargeFontView(tester, textScale: 2.0);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AssessmentErrorCounters(
                  tally: const RecitationErrorTally(tanbeehat: 12),
                  limits: ExamEvaluation.limits,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // The two round buttons and the count keep their width, so the label
      // column takes the squeeze — each one-word error name must still land
      // on a single line (shrunk, never broken mid-word).
      for (final type in RecitationErrorType.values) {
        final label = find.text(type.nameAr);
        expect(
          tester.getSize(label).height,
          moreOrLessEquals(
            singleLineHeight(tester, label, type.nameAr),
            epsilon: 1.0,
          ),
          reason: '${type.nameAr} wrapped onto more than one line',
        );
      }
    });
  });

  group('dashboard stat grid', () {
    testWidgets('tiles grow with the system font size instead of clipping', (
      tester,
    ) async {
      useNarrowLargeFontView(tester, textScale: 2.0);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) => GridView(
                  gridDelegate: statCardGridDelegate(context),
                  children: const [
                    StatCard(
                      title: 'اختبارات معلقة',
                      value: '12',
                      icon: Icons.pending_actions,
                    ),
                    StatCard(
                      title: 'الطلاب',
                      value: '245',
                      icon: Icons.school,
                      subtitle: 'طالب نشط',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // A truly fixed 132px tile height clipped the numeral off the bottom
      // ("BOTTOM OVERFLOWED") once the text scaled up.
      expect(tester.takeException(), isNull);
    });
  });

  group('closing تلقين passage card', () {
    final student = StudentModel(
      id: 's1',
      userId: 'u1',
      instituteId: 'inst1',
      currentLevel: 1,
      createdAt: DateTime(2026),
    );

    final user = UserModel(
      id: 'u1',
      email: 'student@example.com',
      name: 'طالب',
      role: UserRole.student,
      createdAt: DateTime(2026),
    );

    /// A next meeting WITH new content, so the card renders the reported
    /// title (المقطع القادم للتلقين) alongside the timer pill.
    final nextMeeting = PacedSession(
      sessions: const [
        SessionModel(
          id: 'L1_J30_S2',
          levelId: 1,
          juzNumber: 30,
          sessionNumber: 2,
          orderInLevel: 2,
          kind: SessionKind.lesson,
          assessedBy: AssessedBy.teacher,
        ),
      ],
      newContent: const [
        QuranContent(
          fromSurah: 'إبراهيم',
          fromVerse: 9,
          toSurah: 'إبراهيم',
          toVerse: 18,
        ),
      ],
      recentReview: const [],
      distantReview: const [],
    );

    Future<void> pumpScreen(WidgetTester tester) async {
      useNarrowLargeFontView(tester);

      final container = ProviderContainer(
        overrides: [
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          activeSessionNextMeetingProvider.overrideWith(
            (ref) async => nextMeeting,
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(activeSessionProvider.notifier)
          .seedForTest(
            ActiveSessionState(studentId: 's1', startedAt: DateTime.now()),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: NextContentTalqeenScreen(studentId: 's1'),
            ),
          ),
        ),
      );
      // Single pumps (not pumpAndSettle) — the timer ticks forever.
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the card title is not squeezed into a one-glyph column', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(tester.takeException(), isNull);

      final title = find.text('المقطع القادم للتلقين');
      expect(title, findsOneWidget);

      final size = tester.getSize(title);
      // Squeezed to a sliver, the title rendered ~1 glyph per line: a ~40px
      // wide, ~400px tall column. Readable means a real share of the card's
      // width and at most a couple of lines of height.
      expect(
        size.width,
        greaterThan(120),
        reason: 'title got a sliver of width and wrapped per glyph',
      );
      expect(
        size.height,
        lessThan(150),
        reason: 'title stacked into a tall one-glyph column',
      );

      // Dispose the tree so the timer's ticker is cancelled.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
