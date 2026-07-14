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

const _supervisorId = 'supervisor1';
const _teacherId = 'teacher1';
const _instituteId = 'institute1';

UserModel _supervisor() => UserModel(
  id: _supervisorId,
  email: 'supervisor@example.com',
  name: 'المشرف سالم',
  role: UserRole.supervisor,
  instituteId: _instituteId,
  createdAt: DateTime(2024, 1, 1),
);

/// Seeds the supervisor's bound institute (AgDR-0003), a curriculum with a
/// real starting session so the picker has a valid position to submit, and
/// (only when [withTeacher]) one teacher assigned to that institute — the
/// pool [AddStudentScreen] must offer a supervisor for the required teacher
/// picker (al_rasikhoon-6bw).
Future<FakeFirebaseFirestore> _seedInstitute({
  required bool withTeacher,
}) async {
  final firestore = FakeFirebaseFirestore();

  await firestore.collection('institutes').doc(_instituteId).set({
    'name': 'معهد الاختبار',
    'location': 'الرياض',
    'created_by': 'admin',
    'created_at': Timestamp.now(),
    'is_active': true,
  });

  if (withTeacher) {
    await firestore.collection('users').doc(_teacherId).set({
      'username': 'teacher1',
      'email': 'teacher1@example.com',
      'name': 'المعلم خالد',
      'role': 'teacher',
      'auth_provider': 'email_password',
      'created_at': Timestamp.now(),
      'is_active': true,
    });
    await firestore.collection('teacher_institutes').add({
      'teacher_id': _teacherId,
      'institute_id': _instituteId,
      'is_active': true,
    });
  }

  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'juz_numbers': [30, 29, 28],
    'session_count': 1,
    'order': 1,
  });
  await firestore.collection('sessions').doc('L1_J30_S1').set({
    'level_id': 1,
    'juz_number': 30,
    'session_number': 1,
    'order_in_level': 1,
    'kind': 'lesson',
    'hizb_number': 59,
    'current_level_content': {
      'from_surah': 'النبأ',
      'from_verse': 1,
      'to_surah': 'النبأ',
      'to_verse': 11,
    },
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
        currentUserProvider.overrideWithValue(_supervisor()),
      ],
      child: const MaterialApp(home: AddStudentScreen(asSupervisor: true)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_supervisor());
  });

  testWidgets(
    'a supervisor cannot create a student without choosing a teacher — the '
    'submit is refused and NO student document is written (al_rasikhoon-6bw)',
    (tester) async {
      final firestore = await _seedInstitute(withTeacher: true);
      final firebaseService = _MockFirebaseService();
      await _pumpAddStudentScreen(tester, firestore, firebaseService);

      // A teacher exists in the institute, but the supervisor never picks
      // one — the picker is left on its unselected hint.
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

      // Nothing was written and no account was provisioned — the guard must
      // refuse before any of that, purely because no teacher was selected.
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

      expect(find.text('يرجى اختيار المعلم'), findsOneWidget);
    },
  );
}
