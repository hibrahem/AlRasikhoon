import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/session_record_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/features/teacher/providers/teacher_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

/// Records the teacher recorded, keyed by nothing — the fake just returns them
/// in the order the real repository would (date descending).
class _FakeSessionRepository implements SessionRepository {
  final List<SessionRecordModel> records;

  _FakeSessionRepository(this.records);

  /// The `limit` the provider passed on its most recent call, so tests can
  /// confirm the query is bounded (al_rasikhoon-256: an unbounded query
  /// re-downloaded every session a teacher ever recorded on each refresh).
  int? lastLimit;

  @override
  Future<List<SessionRecordModel>> getSessionRecordsForTeacher(
    String teacherId, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    lastLimit = limit;
    return records.where((r) => r.teacherId == teacherId).toList();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel _teacher(String id) => UserModel(
  id: id,
  email: '$id@example.com',
  name: 'المعلم',
  role: UserRole.teacher,
  createdAt: DateTime(2024),
);

StudentWithUser _student({
  required String id,
  required String name,
  required String instituteId,
}) {
  final userId = 'user-$id';
  return StudentWithUser(
    student: StudentModel(
      id: id,
      userId: userId,
      instituteId: instituteId,
      teacherId: 'teacher1',
      createdAt: DateTime(2024),
    ),
    user: UserModel(
      id: userId,
      email: '$id@example.com',
      name: name,
      role: UserRole.student,
      createdAt: DateTime(2024),
    ),
  );
}

SessionRecordModel _record({
  required String id,
  required String studentId,
  required DateTime date,
  String teacherId = 'teacher1',
}) {
  return SessionRecordModel(
    id: id,
    studentId: studentId,
    teacherId: teacherId,
    curriculumSessionId: 'cs1',
    levelId: 1,
    juzNumber: 30,
    sessionNumber: 1,
    fromOrderInLevel: 1,
    toOrderInLevel: 1,
    coversSessionIds: const ['cs1'],
    kind: SessionKind.lesson,
    date: date,
    attemptNumber: 1,
    grades: const SessionGrades(
      newMemorizationErrors: 0,
      recentReviewErrors: 0,
      distantReviewErrors: 0,
    ),
    passed: true,
    createdAt: date,
  );
}

ProviderContainer _container({
  required List<SessionRecordModel> records,
  required List<StudentWithUser> students,
}) {
  return ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_teacher('teacher1')),
      sessionRepositoryProvider.overrideWithValue(
        _FakeSessionRepository(records),
      ),
      teacherStudentsProvider.overrideWith((ref) async => students),
    ],
  );
}

void main() {
  final students = [
    _student(id: 's1', name: 'أحمد', instituteId: 'inst1'),
    _student(id: 's2', name: 'خالد', instituteId: 'inst2'),
  ];

  test('resolves each record to its student name', () async {
    final container = _container(
      records: [_record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2))],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries, hasLength(1));
    expect(entries.single.studentName, 'أحمد');
    expect(entries.single.record.id, 'r1');
    expect(entries.single.instituteId, 'inst1');
  });

  test('institute filter scopes history to that institute', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
        _record(id: 'r2', studentId: 's2', date: DateTime(2024, 3, 1)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    container
        .read(selectedTeacherInstituteFilterProvider.notifier)
        .set('inst2');

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries.map((e) => e.record.id), ['r2']);
  });

  test('null filter means all institutes', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
        _record(id: 'r2', studentId: 's2', date: DateTime(2024, 3, 1)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries.map((e) => e.record.id), ['r1', 'r2']);
  });

  test('drops records whose student is no longer with this teacher', () async {
    final container = _container(
      records: [
        _record(id: 'r1', studentId: 'transferred', date: DateTime(2024, 3, 2)),
      ],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    expect(entries, isEmpty);
  });

  test('bounds the query so a year of history is not re-downloaded on every '
      'refresh (al_rasikhoon-256)', () async {
    final fake = _FakeSessionRepository([
      _record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2)),
    ]);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_teacher('teacher1')),
        sessionRepositoryProvider.overrideWithValue(fake),
        teacherStudentsProvider.overrideWith((ref) async => students),
      ],
    );
    addTearDown(container.dispose);

    await container.read(teacherHistoryProvider.future);

    expect(fake.lastLimit, 20);
  });

  test('joins records by student id, not the student\'s user id', () async {
    final container = _container(
      records: [_record(id: 'r1', studentId: 's1', date: DateTime(2024, 3, 2))],
      students: students,
    );
    addTearDown(container.dispose);

    final entries = await container.read(teacherHistoryProvider.future);

    // If the provider wrongly keyed the roster by user id (user-s1), this
    // would find nothing, since the record references the student document id.
    expect(entries, hasLength(1));
    expect(entries.single.studentName, 'أحمد');
  });
}
