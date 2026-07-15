import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/next_content_talqeen_screen.dart';
import 'package:al_rasikhoon/shared/widgets/app_card.dart';
import 'package:al_rasikhoon/shared/widgets/session_timer.dart';

/// The closing تلقين step (NextContentTalqeenScreen) must show the live session
/// timer just like the recitation flow, so the teacher keeps seeing elapsed
/// time right up to the point the الحلقة is ended (al_rasikhoon-drc). It is
/// placed as a filled pill in the passage card's header — the same content-card
/// header treatment the recitation screen uses (al_rasikhoon-8z6) — so this
/// proves the timer renders and lives inside the content card.
void main() {
  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        // A real student so `currentLevel` resolves and the screen renders the
        // passage card (not its loading spinner); the timer also reads pace off
        // this same student.
        studentProvider('s1').overrideWith(
          (ref) async => StudentWithUser(student: student, user: user),
        ),
        // The closing تلقين previews the NEXT meeting's passage; a null preview
        // renders the no-new-content card, which is enough to place the timer.
        activeSessionNextMeetingProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);

    // Seed an active session so the live timer has a start instant to tick
    // from — without one it collapses to an empty box and there is nothing to
    // place.
    container
        .read(activeSessionProvider.notifier)
        .seedForTest(
          ActiveSessionState(studentId: 's1', startedAt: DateTime.now()),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: NextContentTalqeenScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    // Single-pump (not pumpAndSettle) so the SessionTimer's periodic ticker
    // doesn't keep the tree busy; several pumps let the chained async overrides
    // (student → next-meeting preview) resolve to a frame that renders the
    // passage card + timer.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the live timer renders in the closing تلقين passage card', (
    tester,
  ) async {
    await pump(tester);

    // The timer is present…
    expect(find.byType(SessionTimer), findsOneWidget);

    // …and it lives in the passage card's header, consistent with the
    // recitation screen's content-card timer pill.
    expect(
      find.descendant(
        of: find.byType(AppCard),
        matching: find.byType(SessionTimer),
      ),
      findsOneWidget,
    );

    // Dispose the tree so the timer's periodic ticker is cancelled and the
    // test binding doesn't flag a still-pending Timer.
    await tester.pumpWidget(const SizedBox());
  });
}
