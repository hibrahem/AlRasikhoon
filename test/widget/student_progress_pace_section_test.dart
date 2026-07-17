import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';
import 'package:al_rasikhoon/shared/widgets/completion_forecast_card.dart';
import 'package:al_rasikhoon/shared/widgets/student_pace_control.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// The supervisor may set pace on the otherwise read-only progress screen
/// (al_rasikhoon-3qy): the router injects a `paceSection` built with the loaded
/// student. The admin shell injects nothing and stays read-only. This pins that
/// the screen renders the injected control, that it writes and refreshes on a
/// change, and that WITHOUT the section the screen shows no pace control at all.
void main() {
  setUpAll(() => registerFallbackValue(CurriculumPace.standard));

  /// Moves the pace slider to [multiplier] and releases — the write fires on
  /// release (onChangeEnd), which is the control's contract.
  Future<void> setPace(WidgetTester tester, int multiplier) async {
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(multiplier.toDouble());
    slider.onChangeEnd!(multiplier.toDouble());
    await tester.pumpAndSettle();
  }

  final lesson = SessionModel(
    id: 'L1_J30_S5',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 5,
    orderInLevel: 5,
    kind: SessionKind.lesson,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 5,
    ),
  );

  final meeting = PacedSession(
    sessions: [lesson],
    newContent: [lesson.currentLevelContent!],
    recentReview: const [],
    distantReview: const [],
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S5',
    currentSessionKind: SessionKind.lesson,
    currentOrderInLevel: 5,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester, {
    required StudentRepository repo,
    Widget Function(StudentModel)? paceSection,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          studentRepositoryProvider.overrideWithValue(repo),
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          adminStudentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
          adminStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => <StudentHistoryEntry>[]),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentProgressScreen(
              studentId: 's1',
              studentProvider: adminStudentProvider,
              currentMeetingProvider: adminStudentCurrentMeetingProvider,
              sessionHistoryProvider: adminStudentSessionHistoryProvider,
              sessionDetailRoute: '/admin/students/history/:recordId',
              assessmentDetailRoute:
                  '/admin/students/assessment/:kind/:recordId',
              paceSection: paceSection,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the injected pace control and writes on a change', (
    tester,
  ) async {
    final repo = MockStudentRepository();
    when(() => repo.setStudentPace(any(), any())).thenAnswer((_) async {});
    var refreshed = false;

    await pump(
      tester,
      repo: repo,
      paceSection: (s) => StudentPaceControl(
        student: s,
        onPlanChanged: (_) => refreshed = true,
      ),
    );

    expect(find.text('وتيرة الحفظ'), findsOneWidget);
    // A shell that injects the plan card gets NO standalone forecast card —
    // the plan card carries the forecast itself.
    expect(find.byType(CompletionForecastCard), findsNothing);

    await setPace(tester, 2);

    verify(() => repo.setStudentPace('s1', CurriculumPace(2))).called(1);
    // onPlanChanged fires only on a successful write.
    expect(refreshed, isTrue);
  });

  testWidgets('shows no pace control when no section is injected (admin)', (
    tester,
  ) async {
    await pump(tester, repo: MockStudentRepository(), paceSection: null);

    expect(find.text('وتيرة الحفظ'), findsNothing);
    // The read-only shell still gets the standalone forecast card.
    expect(find.byType(CompletionForecastCard), findsOneWidget);
  });

  testWidgets(
    'on a failed write, shows the error, reverts and does not fire onPlanChanged',
    (tester) async {
      final repo = MockStudentRepository();
      when(
        () => repo.setStudentPace(any(), any()),
      ).thenThrow(Exception('offline'));
      var refreshed = false;

      await pump(
        tester,
        repo: repo,
        paceSection: (s) => StudentPaceControl(
          student: s,
          onPlanChanged: (_) => refreshed = true,
        ),
      );

      await setPace(tester, 3);

      expect(find.text('تعذر تحديث وتيرة الحفظ'), findsOneWidget);
      // The optimistic slider value snaps back to what is actually stored.
      expect(find.text('1×'), findsOneWidget);
      expect(refreshed, isFalse);
    },
  );
}
