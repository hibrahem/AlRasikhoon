import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/supervisor/providers/supervisor_provider.dart';
import 'package:al_rasikhoon/features/supervisor/widgets/reposition_starting_point_section.dart';

/// The supervisor's "edit starting point" affordance (al_rasikhoon-sne) is
/// offered ONLY while the student has not started — zero progress records. Once
/// they have started, the section hides itself entirely (the edit is not
/// offered, and the server-side path rejects a stale attempt regardless). These
/// tests pin exactly that visibility rule.
void main() {
  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L1_J30_S1',
    currentSessionKind: SessionKind.talqeen,
    createdAt: DateTime(2026),
  );

  final user = UserModel(
    id: 'u1',
    email: 'student@example.com',
    name: 'طالب',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, {required bool hasStarted}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supervisorStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          supervisorStudentHasStartedProvider(
            's1',
          ).overrideWith((ref) async => hasStarted),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: RepositionStartingPointSection(studentId: 's1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers the edit affordance when the student has NOT started', (
    tester,
  ) async {
    await pump(tester, hasStarted: false);

    expect(
      find.byKey(const Key('reposition_starting_point_button')),
      findsOneWidget,
    );
    expect(find.text('تعديل نقطة البداية'), findsOneWidget);
  });

  testWidgets('hides the edit affordance once the student HAS started', (
    tester,
  ) async {
    await pump(tester, hasStarted: true);

    expect(
      find.byKey(const Key('reposition_starting_point_button')),
      findsNothing,
    );
    expect(find.text('تعديل نقطة البداية'), findsNothing);
  });
}
