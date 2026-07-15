import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

UserModel _teacher() => UserModel(
  id: 't1',
  username: 'teacher_one',
  email: 'teacher_one@alrasikhoon.local',
  name: 'المعلم',
  role: UserRole.teacher,
  createdAt: DateTime(2024),
);

InstituteModel _institute(String id) => InstituteModel(
  id: id,
  name: 'معهد $id',
  location: 'الرياض',
  createdBy: 'admin1',
  createdAt: DateTime(2024),
);

void main() {
  test(
    'teacherStatsProvider composes counts, roster size and institutes',
    () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 5);
      final lastMonth = DateTime(
        now.year,
        now.month,
        1,
      ).subtract(const Duration(days: 5));

      // Two records this month, one earlier → total 3, this-month 2.
      for (final date in [thisMonth, thisMonth, lastMonth]) {
        await fakeFirestore.collection('session_records').add({
          'teacher_id': 't1',
          'date': Timestamp.fromDate(date),
        });
      }
      // A record for a different teacher must not be counted.
      await fakeFirestore.collection('session_records').add({
        'teacher_id': 't2',
        'date': Timestamp.fromDate(thisMonth),
      });

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_teacher()),
          sessionRepositoryProvider.overrideWithValue(
            SessionRepository(firestore: fakeFirestore),
          ),
          teacherStudentsProvider.overrideWith(
            (ref) async => <StudentWithUser>[],
          ),
          teacherInstitutesProvider.overrideWith(
            (ref) async => [_institute('a'), _institute('b')],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Roster size is asserted independently of its element type, so an empty
      // roster (0 students) is the simplest correct fixture; institutes carry 2.
      final stats = await container.read(teacherStatsProvider.future);

      expect(stats.totalSessions, 3);
      expect(stats.sessionsThisMonth, 2);
      expect(stats.studentCount, 0);
      expect(stats.instituteCount, 2);
    },
  );

  test('teacherStatsProvider returns empty stats when signed out', () async {
    final container = ProviderContainer(
      overrides: [currentUserProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    final stats = await container.read(teacherStatsProvider.future);

    expect(stats.totalSessions, 0);
    expect(stats.sessionsThisMonth, 0);
    expect(stats.studentCount, 0);
    expect(stats.instituteCount, 0);
  });
}
