import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/features/teacher/screens/add_student_screen.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

const _teacherId = 'teacher1';
const _instituteId = 'institute1';

UserModel _teacher() => UserModel(
  id: _teacherId,
  email: 'teacher@example.com',
  name: 'المعلم أحمد',
  role: UserRole.teacher,
  createdAt: DateTime(2024, 1, 1),
);

/// Seeds one institute assigned to [_teacherId] (so AddStudentScreen's
/// institute dropdown auto-selects it) and a curriculum whose only level has
/// no sessions at all for its (auto-selected) first juz — the picker therefore
/// has nothing valid to report, exactly the "empty juz" gap the submit guard
/// exists for (finding 2 / AgDR review, fix pass 2).
Future<FakeFirebaseFirestore> _seedNoSessionCurriculum() async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('institutes').doc(_instituteId).set({
    'name': 'معهد الاختبار',
    'location': 'الرياض',
    'created_by': 'admin',
    'created_at': Timestamp.now(),
    'is_active': true,
  });
  await firestore.collection('teacher_institutes').add({
    'teacher_id': _teacherId,
    'institute_id': _instituteId,
    'is_active': true,
  });

  // Level 1 exists but no session documents are seeded for it at all, so juz
  // 30 (the first juz level 1 teaches, and the picker's default) has none to
  // offer.
  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30, 29, 28],
    'session_count': 204,
    'order': 1,
  });

  return firestore;
}

Future<void> _pumpAddStudentScreen(
  WidgetTester tester,
  FakeFirebaseFirestore firestore,
  _MockFirebaseService firebaseService,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(firestore),
        firebaseServiceProvider.overrideWithValue(firebaseService),
        currentUserProvider.overrideWithValue(_teacher()),
      ],
      child: const MaterialApp(home: AddStudentScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_teacher());
  });

  testWidgets(
    'refuses to submit, and creates nothing, when the curriculum picker '
    'has no valid starting position (empty juz)',
    (tester) async {
      final firestore = await _seedNoSessionCurriculum();
      final firebaseService = _MockFirebaseService();
      await _pumpAddStudentScreen(tester, firestore, firebaseService);

      // The picker has settled on juz 30 with no sessions to offer — its
      // banner confirms there is nothing to start at.
      expect(
        find.textContaining('لا توجد حلقات لهذا الجزء في المنهج'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'طالب جديد');
      await tester.enterText(find.byType(TextFormField).at(1), 'new_student');
      await tester.enterText(find.byType(TextFormField).at(2), 'pass123');
      await tester.enterText(find.byType(TextFormField).at(3), 'pass123');
      await tester.pumpAndSettle();

      final submitButton = find.text('إضافة الطالب');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Nothing was written and no account was provisioned — the guard in
      // AddStudentScreen._handleCreate must have refused before any of
      // that, purely because _startingPosition was null.
      final students = await firestore.collection('students').get();
      expect(students.docs, isEmpty);
      verifyNever(
        () => firebaseService.provisionUserAccount(
          email: any(named: 'email'),
          password: any(named: 'password'),
          role: any(named: 'role'),
          name: any(named: 'name'),
          username: any(named: 'username'),
          phone: any(named: 'phone'),
          instituteId: any(named: 'instituteId'),
        ),
      );

      expect(
        find.text('يرجى اختيار نقطة بداية صالحة في المنهج'),
        findsOneWidget,
      );
    },
  );
}
