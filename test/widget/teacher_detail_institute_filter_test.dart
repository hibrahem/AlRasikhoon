import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/admin/providers/admin_provider.dart';
import 'package:al_rasikhoon/features/admin/screens/teacher_detail_screen.dart';
import 'package:al_rasikhoon/shared/widgets/student_card.dart';

/// Counts how many StudentCards display [name] as a badge (text scoped to a
/// StudentCard subtree). Independent of the assigned-institutes section and
/// the filter chips, which also render institute names elsewhere on screen.
Finder _badgesNamed(String name) => find.descendant(
      of: find.byType(StudentCard),
      matching: find.text(name),
    );

/// Widget tests for the admin teacher-detail institute filter —
/// hibrahem/AlRasikhoon#53. Reuses the existing StudentWithUser domain via
/// teacherProvider + institutesForTeacherProvider + studentsForTeacherAdminProvider.

const _teacherId = 't1';

UserModel _teacher() => UserModel(
      id: _teacherId,
      email: 'teacher@example.com',
      name: 'المعلم أحمد',
      role: UserRole.teacher,
      createdAt: DateTime(2024, 1, 1),
    );

InstituteModel _institute(String id, String name) => InstituteModel(
      id: id,
      name: name,
      location: 'الموقع',
      createdBy: 'admin',
      createdAt: DateTime(2024, 1, 1),
    );

StudentWithUser _student({
  required String id,
  required String name,
  required String instituteId,
}) {
  return StudentWithUser(
    student: StudentModel(
      id: id,
      userId: 'u_$id',
      instituteId: instituteId,
      teacherId: _teacherId,
      createdAt: DateTime(2024, 1, 1),
    ),
    user: UserModel(
      id: 'u_$id',
      email: '$id@example.com',
      name: name,
      role: UserRole.student,
      createdAt: DateTime(2024, 1, 1),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<InstituteModel> institutes,
  required List<StudentWithUser> students,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teacherProvider(_teacherId).overrideWith((ref) async => _teacher()),
        institutesForTeacherProvider(_teacherId)
            .overrideWith((ref) async => institutes),
        studentsForTeacherAdminProvider(_teacherId)
            .overrideWith((ref) async => students),
      ],
      child: const MaterialApp(
        home: TeacherDetailScreen(teacherId: _teacherId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TeacherDetailScreen institute filter (#53)', () {
    final institutes = [
      _institute('i1', 'معهد النور'),
      _institute('i2', 'معهد الهدى'),
    ];
    final students = [
      _student(id: 's1', name: 'الطالب سالم', instituteId: 'i1'),
      _student(id: 's2', name: 'الطالب خالد', instituteId: 'i2'),
      _student(id: 's3', name: 'الطالب يوسف', instituteId: 'i1'),
    ];

    testWidgets('default shows all students with institute badges',
        (tester) async {
      await _pump(tester, institutes: institutes, students: students);

      // All three students visible by default.
      expect(find.text('الطالب سالم'), findsOneWidget);
      expect(find.text('الطالب خالد'), findsOneWidget);
      expect(find.text('الطالب يوسف'), findsOneWidget);

      // Spanning >1 institute -> per-card badges render. Two students in
      // معهد النور (i1), one in معهد الهدى (i2).
      expect(_badgesNamed('معهد النور'), findsNWidgets(2));
      expect(_badgesNamed('معهد الهدى'), findsOneWidget);

      // "All" affordance present.
      expect(find.widgetWithText(FilterChip, 'الكل'), findsOneWidget);
    });

    testWidgets('selecting one institute filters the list to that institute',
        (tester) async {
      await _pump(tester, institutes: institutes, students: students);

      // Tap the معهد الهدى (i2) chip.
      await tester.tap(find.widgetWithText(FilterChip, 'معهد الهدى'));
      await tester.pumpAndSettle();

      // Only the i2 student remains.
      expect(find.text('الطالب خالد'), findsOneWidget);
      expect(find.text('الطالب سالم'), findsNothing);
      expect(find.text('الطالب يوسف'), findsNothing);
    });

    testWidgets(
        'single visible institute hides the per-card badge (chip conveys it)',
        (tester) async {
      await _pump(tester, institutes: institutes, students: students);

      await tester.tap(find.widgetWithText(FilterChip, 'معهد الهدى'));
      await tester.pumpAndSettle();

      // Single visible institute -> no per-card badge (the chip conveys it).
      expect(_badgesNamed('معهد الهدى'), findsNothing);
    });

    testWidgets('selecting all institutes shows every student', (tester) async {
      await _pump(tester, institutes: institutes, students: students);

      await tester.tap(find.widgetWithText(FilterChip, 'معهد النور'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'معهد الهدى'));
      await tester.pumpAndSettle();

      // Both institutes selected -> all students visible again.
      expect(find.text('الطالب سالم'), findsOneWidget);
      expect(find.text('الطالب خالد'), findsOneWidget);
      expect(find.text('الطالب يوسف'), findsOneWidget);
    });

    testWidgets('"All" chip resets the filter back to every student',
        (tester) async {
      await _pump(tester, institutes: institutes, students: students);

      // Narrow to i2 first.
      await tester.tap(find.widgetWithText(FilterChip, 'معهد الهدى'));
      await tester.pumpAndSettle();
      expect(find.text('الطالب سالم'), findsNothing);

      // Tap "All" to reset.
      await tester.tap(find.widgetWithText(FilterChip, 'الكل'));
      await tester.pumpAndSettle();

      expect(find.text('الطالب سالم'), findsOneWidget);
      expect(find.text('الطالب خالد'), findsOneWidget);
      expect(find.text('الطالب يوسف'), findsOneWidget);
    });

    testWidgets('selected institute with no students shows friendly empty state',
        (tester) async {
      // Only i1 students exist; selecting i2 yields an empty filtered list.
      final onlyI1 = [
        _student(id: 's1', name: 'الطالب سالم', instituteId: 'i1'),
      ];
      await _pump(tester, institutes: institutes, students: onlyI1);

      await tester.tap(find.widgetWithText(FilterChip, 'معهد الهدى'));
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد طلاب في المعهد المحدد'), findsOneWidget);
      expect(find.text('الطالب سالم'), findsNothing);
    });

    testWidgets('single-institute teacher: chips render, badge omitted',
        (tester) async {
      final oneInstitute = [_institute('i1', 'معهد النور')];
      final i1Students = [
        _student(id: 's1', name: 'الطالب سالم', instituteId: 'i1'),
        _student(id: 's3', name: 'الطالب يوسف', instituteId: 'i1'),
      ];
      await _pump(tester, institutes: oneInstitute, students: i1Students);

      // Chip still renders.
      expect(find.widgetWithText(FilterChip, 'معهد النور'), findsOneWidget);
      // List spans a single institute -> no per-card badge.
      expect(_badgesNamed('معهد النور'), findsNothing);
      expect(find.text('الطالب سالم'), findsOneWidget);
      expect(find.text('الطالب يوسف'), findsOneWidget);
    });
  });
}
