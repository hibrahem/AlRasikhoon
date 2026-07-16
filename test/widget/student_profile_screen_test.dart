import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/paced_session.dart';
import 'package:al_rasikhoon/domain/session/student_history_entry.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/features/teacher/screens/student_profile_screen.dart';

/// The consolidated student profile (al_rasikhoon-pb7): a teacher taps a
/// student and sees identity, level, progress, pace, the current session (which
/// they can START from here), AND that student's session history — all on one
/// screen. This pins that every one of those sections is present, so the
/// history can never silently drift back out into a separate tab.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  final regularSession = SessionModel(
    id: 'L2_J29_S7',
    levelId: 2,
    juzNumber: 29,
    sessionNumber: 7,
    orderInLevel: 7,
    kind: SessionKind.lesson,
    currentLevelContent: QuranContent(
      fromSurah: 'الملك',
      fromVerse: 1,
      toSurah: 'الملك',
      toVerse: 5,
    ),
  );

  final meeting = PacedSession(
    sessions: [regularSession],
    newContent: [regularSession.currentLevelContent!],
    recentReview: const [],
    distantReview: const [],
  );

  final user = UserModel(
    id: 'u1',
    username: 'ahmad99',
    email: 'ahmad@example.com',
    name: 'أحمد',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );

  final student = StudentModel(
    id: 's1',
    userId: 'u1',
    instituteId: 'inst1',
    currentSessionId: 'L2_J29_S7',
    currentSessionKind: SessionKind.lesson,
    currentLevel: 2,
    currentOrderInLevel: 7,
    createdAt: DateTime(2026),
  );

  StudentHistoryEntry record({
    required String id,
    required int sessionNumber,
    required bool passed,
    required DateTime date,
  }) {
    return StudentHistoryEntry(
      id: id,
      kind: StudentHistoryKind.lesson,
      levelId: 2,
      sessionNumber: sessionNumber,
      passed: passed,
      date: date,
      detailRecordId: id,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<StudentHistoryEntry> history,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // StudentLevelProgress reads levelProvider (Firestore); route it at
          // an empty fake so it renders its fallback instead of erroring
          // against an uninitialized Firebase app.
          firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
          studentProvider('s1').overrideWith(
            (ref) async => StudentWithUser(student: student, user: user),
          ),
          studentCurrentMeetingProvider(
            's1',
          ).overrideWith((ref) async => meeting),
          teacherStudentSessionHistoryProvider(
            's1',
          ).overrideWith((ref) async => history),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StudentProfileScreen(studentId: 's1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows identity, pace, current session with a start action, '
      'progress, and the embedded history — all on one screen', (tester) async {
    await pump(
      tester,
      history: [
        record(
          id: 'r1',
          sessionNumber: 6,
          passed: true,
          date: DateTime(2026, 3, 15),
        ),
      ],
    );

    // Identity: name + username.
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('اسم المستخدم: ahmad99'), findsOneWidget);

    // Pace control.
    expect(find.text('وتيرة الحفظ'), findsOneWidget);

    // Current session — with the START action reachable from the profile.
    expect(find.text('الحلقة الحالية'), findsOneWidget);
    expect(find.text('بدء الحلقة'), findsOneWidget);

    // Progress section heading.
    expect(find.text('التقدم في المستوى'), findsOneWidget);

    // Embedded history: the section heading and a record row for this student.
    expect(find.text('سجل الحلقات'), findsOneWidget);
    expect(find.text('الحلقة 6'), findsOneWidget);
    expect(find.text('نجح'), findsOneWidget);
  });

  testWidgets('a student with no prior sessions shows the empty history state, '
      'not an error', (tester) async {
    await pump(tester, history: const []);

    expect(find.text('سجل الحلقات'), findsOneWidget);
    expect(find.text('لا يوجد سجل للحلقات'), findsOneWidget);
    // The rest of the profile is unaffected.
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('بدء الحلقة'), findsOneWidget);
  });
}
