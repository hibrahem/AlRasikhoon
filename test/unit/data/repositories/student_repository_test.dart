import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';

void main() {
  group('StudentRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserRepository userRepository;
    late StudentRepository studentRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userRepository = UserRepository(firestore: fakeFirestore);
      studentRepository = StudentRepository(
        firestore: fakeFirestore,
        userRepository: userRepository,
      );
    });

    Future<void> _createUser({
      required String id,
      String email = 'test@example.com',
      String name = 'Test User',
      String role = 'student',
    }) async {
      await fakeFirestore.collection('users').doc(id).set({
        'email': email,
        'name': name,
        'role': role,
        'is_active': true,
        'auth_provider': 'pending',
        'created_at': Timestamp.now(),
      });
    }

    group('createStudent', () {
      test('creates user and student documents', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب جديد',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.user.name, 'طالب جديد');
        expect(result.user.email, 'student@example.com');
        expect(result.user.role, UserRole.student);
        expect(result.student.instituteId, 'institute1');
        expect(result.student.teacherId, 'teacher1');
      });

      test('sets default student progression values', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.student.currentLevel, 1);
        expect(result.student.currentJuz, 30);
        expect(result.student.currentHizb, 59);
        expect(result.student.currentSession, 1);
        expect(result.student.currentAttempt, 1);
      });

      test('creates guardian user when guardian email provided', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
          guardianEmail: 'guardian@example.com',
          guardianPhone: '+966512345678',
        );

        expect(result.student.guardianId, isNotNull);

        // Verify guardian user was created
        final guardian = await userRepository.getUserByEmail('guardian@example.com');
        expect(guardian, isNotNull);
        expect(guardian?.role, UserRole.guardian);
        expect(guardian?.name, 'ولي أمر طالب');
      });

      test('reuses existing guardian if email already exists', () async {
        // Create existing guardian
        await _createUser(
          id: 'existing-guardian',
          email: 'guardian@example.com',
          name: 'ولي أمر موجود',
          role: 'guardian',
        );

        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
          guardianEmail: 'guardian@example.com',
        );

        expect(result.student.guardianId, 'existing-guardian');
      });

      test('creates student without guardian when no email provided', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.student.guardianId, isNull);
      });

      test('stores phone number when provided', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          phone: '+966512345678',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.user.phone, '+966512345678');
      });

      test('user auth_provider defaults to pending', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          email: 'student@example.com',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.user.authProvider, UserAuthProvider.pending);
      });
    });

    group('getStudentById', () {
      test('returns student when exists', () async {
        await fakeFirestore.collection('students').doc('student1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'teacher_id': 'teacher1',
          'current_level': 2,
          'current_session': 15,
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final student = await studentRepository.getStudentById('student1');

        expect(student, isNotNull);
        expect(student?.id, 'student1');
        expect(student?.currentLevel, 2);
        expect(student?.currentSession, 15);
      });

      test('returns null when not found', () async {
        final student = await studentRepository.getStudentById('nonexistent');
        expect(student, isNull);
      });
    });

    group('getStudentByUserId', () {
      test('returns student by user_id', () async {
        await _createUser(id: 'user1');
        await fakeFirestore.collection('students').doc('student1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final student = await studentRepository.getStudentByUserId('user1');

        expect(student, isNotNull);
        expect(student?.userId, 'user1');
      });

      test('returns null when no student for user', () async {
        await _createUser(id: 'user-no-student');
        final student = await studentRepository.getStudentByUserId('user-no-student');
        expect(student, isNull);
      });
    });

    group('getStudentsForTeacher', () {
      test('returns only active students for teacher', () async {
        await _createUser(id: 'user1', name: 'طالب 1');
        await _createUser(id: 'user2', name: 'طالب 2');
        await _createUser(id: 'user3', name: 'طالب غير فعال');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'teacher_id': 'teacher1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s2').set({
          'user_id': 'user2',
          'institute_id': 'i1',
          'teacher_id': 'teacher1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s3').set({
          'user_id': 'user3',
          'institute_id': 'i1',
          'teacher_id': 'teacher1',
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository.getStudentsForTeacher('teacher1');

        expect(students.length, 2);
        expect(students.every((s) => s.student.teacherId == 'teacher1'), true);
      });

      test('excludes students from other teachers', () async {
        await _createUser(id: 'user1', name: 'طالب');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'teacher_id': 'other-teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository.getStudentsForTeacher('teacher1');

        expect(students, isEmpty);
      });
    });

    group('advanceStudentSession', () {
      test('increments session number within same hizb', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_hizb': 59,
          'current_session': 5,
          'current_attempt': 2,
          'completed_levels': [],
          'unlocked_levels': [1],
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.advanceStudentSession('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_session'], 6);
        expect(doc.data()?['current_attempt'], 1); // Reset to 1
      });

      test('completes level and advances when session exceeds 36 at level boundary',
          () async {
        // At level 1, hizb 59 is the first hizb. After exam (session 36),
        // hizb decrements to 58 which is below the level boundary (59),
        // triggering level completion and advancement to level 2.
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_hizb': 59,
          'current_session': 36,
          'current_attempt': 1,
          'completed_levels': [],
          'unlocked_levels': [1],
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.advanceStudentSession('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_session'], 1);
        expect(doc.data()?['current_level'], 2);
        expect(doc.data()?['completed_levels'], contains(1));
        expect(doc.data()?['unlocked_levels'], contains(2));
      });

      test('wraps session and decrements hizb mid-level', () async {
        // At hizb 58 (still within level 1 range), advancing past session 36
        // should wrap session to 1 and decrement hizb without level change.
        // Level 1 first hizb = 59, but hizb 57 is still >= first hizb of
        // level boundary check. Actually let's test with level 2.
        // Level 2: first hizb = 53. At hizb 55, decrementing to 54 is still >= 53.
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 2,
          'current_juz': 28,
          'current_hizb': 55,
          'current_session': 36,
          'current_attempt': 1,
          'completed_levels': [1],
          'unlocked_levels': [1, 2],
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.advanceStudentSession('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_session'], 1);
        expect(doc.data()?['current_hizb'], 54);
        expect(doc.data()?['current_level'], 2); // Level unchanged
      });

      test('resets attempt to 1 after advancement', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': 1,
          'current_juz': 30,
          'current_hizb': 59,
          'current_session': 10,
          'current_attempt': 3,
          'completed_levels': [],
          'unlocked_levels': [1],
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.advanceStudentSession('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_attempt'], 1);
      });

      test('does nothing when student not found', () async {
        // Should not throw
        await studentRepository.advanceStudentSession('nonexistent');
      });
    });

    group('incrementStudentAttempt', () {
      test('increments attempt count', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_attempt': 1,
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.incrementStudentAttempt('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_attempt'], 2);
      });
    });

    group('resetStudentAttempt', () {
      test('resets attempt to 1', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_attempt': 3,
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.resetStudentAttempt('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_attempt'], 1);
      });
    });

    group('deleteStudent', () {
      test('soft deletes by setting is_active to false', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await studentRepository.deleteStudent('s1');

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.exists, true);
        expect(doc.data()?['is_active'], false);
      });
    });

    group('getStudentsByGuardianId', () {
      test('returns students for guardian', () async {
        await _createUser(id: 'user1', name: 'طالب');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students =
            await studentRepository.getStudentsByGuardianId('guardian1');

        expect(students.length, 1);
        expect(students.first.student.guardianId, 'guardian1');
      });

      test('returns empty list when guardian has no students', () async {
        final students =
            await studentRepository.getStudentsByGuardianId('no-guardian');

        expect(students, isEmpty);
      });

      test('returns multiple students for same guardian', () async {
        await _createUser(id: 'user1', name: 'طالب 1');
        await _createUser(id: 'user2', name: 'طالب 2', email: 'student2@example.com');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s2').set({
          'user_id': 'user2',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students =
            await studentRepository.getStudentsByGuardianId('guardian1');

        expect(students.length, 2);
      });
    });

    group('getFirstStudentByGuardianId', () {
      test('returns first student for guardian', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final student =
            await studentRepository.getFirstStudentByGuardianId('guardian1');

        expect(student, isNotNull);
        expect(student?.guardianId, 'guardian1');
      });

      test('returns null when no student for guardian', () async {
        final student =
            await studentRepository.getFirstStudentByGuardianId('no-guardian');

        expect(student, isNull);
      });
    });

    group('getStudentsForInstitute', () {
      test('returns active students for institute', () async {
        await _createUser(id: 'user1', name: 'طالب');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'teacher_id': 'teacher1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s2').set({
          'user_id': 'user1',
          'institute_id': 'institute2',
          'teacher_id': 'teacher1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students =
            await studentRepository.getStudentsForInstitute('institute1');

        expect(students.length, 1);
        expect(students.first.student.instituteId, 'institute1');
      });

      test('returns empty list for unknown institute', () async {
        final students =
            await studentRepository.getStudentsForInstitute('nonexistent');

        expect(students, isEmpty);
      });
    });

    group('getStudentsReadyForExam', () {
      test('returns students at session 36', () async {
        await _createUser(id: 'user1', name: 'طالب جاهز');
        await _createUser(id: 'user2', name: 'طالب غير جاهز', email: 'u2@example.com');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'current_session': 36,
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s2').set({
          'user_id': 'user2',
          'institute_id': 'institute1',
          'current_session': 10,
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final ready =
            await studentRepository.getStudentsReadyForExam('institute1');

        expect(ready.length, 1);
        expect(ready.first.user.name, 'طالب جاهز');
      });

      test('excludes inactive students', () async {
        await _createUser(id: 'user1', name: 'طالب غير فعال');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'current_session': 36,
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final ready =
            await studentRepository.getStudentsReadyForExam('institute1');

        expect(ready, isEmpty);
      });
    });

    group('updateStudent', () {
      test('updates student fields', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_session': 5,
          'current_attempt': 1,
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final student = StudentModel(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          currentSession: 10,
          currentAttempt: 2,
          createdAt: DateTime.now(),
        );

        await studentRepository.updateStudent(student);

        final doc = await fakeFirestore.collection('students').doc('s1').get();
        expect(doc.data()?['current_session'], 10);
        expect(doc.data()?['current_attempt'], 2);
      });
    });
  });
}
