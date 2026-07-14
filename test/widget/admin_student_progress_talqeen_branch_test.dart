import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/admin_student_progress_screen.dart';

/// Pins the load-bearing branch of the admin/supervisor progress screen's
/// current-session card: a student standing on a تلقين MUST be shown as
/// being on a تلقين, never as an ordinary graded lesson. This mirrors the
/// same ordering already pinned for the teacher's screen
/// (`session_overview_talqeen_branch_test.dart`) and the student's dashboard
/// (`student_dashboard_talqeen_branch_test.dart`): the تلقين check MUST come
/// before isExam/isSard and before the regular-lesson fallthrough, or a
/// supervisor reviewing a student's progress would see the model's own
/// new-memorization framing ("الحفظ الجديد") for a session that is graded on
/// nothing and cannot be failed.
void main() {
  const talqeenSession = SessionModel(
    id: 'L1_J30_S1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    orderInLevel: 1,
    kind: SessionKind.talqeen,
    unitIndex: 1,
    hizbNumber: 59,
    currentLevelContent: QuranContent(
      fromSurah: 'النبأ',
      fromVerse: 1,
      toSurah: 'النبأ',
      toVerse: 11,
    ),
  );

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          adminStudentCurrentSessionProvider(
            's1',
          ).overrideWith((ref) async => talqeenSession),
          adminStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => const <SessionRecordModel>[]),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AdminStudentProgressScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a student standing on a تلقين is shown to the supervisor as being on a '
    'تلقين, not a graded lesson',
    (tester) async {
      await pump(tester);

      // The تلقين is named as what it is.
      expect(find.textContaining('تلقين'), findsWidgets);

      // The regular graded-lesson framing and its part tiles are absent — a
      // تلقين must never be displayed as new memorization for the student to
      // recite alone.
      expect(find.text('الحفظ الجديد'), findsNothing);
      expect(find.text('المراجعة القريبة'), findsNothing);
      expect(find.text('المراجعة البعيدة'), findsNothing);
    },
  );
}
