import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';

class _MockFirebaseService extends Mock implements FirebaseService {}

/// Stubs FirebaseService.provisionUserAccount to mirror what the
/// createUserAccount Cloud Function does in production: pick a deterministic
/// UID derived from the email's local part, then write the users/{uid}
/// Firestore profile. Each call gets a fresh UID.
void _stubAuthCreate(
  _MockFirebaseService service,
  FakeFirebaseFirestore firestore,
) {
  when(
    () => service.provisionUserAccount(
      email: any(named: 'email'),
      password: any(named: 'password'),
      role: any(named: 'role'),
      name: any(named: 'name'),
      username: any(named: 'username'),
      phone: any(named: 'phone'),
    ),
  ).thenAnswer((invocation) async {
    final email = invocation.namedArguments[#email] as String;
    final role = invocation.namedArguments[#role] as String;
    final name = invocation.namedArguments[#name] as String;
    final username = invocation.namedArguments[#username] as String;
    final phone = invocation.namedArguments[#phone] as String?;
    final localPart = email.split('@').first;
    final uid = 'uid-$localPart';
    await firestore.collection('users').doc(uid).set({
      'username': username,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'auth_provider': 'email_password',
      'is_active': true,
      'created_at': Timestamp.now(),
    });
    return uid;
  });
}

void main() {
  group('StudentRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseService firebaseService;
    late UserRepository userRepository;
    late StudentRepository studentRepository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      firebaseService = _MockFirebaseService();
      _stubAuthCreate(firebaseService, fakeFirestore);
      userRepository = UserRepository(firestore: fakeFirestore);
      studentRepository = StudentRepository(
        firestore: fakeFirestore,
        firebaseService: firebaseService,
        userRepository: userRepository,
        curriculumRepository: CurriculumRepository(firestore: fakeFirestore),
      );
    });

    Future<void> seedUser({
      required String id,
      String username = 'seeded_user',
      String email = 'test@example.com',
      String name = 'Test User',
      String role = 'student',
    }) async {
      await fakeFirestore.collection('users').doc(id).set({
        'username': username,
        'email': email,
        'name': name,
        'role': role,
        'is_active': true,
        'auth_provider': 'email_password',
        'created_at': Timestamp.now(),
      });
    }

    group('createStudent', () {
      test('creates user and student documents', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب جديد',
          username: 'student_one',
          password: 'pass123',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.user.name, 'طالب جديد');
        expect(result.user.username, 'student_one');
        expect(result.user.email, 'student_one@alrasikhoon.local');
        expect(result.user.role, UserRole.student);
        expect(result.user.authProvider, UserAuthProvider.emailPassword);
        expect(result.student.instituteId, 'institute1');
        expect(result.student.teacherId, 'teacher1');
      });

      test('sets default student progression values', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          username: 'student_two',
          password: 'pass123',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.student.currentLevel, 1);
        expect(result.student.currentJuz, 30);
        expect(result.student.currentHizb, 59);
        expect(result.student.currentSession, 1);
        expect(result.student.currentAttempt, 1);
      });

      test(
        'creates guardian user when guardian credentials provided',
        () async {
          final result = await studentRepository.createStudent(
            name: 'طالب',
            username: 'student_three',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
            guardianUsername: 'guardian_one',
            guardianPassword: 'guard123',
            guardianPhone: '+966512345678',
          );

          expect(result.student.guardianId, isNotNull);

          final guardian = await userRepository.getUserByUsername(
            'guardian_one',
          );
          expect(guardian, isNotNull);
          expect(guardian?.role, UserRole.guardian);
          expect(guardian?.name, 'ولي أمر طالب');
          expect(guardian?.username, 'guardian_one');
        },
      );

      test('reuses existing guardian if username already exists', () async {
        await seedUser(
          id: 'existing-guardian',
          username: 'guardian_one',
          email: 'guardian_one@alrasikhoon.local',
          name: 'ولي أمر موجود',
          role: 'guardian',
        );

        final result = await studentRepository.createStudent(
          name: 'طالب',
          username: 'student_four',
          password: 'pass123',
          instituteId: 'institute1',
          teacherId: 'teacher1',
          guardianUsername: 'guardian_one',
        );

        expect(result.student.guardianId, 'existing-guardian');
      });

      test('throws when new guardian provided without password', () async {
        expect(
          () => studentRepository.createStudent(
            name: 'طالب',
            username: 'student_five',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
            guardianUsername: 'fresh_guardian',
          ),
          throwsArgumentError,
        );
      });

      test(
        'creates student without guardian when no username provided',
        () async {
          final result = await studentRepository.createStudent(
            name: 'طالب',
            username: 'student_six',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
          );

          expect(result.student.guardianId, isNull);
        },
      );

      test(
        'supervisor path: stamps institute_id and leaves teacher_id null',
        () async {
          // A supervisor provisions an institute-scoped student (no teacher
          // assignment) — the student doc must still carry institute_id so
          // rules/UI can scope by users/{uid}.institute_id (AgDR-0003).
          final result = await studentRepository.createStudent(
            name: 'طالب المشرف',
            username: 'sup_student',
            password: 'pass123',
            instituteId: 'institute-sup',
            teacherId: null,
          );

          expect(result.student.instituteId, 'institute-sup');
          expect(result.student.teacherId, isNull);

          final doc = await fakeFirestore
              .collection('students')
              .doc(result.student.id)
              .get();
          expect(doc.data()?['institute_id'], 'institute-sup');
          expect(doc.data()?['teacher_id'], isNull);
        },
      );

      test('stores phone number when provided', () async {
        final result = await studentRepository.createStudent(
          name: 'طالب',
          username: 'student_seven',
          password: 'pass123',
          phone: '+966512345678',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        expect(result.user.phone, '+966512345678');
      });

      test('provisions the student account through the server gateway '
          '(never the client-side Firebase Auth path, which would evict the '
          'admin caller session)', () async {
        await studentRepository.createStudent(
          name: 'طالب',
          username: 'student_no_client_auth',
          password: 'pass123',
          instituteId: 'institute1',
          teacherId: 'teacher1',
        );

        verify(
          () => firebaseService.provisionUserAccount(
            email: 'student_no_client_auth@alrasikhoon.local',
            password: 'pass123',
            role: 'student',
            name: 'طالب',
            username: 'student_no_client_auth',
            phone: null,
          ),
        ).called(1);
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
        await seedUser(id: 'user1');
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
        await seedUser(id: 'user-no-student');
        final student = await studentRepository.getStudentByUserId(
          'user-no-student',
        );
        expect(student, isNull);
      });
    });

    group('getStudentsForTeacher', () {
      test('returns only active students for teacher', () async {
        await seedUser(id: 'user1', name: 'طالب 1');
        await seedUser(id: 'user2', name: 'طالب 2');
        await seedUser(id: 'user3', name: 'طالب غير فعال');

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

        final students = await studentRepository.getStudentsForTeacher(
          'teacher1',
        );

        expect(students.length, 2);
        expect(students.every((s) => s.student.teacherId == 'teacher1'), true);
      });

      test('excludes students from other teachers', () async {
        await seedUser(id: 'user1', name: 'طالب');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'teacher_id': 'other-teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository.getStudentsForTeacher(
          'teacher1',
        );

        expect(students, isEmpty);
      });
    });

    group('advanceStudentSession', () {
      /// Seeds one curriculum session. The curriculum is sparse, so tests seed
      /// exactly the sessions they mean to exist.
      Future<void> seedSession({
        required int level,
        required int hizb,
        required int session,
      }) async {
        final juz = (hizb + 1) ~/ 2;
        await fakeFirestore
            .collection('sessions')
            .doc('L${level}_J${juz}_H${hizb}_S$session')
            .set({
              'session_number': session,
              'level_id': level,
              'juz_number': juz,
              'hizb_number': hizb,
              'session_type': session == 35
                  ? 'sard'
                  : session == 36
                  ? 'exam'
                  : 'regular',
            });
      }

      Future<void> seedStudent({
        required int level,
        required int hizb,
        required int session,
        int attempt = 1,
        List<int> completedLevels = const [],
        List<int> unlockedLevels = const [1],
      }) async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'current_level': level,
          'current_juz': (hizb + 1) ~/ 2,
          'current_hizb': hizb,
          'current_session': session,
          'current_attempt': attempt,
          'completed_levels': completedLevels,
          'unlocked_levels': unlockedLevels,
          'is_active': true,
          'created_at': Timestamp.now(),
        });
      }

      Future<Map<String, dynamic>> readStudent() async {
        final doc = await fakeFirestore.collection('students').doc('s1').get();
        return doc.data()!;
      }

      test('moves to the next session in the same hizb', () async {
        await seedSession(level: 1, hizb: 59, session: 5);
        await seedSession(level: 1, hizb: 59, session: 6);
        await seedStudent(level: 1, hizb: 59, session: 5, attempt: 2);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_session'], 6);
        expect(student['current_hizb'], 59);
        expect(student['current_attempt'], 1);
      });

      test('skips session numbers the curriculum does not contain', () async {
        // Hizb 49 is sparse: sessions 2 and 18 exist, nothing between them.
        await seedSession(level: 2, hizb: 49, session: 2);
        await seedSession(level: 2, hizb: 49, session: 18);
        await seedStudent(
          level: 2,
          hizb: 49,
          session: 2,
          completedLevels: [1],
          unlockedLevels: [1, 2],
        );

        await studentRepository.advanceStudentSession('s1');

        expect((await readStudent())['current_session'], 18);
      });

      test(
        'moves to the next hizb in teaching order, not the next number down',
        () async {
          // Level 1 is taught 59, 60, 57, 58, 55, 56 — after hizb 59 comes 60.
          await seedSession(level: 1, hizb: 59, session: 36);
          await seedSession(level: 1, hizb: 60, session: 1);
          await seedStudent(level: 1, hizb: 59, session: 36);

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          expect(student['current_hizb'], 60);
          expect(student['current_juz'], 30);
          expect(student['current_session'], 1);
          expect(student['current_level'], 1);
          expect(student['completed_levels'], isEmpty);
        },
      );

      test('finishing a hizb does not complete the level', () async {
        // The old code promoted the student to level 2 here. It must not.
        await seedSession(level: 1, hizb: 60, session: 36);
        await seedSession(level: 1, hizb: 57, session: 1);
        await seedStudent(level: 1, hizb: 60, session: 36);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 1);
        expect(student['current_hizb'], 57);
        expect(student['current_juz'], 29);
        expect(student['completed_levels'], isEmpty);
      });

      test('the level completes only after its last hizb', () async {
        // Hizb 56 is the last hizb of level 1; the next is 53, in level 2.
        await seedSession(level: 1, hizb: 56, session: 36);
        await seedSession(level: 2, hizb: 53, session: 1);
        await seedStudent(level: 1, hizb: 56, session: 36);

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 2);
        expect(student['current_hizb'], 53);
        expect(student['current_juz'], 27);
        expect(student['current_session'], 1);
        expect(student['completed_levels'], contains(1));
        expect(student['unlocked_levels'], contains(2));
      });

      test('a hizb with no seeded sessions is stepped over', () async {
        await seedSession(level: 1, hizb: 59, session: 36);
        // Hizb 60 has no sessions at all; the next real one is in hizb 57.
        await seedSession(level: 1, hizb: 57, session: 1);
        await seedStudent(level: 1, hizb: 59, session: 36);

        await studentRepository.advanceStudentSession('s1');

        expect((await readStudent())['current_hizb'], 57);
      });

      test('the end of the curriculum is a terminal position', () async {
        // Hizb 2 is the last hizb of level 10, session 36 its exam.
        await seedSession(level: 10, hizb: 2, session: 36);
        await seedStudent(
          level: 10,
          hizb: 2,
          session: 36,
          attempt: 2,
          completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9],
          unlockedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        );

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 10);
        expect(student['current_hizb'], 2);
        expect(student['current_session'], 36);
        expect(student['current_attempt'], 1);
        // Passing the final exam must credit level 10 as completed — there
        // is no eleventh level to unlock into, so completion is the only
        // signal that the curriculum was finished.
        expect(
          student['completed_levels'],
          containsAll([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        );
      });

      test(
        'a repeat call after finishing the curriculum does not duplicate the level-10 credit',
        () async {
          await seedSession(level: 10, hizb: 2, session: 36);
          await seedStudent(
            level: 10,
            hizb: 2,
            session: 36,
            attempt: 1,
            completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            unlockedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          );

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          final tens = (student['completed_levels'] as List).where(
            (l) => l == 10,
          );
          expect(tens.length, 1);
        },
      );

      test('missing curriculum data ahead leaves the student untouched, not '
          'credited as having finished', () async {
        // The student sits at hizb 60 of level 1 — not the last hizb of
        // the curriculum — but nothing is seeded in hizb 60 or in any
        // hizb ahead of it (a partially-seeded environment/fixture). This
        // must not be conflated with reaching the real end of the
        // curriculum: position, attempt, and credit must all stay exactly
        // as they were, and nothing should be written.
        await seedStudent(
          level: 1,
          hizb: 60,
          session: 36,
          attempt: 2,
          completedLevels: const [],
          unlockedLevels: const [1],
        );

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 1);
        expect(student['current_hizb'], 60);
        expect(student['current_session'], 36);
        expect(student['current_attempt'], 2);
        expect(student['completed_levels'], isEmpty);
        expect(student['unlocked_levels'], [1]);
      });

      test(
        'advancing across a fully-skipped level still credits and unlocks it',
        () async {
          // Level 2 has no seeded sessions anywhere, so the walk from the
          // end of level 1 lands directly in level 3. Level 2 must still be
          // marked completed and unlocked — not silently skipped.
          await seedSession(level: 1, hizb: 56, session: 36); // last of L1
          await seedSession(level: 3, hizb: 47, session: 1); // first of L3
          await seedStudent(
            level: 1,
            hizb: 56,
            session: 36,
            completedLevels: const [],
            unlockedLevels: const [1],
          );

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          expect(student['current_level'], 3);
          expect(student['current_hizb'], 47);
          expect(student['current_session'], 1);
          expect(student['completed_levels'], containsAll([1, 2]));
          expect((student['completed_levels'] as List).length, 2);
          expect(student['unlocked_levels'], containsAll([1, 2, 3]));
          expect((student['unlocked_levels'] as List).length, 3);
        },
      );

      test('derives the level from the hizb even when the stored level is '
          'corrupted (disagrees with the hizb)', () async {
        // Hizb 53 belongs to level 2, but this record's stored level
        // still says 1 — the exact corruption the old advancement bug
        // produced. The walk must find the sessions actually seeded
        // under hizb 53's real level rather than silently skipping past
        // them because it queried under the wrong level.
        await seedSession(level: 2, hizb: 53, session: 5);
        await seedSession(level: 2, hizb: 53, session: 10);
        await seedStudent(
          level: 1, // corrupted: hizb 53 actually belongs to level 2
          hizb: 53,
          session: 5,
          completedLevels: const [1],
          unlockedLevels: const [1, 2],
        );

        await studentRepository.advanceStudentSession('s1');

        final student = await readStudent();
        expect(student['current_level'], 2);
        expect(student['current_hizb'], 53);
        expect(student['current_session'], 10);
      });

      test('does nothing when the student does not exist', () async {
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
        await seedUser(id: 'user1', name: 'طالب');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository.getStudentsByGuardianId(
          'guardian1',
        );

        expect(students.length, 1);
        expect(students.first.student.guardianId, 'guardian1');
      });

      test('returns empty list when guardian has no students', () async {
        final students = await studentRepository.getStudentsByGuardianId(
          'no-guardian',
        );

        expect(students, isEmpty);
      });

      test('returns multiple students for same guardian', () async {
        await seedUser(id: 'user1', name: 'طالب 1');
        await seedUser(
          id: 'user2',
          name: 'طالب 2',
          email: 'student2@example.com',
        );

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

        final students = await studentRepository.getStudentsByGuardianId(
          'guardian1',
        );

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

        final student = await studentRepository.getFirstStudentByGuardianId(
          'guardian1',
        );

        expect(student, isNotNull);
        expect(student?.guardianId, 'guardian1');
      });

      test('returns null when no student for guardian', () async {
        final student = await studentRepository.getFirstStudentByGuardianId(
          'no-guardian',
        );

        expect(student, isNull);
      });
    });

    group('getStudentsForInstitute', () {
      test('returns active students for institute', () async {
        await seedUser(id: 'user1', name: 'طالب');

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

        final students = await studentRepository.getStudentsForInstitute(
          'institute1',
        );

        expect(students.length, 1);
        expect(students.first.student.instituteId, 'institute1');
      });

      test('returns empty list for unknown institute', () async {
        final students = await studentRepository.getStudentsForInstitute(
          'nonexistent',
        );

        expect(students, isEmpty);
      });

      test(
        'excludes students of other institutes (supervisor scope)',
        () async {
          // A supervisor scoped to institute1 (AgDR-0003) must not see the
          // students of institute2.
          await seedUser(id: 'user-in', name: 'طالب المعهد');
          await seedUser(id: 'user-out', name: 'طالب معهد آخر');

          await fakeFirestore.collection('students').doc('s-in').set({
            'user_id': 'user-in',
            'institute_id': 'institute1',
            'is_active': true,
            'created_at': Timestamp.now(),
          });
          await fakeFirestore.collection('students').doc('s-out').set({
            'user_id': 'user-out',
            'institute_id': 'institute2',
            'is_active': true,
            'created_at': Timestamp.now(),
          });

          final scoped = await studentRepository.getStudentsForInstitute(
            'institute1',
          );

          expect(scoped, hasLength(1));
          expect(scoped.single.student.id, 's-in');
          expect(
            scoped.every((s) => s.student.instituteId == 'institute1'),
            isTrue,
          );
        },
      );
    });

    group('streamStudentsForInstitute', () {
      test('streams only the active students of the given institute', () async {
        await fakeFirestore.collection('students').doc('s-a1').set({
          'user_id': 'u-a1',
          'institute_id': 'institute1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s-a2').set({
          'user_id': 'u-a2',
          'institute_id': 'institute1',
          'is_active': false, // inactive — excluded
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s-b1').set({
          'user_id': 'u-b1',
          'institute_id': 'institute2',
          'is_active': true, // other institute — excluded
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository
            .streamStudentsForInstitute('institute1')
            .first;

        expect(students, hasLength(1));
        expect(students.single.id, 's-a1');
        expect(students.single.instituteId, 'institute1');
      });

      test('emits empty list for an institute with no students', () async {
        final students = await studentRepository
            .streamStudentsForInstitute('empty-institute')
            .first;

        expect(students, isEmpty);
      });
    });

    group('getStudentsReadyForExam', () {
      test('returns students at session 36', () async {
        await seedUser(id: 'user1', name: 'طالب جاهز');
        await seedUser(
          id: 'user2',
          name: 'طالب غير جاهز',
          email: 'u2@example.com',
        );

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

        final ready = await studentRepository.getStudentsReadyForExam(
          'institute1',
        );

        expect(ready.length, 1);
        expect(ready.first.user.name, 'طالب جاهز');
      });

      test('excludes inactive students', () async {
        await seedUser(id: 'user1', name: 'طالب غير فعال');

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'institute1',
          'current_session': 36,
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final ready = await studentRepository.getStudentsReadyForExam(
          'institute1',
        );

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
