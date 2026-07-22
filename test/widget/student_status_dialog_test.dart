import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/student/student_status.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';
import 'package:al_rasikhoon/shared/widgets/app_button.dart';
import 'package:al_rasikhoon/shared/widgets/student_status_dialog.dart';

class MockStudentRepository extends Mock implements StudentRepository {}

/// Pins the exclusion dialog (al_rasikhoon-zg1r): a supervisor or admin
/// toggles a student between نشط and مستبعد with an OPTIONAL free-text
/// reason; restoring shows the stored reason for context.
void main() {
  setUpAll(() {
    registerFallbackValue(StudentStatus.active);
    registerFallbackValue(
      UserModel(
        id: 'fallback',
        email: 'fallback@example.com',
        name: 'fallback',
        role: UserRole.supervisor,
        createdAt: DateTime(2026),
      ),
    );
  });

  final supervisor = UserModel(
    id: 'sup1',
    email: 'sup@example.com',
    name: 'مشرف',
    role: UserRole.supervisor,
    createdAt: DateTime(2026),
  );

  StudentModel student({
    StudentStatus status = StudentStatus.active,
    String? reason,
  }) => StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'i1',
    createdAt: DateTime(2026),
    status: status,
    statusReason: reason,
  );

  Future<MockStudentRepository> pumpDialog(
    WidgetTester tester,
    StudentModel s,
  ) async {
    final repo = MockStudentRepository();
    when(
      () => repo.setStudentStatus(
        studentId: any(named: 'studentId'),
        status: any(named: 'status'),
        reason: any(named: 'reason'),
        actor: any(named: 'actor'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWithValue(supervisor),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StudentStatusDialog(
              student: s,
              studentDisplayName: 'أحمد',
              onChanged: () {},
            ),
          ),
        ),
      ),
    );
    return repo;
  }

  testWidgets('excluding an active student sends excluded with the reason', (
    tester,
  ) async {
    final repo = await pumpDialog(tester, student());

    await tester.enterText(find.byType(TextField), 'غياب متكرر');
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repo.setStudentStatus(
        studentId: captureAny(named: 'studentId'),
        status: captureAny(named: 'status'),
        reason: captureAny(named: 'reason'),
        actor: captureAny(named: 'actor'),
      ),
    ).captured;
    // Mocktail orders `captured` by required-named-params-in-declaration-order
    // first, then optional-named-params — not by the order written in this
    // verify() call. `reason` is the only optional parameter on
    // StudentRepository.setStudentStatus, so it lands last (index 3), after
    // the required studentId/status/actor (indices 0-2).
    expect(captured[0], 's1');
    expect(captured[1], StudentStatus.excluded);
    expect((captured[2] as UserModel).id, 'sup1');
    expect(captured[3], 'غياب متكرر');
  });

  testWidgets('the reason is optional — an empty field still submits', (
    tester,
  ) async {
    final repo = await pumpDialog(tester, student());

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    verify(
      () => repo.setStudentStatus(
        studentId: any(named: 'studentId'),
        status: any(named: 'status'),
        reason: any(named: 'reason'),
        actor: any(named: 'actor'),
      ),
    ).called(1);
  });

  testWidgets(
    'restoring an excluded student shows the stored reason and sends active',
    (tester) async {
      final repo = await pumpDialog(
        tester,
        student(status: StudentStatus.excluded, reason: 'غياب متكرر'),
      );

      // The dialog surfaces WHY the student was excluded before undoing it.
      expect(find.textContaining('غياب متكرر'), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      final captured = verify(
        () => repo.setStudentStatus(
          studentId: captureAny(named: 'studentId'),
          status: captureAny(named: 'status'),
          reason: captureAny(named: 'reason'),
          actor: captureAny(named: 'actor'),
        ),
      ).captured;
      expect(captured[1], StudentStatus.active);
    },
  );
}
