import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/shared/screens/student_progress_screen.dart';

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
///
/// It also pins the session-history LIST below the current-session card
/// (`_SessionHistoryList`): that list branches on `record.passed` and had no
/// تلقين check at all, so a تلقين record rendered as a phantom graded pass.
void main() {
  setUpAll(() async {
    // The history list formats dates with the Arabic locale.
    await initializeDateFormatting('ar');
  });

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

  // A تلقين record and a real, FAILED lesson record. The talqeen carries
  // `passed: true` unconditionally (it exists to record attendance and carry
  // the home assignment, not a grade) — if the history list branched only on
  // `record.passed`, this talqeen would render as a graded pass, and this
  // failed lesson would prove the list still uses `record.passed` at all.
  final talqeenRecord = SessionRecordModel(
    id: 'r-talqeen',
    studentId: 's1',
    teacherId: 't1',
    curriculumSessionId: 'L1_J30_S1',
    levelId: 1,
    kind: SessionKind.talqeen,
    juzNumber: 30,
    hizbNumber: 59,
    sessionNumber: 1,
    fromOrderInLevel: 1,
    toOrderInLevel: 1,
    coversSessionIds: const ['L1_J30_S1'],
    date: DateTime(2026, 7, 1),
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    passed: true,
    createdAt: DateTime(2026, 7, 1),
  );

  final failedLessonRecord = SessionRecordModel(
    id: 'r-lesson',
    studentId: 's1',
    teacherId: 't1',
    curriculumSessionId: 'L1_J30_S2',
    levelId: 1,
    kind: SessionKind.lesson,
    juzNumber: 30,
    hizbNumber: 59,
    sessionNumber: 2,
    fromOrderInLevel: 2,
    toOrderInLevel: 2,
    coversSessionIds: const ['L1_J30_S2'],
    date: DateTime(2026, 7, 2),
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 5,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    passed: false,
    createdAt: DateTime(2026, 7, 2),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStudentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          // A تلقين always stands alone (`PacedSessionComposer` never
          // batches one), so its meeting is a single-session `PacedSession`
          // built from the same row — the screen now reads the MEETING, not
          // the session directly.
          adminStudentCurrentMeetingProvider('s1').overrideWith(
            (ref) async => PacedSession(
              sessions: [talqeenSession],
              newContent: [
                if (talqeenSession.currentLevelContent != null)
                  talqeenSession.currentLevelContent!,
              ],
              recentReview: [
                if (talqeenSession.recentReviewContent != null)
                  talqeenSession.recentReviewContent!,
              ],
              distantReview: [
                if (talqeenSession.distantReviewContent != null)
                  talqeenSession.distantReviewContent!,
              ],
            ),
          ),
          adminStudentSessionHistoryProvider('s1').overrideWith(
            (ref) async => <StudentHistoryEntry>[
              StudentHistoryEntry(
                id: talqeenRecord.id,
                kind: StudentHistoryKind.talqeen,
                levelId: talqeenRecord.levelId,
                sessionNumber: talqeenRecord.sessionNumber,
                passed: talqeenRecord.passed,
                date: talqeenRecord.date,
                detailRecordId: talqeenRecord.id,
              ),
              StudentHistoryEntry(
                id: failedLessonRecord.id,
                kind: StudentHistoryKind.lesson,
                levelId: failedLessonRecord.levelId,
                sessionNumber: failedLessonRecord.sessionNumber,
                passed: failedLessonRecord.passed,
                date: failedLessonRecord.date,
                detailRecordId: failedLessonRecord.id,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            // The screen is role-agnostic (al_rasikhoon-801): the admin and the
            // supervisor get the same read-only view, each with their own
            // scoped providers injected. Here we inject the admin's.
            child: StudentProgressScreen(
              studentId: 's1',
              studentProvider: adminStudentProvider,
              currentMeetingProvider: adminStudentCurrentMeetingProvider,
              sessionHistoryProvider: adminStudentSessionHistoryProvider,
              sessionDetailRoute: '/admin/students/history/:recordId',
            ),
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

  testWidgets(
    'the session-history list shows a تلقين record as attendance, never as '
    'a graded pass, while a real failed lesson still shows رسب',
    (tester) async {
      await pump(tester);

      // The talqeen record: named as a تلقين both in its title and its badge
      // (two exact-text widgets), no pass badge, no fail badge — just
      // because `passed` happens to be `true` on the record must not make it
      // render as "نجح".
      expect(find.text('تلقين'), findsNWidgets(2));
      expect(find.text('نجح'), findsNothing);

      // The real lesson record still shows its own, genuine result.
      expect(find.text('رسب'), findsOneWidget);
      expect(find.text('الحلقة 2'), findsOneWidget);
    },
  );
}
