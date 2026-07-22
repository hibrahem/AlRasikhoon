import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/admin/widgets/delete_student_dialog.dart';

class _MockStudentRepository extends Mock implements StudentRepository {}

void main() {
  late _MockStudentRepository studentRepository;

  setUp(() {
    studentRepository = _MockStudentRepository();
  });

  /// Pumps a screen with a button that opens the dialog, so the dialog sits
  /// on a real dialog route (its confirm/cancel paths pop a route) above a
  /// Scaffold (its outcome SnackBars need a ScaffoldMessenger).
  Future<void> pumpAndOpenDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRepositoryProvider.overrideWithValue(studentRepository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const DeleteStudentDialog(
                    studentId: 'student-1',
                    studentDisplayName: 'أحمد',
                  ),
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
  }

  group('DeleteStudentDialog', () {
    testWidgets('warns that the student and ALL their data are erased '
        'irreversibly before offering the delete', (tester) async {
      await pumpAndOpenDialog(tester);

      expect(find.text('حذف الطالب نهائيًا؟'), findsOneWidget);
      expect(find.textContaining('أحمد'), findsWidgets);
      expect(find.text('لا يمكن التراجع عن هذا الإجراء.'), findsOneWidget);
      expect(find.text('حذف نهائيًا'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpAndOpenDialog(tester);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('حذف الطالب نهائيًا؟'), findsNothing);
      verifyNever(() => studentRepository.hardDeleteStudent(any()));
    });

    testWidgets('confirming hard-deletes exactly the shown student and '
        'reports success', (tester) async {
      when(
        () => studentRepository.hardDeleteStudent(any()),
      ).thenAnswer((_) async {});

      await pumpAndOpenDialog(tester);
      await tester.tap(find.text('حذف نهائيًا'));
      await tester.pumpAndSettle();

      verify(() => studentRepository.hardDeleteStudent('student-1')).called(1);
      expect(find.text('حذف الطالب نهائيًا؟'), findsNothing);
      expect(find.textContaining('تم حذف الطالب'), findsOneWidget);
    });

    testWidgets('a failed delete keeps the dialog open and surfaces the '
        'error instead of pretending the student is gone', (tester) async {
      when(
        () => studentRepository.hardDeleteStudent(any()),
      ).thenThrow(Exception('boom'));

      await pumpAndOpenDialog(tester);
      await tester.tap(find.text('حذف نهائيًا'));
      await tester.pumpAndSettle();

      expect(find.text('حذف الطالب نهائيًا؟'), findsOneWidget);
      expect(find.textContaining('حدث خطأ'), findsOneWidget);
    });
  });
}
