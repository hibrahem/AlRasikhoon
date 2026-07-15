import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';
import 'package:al_rasikhoon/data/models/student_model.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/curriculum_repository.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/repositories/student_repository.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';
import 'package:al_rasikhoon/data/services/firebase_service.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_pace.dart';
import 'package:al_rasikhoon/domain/curriculum/curriculum_position.dart';
import 'package:al_rasikhoon/domain/curriculum/reposition_exceptions.dart';

import 'curriculum_fixtures.dart';

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
        sessionRepository: SessionRepository(firestore: fakeFirestore),
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

    /// Places a student at a curriculum position, writing the same shape
    /// StudentRepository writes: identity AND the denormalized session facts.
    Future<void> seedStudent({
      String id = 's1',
      required int level,
      required int juz,
      required int session,
      required int order,
      String kind = 'lesson',
      String? tier,
      String? labelAr,
      int? hizb,
      int attempt = 1,
      List<int> completedLevels = const [],
      List<int> unlockedLevels = const [1],
      String instituteId = 'i1',
    }) async {
      await fakeFirestore.collection('students').doc(id).set({
        'user_id': 'u1',
        'institute_id': instituteId,
        'current_level': level,
        'current_juz': juz,
        'current_session': session,
        'current_order_in_level': order,
        'current_hizb': hizb,
        'current_session_id': 'L${level}_J${juz}_S$session',
        'current_session_kind': kind,
        'current_session_tier': tier,
        'current_session_label_ar': labelAr,
        'current_attempt': attempt,
        'completed_levels': completedLevels,
        'unlocked_levels': unlockedLevels,
        'is_active': true,
        'created_at': Timestamp.now(),
      });
    }

    Future<Map<String, dynamic>> readStudent([String id = 's1']) async {
      final doc = await fakeFirestore.collection('students').doc(id).get();
      return doc.data()!;
    }

    group('createStudent', () {
      setUp(() async {
        await seedLevels(fakeFirestore);
        await seedLevelOneJuz30(fakeFirestore);
        await seedLevelTwoHead(fakeFirestore);
      });

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

      test(
        'a student created without a position starts at the first session of '
        'the curriculum, with its facts copied from the curriculum',
        () async {
          final result = await studentRepository.createStudent(
            name: 'طالب',
            username: 'student_two',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
          );

          expect(result.student.enrollmentPosition, CurriculumPosition.start);
          expect(result.student.currentLevel, 1);
          expect(result.student.currentJuz, 30);
          expect(result.student.currentSession, 1);
          expect(result.student.currentOrderInLevel, 1);
          expect(result.student.currentSessionId, 'L1_J30_S1');
          expect(result.student.currentSessionKind, SessionKind.talqeen);
          expect(result.student.currentAttempt, 1);
          expect(result.student.completedLevels, isEmpty);

          final doc = await fakeFirestore
              .collection('students')
              .doc(result.student.id)
              .get();
          expect(doc.data()?['current_session_id'], 'L1_J30_S1');
          expect(doc.data()?['current_session_kind'], 'talqeen');
          expect(doc.data()?['current_order_in_level'], 1);
        },
      );

      test(
        'a student may be placed onto an assessment — the placement carries its '
        'kind and its scope, not a guess from the session number',
        () async {
          final result = await studentRepository.createStudent(
            name: 'طالب حافظ',
            username: 'hafiz',
            password: 'pass123',
            instituteId: 'i1',
            teacherId: 't1',
            // L1_J30_S69 is the juz-30 سرد — under the old 35/36 rule, session
            // 69 could only ever have been read as an ordinary lesson.
            startingPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 69,
            ),
          );

          expect(result.student.currentSessionKind, SessionKind.sard);
          expect(result.student.currentSessionTier, AssessmentTier.juz);
          expect(
            result.student.currentSessionLabelAr,
            'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
          );
          expect(result.student.currentOrderInLevel, 69);

          final doc = await fakeFirestore
              .collection('students')
              .doc(result.student.id)
              .get();
          expect(doc.data()?['current_session_kind'], 'sard');
          expect(doc.data()?['current_session_tier'], 'juz');
        },
      );

      test(
        'a student placed mid-curriculum is credited with the levels before them',
        () async {
          final result = await studentRepository.createStudent(
            name: 'طالب',
            username: 'level_two',
            password: 'pass123',
            instituteId: 'i1',
            teacherId: 't1',
            startingPosition: const CurriculumPosition(
              level: 2,
              juz: 27,
              session: 1,
            ),
          );

          expect(result.student.currentLevel, 2);
          expect(result.student.currentJuz, 27);
          expect(result.student.completedLevels, [1]);
          expect(result.student.unlockedLevels, [1, 2]);

          final doc = await fakeFirestore
              .collection('students')
              .doc(result.student.id)
              .get();
          expect(doc.data()?['enrollment_position'], {
            'level': 2,
            'juz': 27,
            'session': 1,
          });
        },
      );

      test('a starting position the curriculum holds no session at is rejected '
          'before any auth user is provisioned', () async {
        // Juz 30 of level 1 has 70 sessions; there is no session 99. Whether
        // a session exists is a DATA question — and a rejected placement must
        // never leave a half-provisioned user behind (an auth account with no
        // student document is worse than no student at all).
        await expectLater(
          studentRepository.createStudent(
            name: 'طالب',
            username: 'no_such_session',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
            startingPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 99,
            ),
          ),
          throwsArgumentError,
        );

        verifyNever(
          () => firebaseService.provisionUserAccount(
            email: any(named: 'email'),
            password: any(named: 'password'),
            role: any(named: 'role'),
            name: any(named: 'name'),
            username: any(named: 'username'),
            phone: any(named: 'phone'),
          ),
        );

        final users = await fakeFirestore.collection('users').get();
        expect(users.docs, isEmpty);
        final students = await fakeFirestore.collection('students').get();
        expect(students.docs, isEmpty);
      });

      test('a position outside the curriculum topology is rejected before any '
          'side effect', () async {
        await expectLater(
          studentRepository.createStudent(
            name: 'طالب',
            username: 'bad_level',
            password: 'pass123',
            instituteId: 'institute1',
            teacherId: 'teacher1',
            startingPosition: const CurriculumPosition(
              level: 11,
              juz: 30,
              session: 1,
            ),
          ),
          throwsArgumentError,
        );

        final users = await fakeFirestore.collection('users').get();
        expect(users.docs, isEmpty);
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
        'supervisor path: stamps institute_id and leaves teacher_id null',
        () async {
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

    group('advanceStudentSession', () {
      setUp(() async {
        await seedLevels(fakeFirestore);
      });

      test('walks order_in_level to the next session', () async {
        await seedLevelOneJuz30(fakeFirestore);
        await seedStudent(
          level: 1,
          juz: 30,
          session: 1,
          order: 1,
          kind: 'talqeen',
          hizb: 59,
          attempt: 3,
        );

        final outcome = await studentRepository.advanceStudentSession('s1');

        expect(outcome, StudentAdvanceOutcome.advanced);
        final student = await readStudent();
        expect(student['current_order_in_level'], 2);
        expect(student['current_session'], 2);
        expect(student['current_session_id'], 'L1_J30_S2');
        expect(
          student['current_attempt'],
          1,
          reason: 'a new session is a new attempt',
        );
      });

      test(
        'the session after a lesson may be an assessment — its kind and scope '
        'are read from the curriculum, never from its number',
        () async {
          await seedLevelOneJuz30(fakeFirestore);
          // The student stands at order 30 — the last lesson before the
          // hizb-59 سرد. Order 31 is the hizb-59 سرد. Nothing about the
          // number 31 says so; the curriculum does.
          await seedStudent(
            level: 1,
            juz: 30,
            session: 30,
            order: 30,
            hizb: 59,
          );

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          expect(student['current_session_id'], 'L1_J30_S31');
          expect(student['current_session_kind'], 'sard');
          expect(student['current_session_tier'], 'unit');
          expect(
            student['current_session_label_ar'],
            'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
          );
        },
      );

      test(
        'crosses a juz boundary within a level without touching hizb arithmetic '
        '— order 70 of level 1 is the last of juz 30, order 71 the first of '
        'juz 29',
        () async {
          await seedLevelOneJuz30(fakeFirestore);
          await seedLevelOneJuz29(fakeFirestore);
          await seedStudent(
            level: 1,
            juz: 30,
            session: 70,
            order: 70,
            kind: 'exam',
            tier: 'juz',
          );

          final outcome = await studentRepository.advanceStudentSession('s1');

          expect(outcome, StudentAdvanceOutcome.advanced);
          final student = await readStudent();
          expect(student['current_level'], 1, reason: 'still the same level');
          expect(student['current_juz'], 29);
          expect(student['current_session'], 1);
          expect(student['current_order_in_level'], 71);
          expect(student['current_session_id'], 'L1_J29_S1');
          expect(student['current_session_kind'], 'talqeen');
          expect(
            student['current_session_tier'],
            isNull,
            reason: 'a تلقين has no tier — the stale سرد tier must be cleared',
          );
          expect(
            student['completed_levels'],
            isEmpty,
            reason: 'finishing a juz does not finish the level',
          );
        },
      );

      test(
        'a student steps out of a talqeen into the lesson it introduces',
        () async {
          await seedSession(
            fakeFirestore,
            level: 1,
            juz: 30,
            session: 1,
            order: 1,
            kind: 'talqeen',
            unitIndex: 1,
            hizb: 59,
          );
          await seedSession(
            fakeFirestore,
            level: 1,
            juz: 30,
            session: 2,
            order: 2,
            kind: 'lesson',
            unitIndex: 1,
            hizb: 59,
          );
          await seedStudent(
            level: 1,
            juz: 30,
            session: 1,
            order: 1,
            kind: 'talqeen',
          );

          final outcome = await studentRepository.advanceStudentSession('s1');
          expect(outcome, StudentAdvanceOutcome.advanced);

          final student = await studentRepository.getStudentById('s1');
          expect(student!.currentSessionId, 'L1_J30_S2');
          expect(student.currentSessionKind, SessionKind.lesson);
          expect(student.currentOrderInLevel, 2);
        },
      );

      test(
        'LEVEL 10 ADVANCES JUZ 1 → 2 → 3: the case every arithmetic rule got '
        'wrong',
        () async {
          await seedLevelTenJuz1To2(fakeFirestore);
          await seedStudent(
            level: 10,
            juz: 1,
            session: 60,
            order: 60,
            kind: 'exam',
            tier: 'juz',
            completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9],
            unlockedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          );

          final outcome = await studentRepository.advanceStudentSession('s1');

          expect(outcome, StudentAdvanceOutcome.advanced);
          final student = await readStudent();
          expect(
            student['current_juz'],
            2,
            reason: 'level 10 ascends: juz 1 is followed by juz 2, not juz 30',
          );
          expect(student['current_order_in_level'], 61);
          expect(student['current_session_id'], 'L10_J2_S1');
        },
      );

      test('the level completes only after its last session', () async {
        await seedLevelOneTail(fakeFirestore);
        await seedLevelTwoHead(fakeFirestore);
        await seedStudent(
          level: 1,
          juz: 28,
          session: 69,
          order: 210, // the level's session_count — its cumulative اختبار
          kind: 'exam',
          tier: 'cumulative',
        );

        final outcome = await studentRepository.advanceStudentSession('s1');

        expect(outcome, StudentAdvanceOutcome.advanced);
        final student = await readStudent();
        expect(student['current_level'], 2);
        expect(student['current_juz'], 27);
        expect(student['current_order_in_level'], 1);
        expect(student['current_session_id'], 'L2_J27_S1');
        expect(student['completed_levels'], contains(1));
        expect(student['unlocked_levels'], containsAll([1, 2]));
      });

      test(
        'a level with no seeded sessions is stepped over, and still credited',
        () async {
          // Level 2 has no sessions at all, so the walk from the end of level 1
          // lands in level 10 (the only other seeded level). Level credit must
          // be gap-free: every level below the new one is complete.
          await seedLevelOneTail(fakeFirestore);
          await seedSession(
            fakeFirestore,
            level: 10,
            juz: 1,
            session: 1,
            order: 1,
          );
          await seedStudent(
            level: 1,
            juz: 28,
            session: 69,
            order: 210,
            kind: 'exam',
            tier: 'cumulative',
          );

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          expect(student['current_level'], 10);
          expect(
            student['completed_levels'],
            containsAll([1, 2, 3, 4, 5, 6, 7, 8, 9]),
          );
          expect((student['completed_levels'] as List).length, 9);
          expect((student['unlocked_levels'] as List).length, 10);
        },
      );

      test(
        'passing the last session of the last level completes the curriculum',
        () async {
          await seedLevelTenTail(fakeFirestore);
          await seedStudent(
            level: 10,
            juz: 3,
            session: 60,
            order: 180, // level 10's session_count
            kind: 'exam',
            tier: 'cumulative',
            attempt: 4,
            completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9],
            unlockedLevels: const [1],
          );

          final outcome = await studentRepository.advanceStudentSession('s1');

          expect(outcome, StudentAdvanceOutcome.curriculumCompleted);
          final student = await readStudent();
          // Nowhere to move to — the position stands, the credit lands.
          expect(student['current_session_id'], 'L10_J3_S60');
          expect(student['current_attempt'], 1);
          expect(
            student['completed_levels'],
            containsAll([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
          );
          expect((student['unlocked_levels'] as List).length, 10);
          // Graduated: the student's position stays frozen on the final
          // اختبار, so the flag — not the position — is what lifts them out of
          // the supervisor's exam queue for good.
          expect(student['curriculum_completed'], isTrue);
          expect(student['curriculum_completed_at'], isNotNull);
        },
      );

      test(
        'an ordinary advance to a later session does NOT graduate the student',
        () async {
          await seedLevelOneTail(fakeFirestore);
          await seedLevelTwoHead(fakeFirestore);
          await seedStudent(
            level: 1,
            juz: 28,
            session: 69,
            order: 210, // the level's session_count — its cumulative اختبار
            kind: 'exam',
            tier: 'cumulative',
          );

          final outcome = await studentRepository.advanceStudentSession('s1');

          expect(outcome, StudentAdvanceOutcome.advanced);
          final student = await readStudent();
          // Passing a non-final اختبار moves the student on; it must never be
          // mistaken for finishing the curriculum.
          expect(student['current_session_id'], 'L2_J27_S1');
          expect(student.containsKey('curriculum_completed'), isFalse);
        },
      );

      test(
        'a repeat advance after finishing does not duplicate the level credit',
        () async {
          await seedLevelTenTail(fakeFirestore);
          await seedStudent(
            level: 10,
            juz: 3,
            session: 60,
            order: 180,
            kind: 'exam',
            tier: 'cumulative',
            completedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            unlockedLevels: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          );

          await studentRepository.advanceStudentSession('s1');

          final student = await readStudent();
          expect(
            (student['completed_levels'] as List).where((l) => l == 10).length,
            1,
          );
          expect((student['completed_levels'] as List).length, 10);
        },
      );

      test('a hole in the curriculum data reports curriculumDataMissing, not '
          'success, and leaves the student untouched', () async {
        // The catalog says level 1 has 210 sessions; the student sits at
        // order 3 and nothing is seeded at order 4. That is a data problem,
        // never "the level is finished" — a silent no-op reported as success
        // would leave the student re-taught the same session forever.
        await seedLevelOneJuz30(fakeFirestore);
        await seedLevelTwoHead(fakeFirestore);
        await seedStudent(
          level: 1,
          juz: 30,
          session: 3,
          order: 3,
          hizb: 59,
          attempt: 2,
        );

        final outcome = await studentRepository.advanceStudentSession('s1');

        expect(outcome, StudentAdvanceOutcome.curriculumDataMissing);
        final student = await readStudent();
        expect(student['current_order_in_level'], 3);
        expect(student['current_session_id'], 'L1_J30_S3');
        expect(student['current_attempt'], 2, reason: 'nothing was written');
        expect(student['completed_levels'], isEmpty);
        expect(student['unlocked_levels'], [1]);
      });

      test('does nothing when the student does not exist', () async {
        final outcome = await studentRepository.advanceStudentSession(
          'nonexistent',
        );
        expect(outcome, StudentAdvanceOutcome.studentNotFound);
      });

      test(
        'a paced meeting ending on the level\'s LAST session rolls the '
        'student over into the next level — the data-hole check gates on '
        'the MEETING\'s endpoint, never the student\'s own position',
        () async {
          // A 2x student stands at order 209, the level's last two orders
          // (209, 210) are both lessons, and the catalog says the level has
          // exactly 210 sessions. His meeting discharges 209 AND 210, so
          // `advanceStudentSession` is called with `fromOrderInLevel: 210`
          // — the meeting's true endpoint — even though the student HIMSELF
          // still sits at 209. Gating the "is the level really finished?"
          // check on 209 instead of 210 would wrongly conclude the data is
          // holed (209 < 210) and strand him on the level forever, since
          // nothing would ever be written and every subsequent pass would
          // repeat the exact same no-op.
          await seedSession(
            fakeFirestore,
            level: 1,
            juz: 28,
            session: 68,
            order: 209,
          );
          await seedSession(
            fakeFirestore,
            level: 1,
            juz: 28,
            session: 69,
            order: 210,
          );
          await seedLevelTwoHead(fakeFirestore);
          await seedStudent(level: 1, juz: 28, session: 68, order: 209);

          final outcome = await studentRepository.advanceStudentSession(
            's1',
            fromOrderInLevel: 210,
          );

          expect(
            outcome,
            StudentAdvanceOutcome.advanced,
            reason:
                'the level is genuinely finished at order 210 (the '
                'meeting\'s endpoint), not merely missing data past the '
                'student\'s own order 209',
          );
          final student = await readStudent();
          expect(student['current_level'], 2);
          expect(student['current_order_in_level'], 1);
          expect(student['current_session_id'], 'L2_J27_S1');
          expect(student['completed_levels'], contains(1));
        },
      );

      test('a paced meeting ending BEFORE the level\'s last session still '
          'reports curriculumDataMissing when the next order is genuinely '
          'absent, even though the student himself stands earlier in the '
          'level', () async {
        // The student himself still stands at order 1 (a تلقين) — his OWN
        // position would find order 2 seeded and never surface the hole.
        // Only the paced meeting's true endpoint (order 3, with nothing
        // seeded at order 4, against a catalog of 210) exposes it. Fixing
        // FIX 1 to gate on the meeting's endpoint must not break this: a
        // genuine hole past the meeting's endpoint is still a hole.
        await seedLevelOneJuz30(fakeFirestore);
        await seedLevelTwoHead(fakeFirestore);
        await seedStudent(
          level: 1,
          juz: 30,
          session: 1,
          order: 1,
          kind: 'talqeen',
        );

        final outcome = await studentRepository.advanceStudentSession(
          's1',
          fromOrderInLevel: 3,
        );

        expect(outcome, StudentAdvanceOutcome.curriculumDataMissing);
        final student = await readStudent();
        expect(
          student['current_order_in_level'],
          1,
          reason:
              'nothing was written — the student is left exactly as '
              'he was',
        );
        expect(student['current_session_id'], 'L1_J30_S1');
      });
    });

    group('advanceStudentSession — completion is proven from data, not '
        'structure', () {
      test('a last-level student whose sessions and catalog were never seeded is '
          'NOT graduated: terminality is decided from the levels catalog, never '
          'from the structural fact that they sit in the last level', () async {
        // A hizb-2 student is placed in juz 1 — which the curriculum teaches
        // in level 10, the LAST structural level. In this environment level
        // 10 was never seeded: neither its sessions nor its levels-catalog
        // entry (this group's setUp seeds NO catalog). The walk forward finds
        // no session ahead AND no catalog to confirm the student stands on the
        // level's last session. Deciding terminality structurally ("level 10
        // is the last level, so nothing ahead means the curriculum is done")
        // would graduate a student who has memorized almost nothing — and,
        // since al_rasikhoon-s9d, would even stamp the `curriculum_completed`
        // flag on that wrong branch. Completion must be credited only when the
        // catalog positively confirms it; a missing catalog proves nothing, so
        // the only honest outcome is curriculumDataMissing.
        await seedStudent(
          level: 10,
          juz: 1,
          session: 2,
          order: 2,
          kind: 'lesson',
          hizb: 2,
        );

        final outcome = await studentRepository.advanceStudentSession('s1');

        expect(outcome, StudentAdvanceOutcome.curriculumDataMissing);

        final student = await readStudent();
        // Nothing was written: not the position, not the level credit, and —
        // the regression that matters — not the graduation flag.
        expect(student['current_order_in_level'], 2);
        expect(student['current_session_id'], 'L10_J1_S2');
        expect(student['completed_levels'], isEmpty);
        expect(
          student.containsKey('curriculum_completed'),
          isFalse,
          reason:
              'an unseeded student must never be stamped as having finished '
              'the curriculum',
        );
      });
    });

    group('getStudentsReadyForExam', () {
      test(
        'returns the students standing on an اختبار — by KIND, not by session '
        'number',
        () async {
          await seedUser(id: 'u1', name: 'طالب على اختبار');
          // The juz-30 اختبار of level 1 is session 70. The old query
          // (current_session == 36) would have found nobody.
          await seedStudent(
            id: 'ready',
            level: 1,
            juz: 30,
            session: 70,
            order: 70,
            kind: 'exam',
            tier: 'juz',
            instituteId: 'institute1',
          );
          await seedStudent(
            id: 'on_lesson',
            level: 1,
            juz: 30,
            session: 2,
            order: 2,
            instituteId: 'institute1',
          );
          await seedStudent(
            id: 'on_sard',
            level: 1,
            juz: 30,
            session: 69,
            order: 69,
            kind: 'sard',
            tier: 'juz',
            instituteId: 'institute1',
          );

          final ready = await studentRepository.getStudentsReadyForExam(
            'institute1',
          );

          expect(ready.map((s) => s.student.id), ['ready']);
          expect(ready.single.student.currentSessionKind, SessionKind.exam);
          expect(ready.single.student.canTakeExam, isTrue);
        },
      );

      test('excludes inactive students and other institutes', () async {
        await seedUser(id: 'u1');
        await seedStudent(
          id: 'other_institute',
          level: 1,
          juz: 30,
          session: 70,
          order: 70,
          kind: 'exam',
          tier: 'juz',
          instituteId: 'institute2',
        );
        await fakeFirestore.collection('students').doc('inactive').set({
          'user_id': 'u1',
          'institute_id': 'institute1',
          'current_session_kind': 'exam',
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final ready = await studentRepository.getStudentsReadyForExam(
          'institute1',
        );

        expect(ready, isEmpty);
      });

      test(
        'excludes a graduated student still standing on the final exam',
        () async {
          await seedUser(id: 'u1', name: 'طالب متخرج');
          // A finished student's position stays frozen on the last اختبار they
          // passed — so kind alone still matches them. Only the graduation flag
          // keeps them out of the queue; without it they would be re-examined
          // forever.
          await fakeFirestore.collection('students').doc('graduate').set({
            'user_id': 'u1',
            'institute_id': 'institute1',
            'current_level': 10,
            'current_juz': 3,
            'current_session': 60,
            'current_order_in_level': 180,
            'current_session_id': 'L10_J3_S60',
            'current_session_kind': 'exam',
            'current_session_tier': 'cumulative',
            'current_attempt': 1,
            'curriculum_completed': true,
            'curriculum_completed_at': Timestamp.now(),
            'is_active': true,
            'created_at': Timestamp.now(),
          });
          // A second student, genuinely awaiting an exam, proves the query still
          // returns the students it should.
          await seedStudent(
            id: 'awaiting',
            level: 1,
            juz: 30,
            session: 70,
            order: 70,
            kind: 'exam',
            tier: 'juz',
            instituteId: 'institute1',
          );

          final ready = await studentRepository.getStudentsReadyForExam(
            'institute1',
          );

          expect(ready.map((s) => s.student.id), ['awaiting']);
        },
      );
    });

    group('getStudentById', () {
      test('returns student when exists', () async {
        await seedStudent(level: 2, juz: 27, session: 15, order: 15);

        final student = await studentRepository.getStudentById('s1');

        expect(student, isNotNull);
        expect(student?.currentLevel, 2);
        expect(student?.currentSession, 15);
        expect(student?.currentOrderInLevel, 15);
      });

      test('returns null when not found', () async {
        final student = await studentRepository.getStudentById('nonexistent');
        expect(student, isNull);
      });
    });

    group('getStudentByUserId', () {
      test('returns student by user_id', () async {
        await seedUser(id: 'u1');
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        final student = await studentRepository.getStudentByUserId('u1');

        expect(student?.userId, 'u1');
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

        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'user1',
          'institute_id': 'i1',
          'teacher_id': 'teacher1',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s2').set({
          'user_id': 'user2',
          'institute_id': 'i1',
          'teacher_id': 'teacher1',
          'current_session_kind': 'lesson',
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository.getStudentsForTeacher(
          'teacher1',
        );

        expect(students.length, 1);
        expect(students.single.student.id, 's1');
      });
    });

    group('attempt limits', () {
      test(
        'a student on an assessment may retry it indefinitely — attempt 9 is '
        'still allowed',
        () async {
          await seedStudent(
            level: 1,
            juz: 30,
            session: 69,
            order: 69,
            kind: 'sard',
            tier: 'juz',
            attempt: 9,
          );

          final student = await studentRepository.getStudentById('s1');

          expect(student!.isOnAssessment, isTrue);
          expect(student.hasReachedMaxAttempts, isFalse);
          expect(student.canStartSession, isTrue);
        },
      );

      test('a student on a lesson still caps at 3 attempts', () async {
        await seedStudent(
          level: 1,
          juz: 30,
          session: 2,
          order: 2,
          hizb: 59,
          attempt: 4,
        );

        final student = await studentRepository.getStudentById('s1');

        expect(student!.isOnAssessment, isFalse);
        expect(student.hasReachedMaxAttempts, isTrue);
        expect(student.canStartSession, isFalse);
      });
    });

    group('incrementStudentAttempt', () {
      test('increments attempt count', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.incrementStudentAttempt('s1');

        expect((await readStudent())['current_attempt'], 2);
      });
    });

    group('resetStudentAttempt', () {
      test('resets attempt to 1', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1, attempt: 3);

        await studentRepository.resetStudentAttempt('s1');

        expect((await readStudent())['current_attempt'], 1);
      });
    });

    group('deleteStudent', () {
      test('soft deletes by setting is_active to false', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.deleteStudent('s1');

        expect((await readStudent())['is_active'], false);
      });
    });

    group('getStudentsByGuardianId', () {
      test('returns students for guardian', () async {
        await seedUser(id: 'u1', name: 'طالب');
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'current_session_kind': 'lesson',
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
        expect(
          await studentRepository.getStudentsByGuardianId('no-guardian'),
          isEmpty,
        );
      });
    });

    group('getFirstStudentByGuardianId', () {
      test('returns first student for guardian', () async {
        await fakeFirestore.collection('students').doc('s1').set({
          'user_id': 'u1',
          'institute_id': 'i1',
          'guardian_id': 'guardian1',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final student = await studentRepository.getFirstStudentByGuardianId(
          'guardian1',
        );

        expect(student?.guardianId, 'guardian1');
      });

      test('returns null when no student for guardian', () async {
        expect(
          await studentRepository.getFirstStudentByGuardianId('no-guardian'),
          isNull,
        );
      });
    });

    group('getStudentsForInstitute', () {
      test(
        'excludes students of other institutes (supervisor scope)',
        () async {
          await seedUser(id: 'user-in', name: 'طالب المعهد');
          await seedUser(id: 'user-out', name: 'طالب معهد آخر');

          await fakeFirestore.collection('students').doc('s-in').set({
            'user_id': 'user-in',
            'institute_id': 'institute1',
            'current_session_kind': 'lesson',
            'is_active': true,
            'created_at': Timestamp.now(),
          });
          await fakeFirestore.collection('students').doc('s-out').set({
            'user_id': 'user-out',
            'institute_id': 'institute2',
            'current_session_kind': 'lesson',
            'is_active': true,
            'created_at': Timestamp.now(),
          });

          final scoped = await studentRepository.getStudentsForInstitute(
            'institute1',
          );

          expect(scoped, hasLength(1));
          expect(scoped.single.student.id, 's-in');
        },
      );
    });

    // al_rasikhoon-3n6 — a multi-institute supervisor sees the UNION of their
    // institutes' students. getStudentsForInstitutes chunks the whereIn at
    // Firestore's 30-value cap, dedups by id, and sorts by created_at desc.
    group('getStudentsForInstitutes', () {
      test('unions active students across the given institutes', () async {
        await seedUser(id: 'user-a', name: 'طالب أ');
        await seedUser(id: 'user-b', name: 'طالب ب');
        await seedUser(id: 'user-c', name: 'طالب ج');

        await fakeFirestore.collection('students').doc('s-a').set({
          'user_id': 'user-a',
          'institute_id': 'inst-a',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
        });
        await fakeFirestore.collection('students').doc('s-b').set({
          'user_id': 'user-b',
          'institute_id': 'inst-b',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 3)),
        });
        // A student in a THIRD institute the supervisor is not a member of.
        await fakeFirestore.collection('students').doc('s-c').set({
          'user_id': 'user-c',
          'institute_id': 'inst-c',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.fromDate(DateTime(2026, 1, 2)),
        });

        final scoped = await studentRepository.getStudentsForInstitutes([
          'inst-a',
          'inst-b',
        ]);

        // Only the two in-scope institutes; inst-c excluded. Sorted by
        // created_at DESCENDING across institutes → s-b (Jan 3) before s-a.
        expect(scoped.map((s) => s.student.id), ['s-b', 's-a']);
      });

      test('returns empty for an empty institute list', () async {
        expect(await studentRepository.getStudentsForInstitutes([]), isEmpty);
      });

      test(
        'resolves ALL students when the institute set exceeds the whereIn cap '
        '(chunking)',
        () async {
          // 31 institutes > Firestore's 30-value whereIn cap: a non-chunked
          // query would be impossible / lossy. Each institute has one student;
          // all 31 must come back.
          final instituteIds = <String>[];
          for (var i = 0; i < 31; i++) {
            final instId = 'inst-$i';
            instituteIds.add(instId);
            await seedUser(id: 'user-$i', name: 'طالب $i');
            await fakeFirestore.collection('students').doc('s-$i').set({
              'user_id': 'user-$i',
              'institute_id': instId,
              'current_session_kind': 'lesson',
              'is_active': true,
              'created_at': Timestamp.fromDate(DateTime(2026, 1, 1, 0, i)),
            });
          }

          final scoped = await studentRepository.getStudentsForInstitutes(
            instituteIds,
          );

          expect(scoped, hasLength(31));
        },
      );
    });

    group('streamStudentsForInstitute', () {
      test('streams only the active students of the given institute', () async {
        await fakeFirestore.collection('students').doc('s-a1').set({
          'user_id': 'u-a1',
          'institute_id': 'institute1',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('students').doc('s-b1').set({
          'user_id': 'u-b1',
          'institute_id': 'institute2',
          'current_session_kind': 'lesson',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final students = await studentRepository
            .streamStudentsForInstitute('institute1')
            .first;

        expect(students, hasLength(1));
        expect(students.single.id, 's-a1');
      });
    });

    group('updateStudent', () {
      // _writePosition is the ONLY writer of the denormalized `current_*`
      // session facts (see its doc comment): the supervisor's exam queue is a
      // single Firestore query on `current_session_kind`, so a second writer
      // that lets these fields drift would silently drop a student out of the
      // queue with no signal to anyone. updateStudent must be STRUCTURALLY
      // unable to write them, however it is called.
      test('cannot change the denormalized current_* session facts', () async {
        await seedStudent(
          level: 1,
          juz: 30,
          session: 5,
          order: 5,
          kind: 'exam',
          tier: 'juz',
          labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
          hizb: 59,
          attempt: 1,
        );

        // A StudentModel carrying a DIFFERENT, wrong position — e.g. built
        // from stale in-memory state. Even so, updateStudent must not let
        // any of it reach the `current_*` fields.
        final student = StudentModel(
          id: 's1',
          userId: 'u1',
          instituteId: 'i1',
          teacherId: 'teacher-2',
          currentLevel: 5,
          currentJuz: 12,
          currentSession: 99,
          currentHizb: 1,
          currentSessionId: 'L5_J12_S99',
          currentSessionKind: SessionKind.lesson,
          currentOrderInLevel: 99,
          currentAttempt: 7,
          createdAt: DateTime.now(),
        );

        await studentRepository.updateStudent(student);

        final doc = await readStudent();
        // The exam-queue-critical facts are exactly as seeded.
        expect(doc['current_level'], 1);
        expect(doc['current_juz'], 30);
        expect(doc['current_session'], 5);
        expect(doc['current_order_in_level'], 5);
        expect(doc['current_session_id'], 'L1_J30_S5');
        expect(doc['current_session_kind'], 'exam');
        expect(doc['current_session_tier'], 'juz');
        expect(
          doc['current_session_label_ar'],
          'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
        );
        expect(doc['current_hizb'], 59);
        expect(doc['current_attempt'], 1);

        // A genuinely non-denormalized field still updates.
        expect(doc['teacher_id'], 'teacher-2');
      });

      test('carries a loaded pace back through — it is not stripped like the '
          'current_* position facts', () async {
        await seedStudent(level: 1, juz: 30, session: 5, order: 5);
        await fakeFirestore.collection('students').doc('s1').update({
          'pace': 3,
        });

        // A realistic caller: load the student (picking up its pace), then
        // change an unrelated field and write it back.
        final loaded = await studentRepository.getStudentById('s1');
        final student = loaded!.copyWith(teacherId: 'teacher-2');
        await studentRepository.updateStudent(student);

        final doc = await readStudent();
        expect(doc['pace'], 3);
      });
    });

    group('setStudentPace', () {
      test('sets how many lessons the student covers in one meeting', () async {
        await seedStudent(level: 1, juz: 30, session: 5, order: 5);

        await studentRepository.setStudentPace('s1', CurriculumPace(2));

        final doc = await readStudent();
        expect(doc['pace'], 2);
      });

      test(
        'does not disturb the denormalized current_* session facts',
        () async {
          await seedStudent(
            level: 1,
            juz: 30,
            session: 5,
            order: 5,
            kind: 'exam',
            tier: 'juz',
          );

          await studentRepository.setStudentPace('s1', CurriculumPace(2));

          final doc = await readStudent();
          expect(doc['current_level'], 1);
          expect(doc['current_session'], 5);
          expect(doc['current_session_kind'], 'exam');
          expect(doc['current_session_tier'], 'juz');
        },
      );
    });

    group('repositionEnrolledStudent', () {
      setUp(() async {
        await seedLevels(fakeFirestore);
        await seedLevelOneJuz30(fakeFirestore);
        await seedLevelTwoHead(fakeFirestore);
      });

      UserModel supervisor({String instituteId = 'i1'}) => UserModel(
        id: 'sup1',
        username: 'sup',
        email: 'sup@example.com',
        name: 'Supervisor',
        role: UserRole.supervisor,
        instituteId: instituteId,
        createdAt: DateTime(2026),
      );

      Future<void> seedRecord(String collection, {String studentId = 's1'}) {
        return fakeFirestore.collection(collection).add({
          'student_id': studentId,
          'date': Timestamp.now(),
        });
      }

      test('re-derives the position fields from the new anchor, reusing the '
          'enrollment derivation', () async {
        // A not-yet-started student enrolled at the very first session.
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        // Moved onto session 2 of the same hizb (an ordinary lesson).
        await studentRepository.repositionEnrolledStudent(
          studentId: 's1',
          newPosition: const CurriculumPosition(level: 1, juz: 30, session: 2),
          actor: supervisor(),
        );

        final doc = await readStudent();
        expect(doc['current_level'], 1);
        expect(doc['current_juz'], 30);
        expect(doc['current_session'], 2);
        expect(doc['current_order_in_level'], 2);
        expect(doc['current_session_id'], 'L1_J30_S2');
        expect(doc['current_session_kind'], 'lesson');
        expect(doc['current_attempt'], 1);
        expect(doc['enrollment_position'], {
          'level': 1,
          'juz': 30,
          'session': 2,
        });
        // Still level 1: nothing before it is a completed level.
        expect(doc['completed_levels'], isEmpty);
        expect(doc['unlocked_levels'], [1]);
      });

      test(
        'moving into a higher level credits every level before it as complete',
        () async {
          await seedStudent(level: 1, juz: 30, session: 1, order: 1);

          // Level 2 / juz 27 / session 1 — the head of level 2.
          await studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            newPosition: const CurriculumPosition(
              level: 2,
              juz: 27,
              session: 1,
            ),
            actor: supervisor(),
          );

          final doc = await readStudent();
          expect(doc['current_level'], 2);
          expect(doc['current_juz'], 27);
          expect(doc['enrollment_position'], {
            'level': 2,
            'juz': 27,
            'session': 1,
          });
          // Level 1 is now credited as memorized before joining.
          expect(doc['completed_levels'], [1]);
          expect(doc['unlocked_levels'], [1, 2]);
        },
      );

      test('records a lightweight audit of who moved whom, from/to', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await studentRepository.repositionEnrolledStudent(
          studentId: 's1',
          newPosition: const CurriculumPosition(level: 2, juz: 27, session: 1),
          actor: supervisor(),
        );

        final audit = await fakeFirestore
            .collection('students')
            .doc('s1')
            .collection('reposition_audit')
            .get();
        expect(audit.docs, hasLength(1));
        final entry = audit.docs.first.data();
        expect(entry['moved_by'], 'sup1');
        expect(entry['from'], {'level': 1, 'juz': 30, 'session': 1});
        expect(entry['to'], {'level': 2, 'juz': 27, 'session': 1});
      });

      test(
        'rejects the move when the student has ANY session record and leaves '
        'the student untouched',
        () async {
          await seedStudent(level: 1, juz: 30, session: 1, order: 1);
          await seedRecord('session_records');

          await expectLater(
            studentRepository.repositionEnrolledStudent(
              studentId: 's1',
              newPosition: const CurriculumPosition(
                level: 2,
                juz: 27,
                session: 1,
              ),
              actor: supervisor(),
            ),
            throwsA(isA<StudentAlreadyStartedException>()),
          );

          final doc = await readStudent();
          expect(doc['current_level'], 1);
          expect(doc['current_session'], 1);
        },
      );

      test('rejects the move when the student has a سرد record', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        await seedRecord('sard_records');

        await expectLater(
          studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            newPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 2,
            ),
            actor: supervisor(),
          ),
          throwsA(isA<StudentAlreadyStartedException>()),
        );
      });

      test('rejects the move when the student has an اختبار record', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);
        await seedRecord('exam_records');

        await expectLater(
          studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            newPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 2,
            ),
            actor: supervisor(),
          ),
          throwsA(isA<StudentAlreadyStartedException>()),
        );
      });

      test('rejects a caller who is not a supervisor', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        final teacher = UserModel(
          id: 't1',
          email: 't@example.com',
          name: 'Teacher',
          role: UserRole.teacher,
          instituteId: 'i1',
          createdAt: DateTime(2026),
        );

        await expectLater(
          studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            newPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 2,
            ),
            actor: teacher,
          ),
          throwsA(isA<RepositionNotAuthorizedException>()),
        );
      });

      test('rejects a supervisor of a DIFFERENT institute', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await expectLater(
          studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            newPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 2,
            ),
            actor: supervisor(instituteId: 'other-institute'),
          ),
          throwsA(isA<RepositionNotAuthorizedException>()),
        );
      });

      test('rejects a position that has no curriculum session', () async {
        await seedStudent(level: 1, juz: 30, session: 1, order: 1);

        await expectLater(
          studentRepository.repositionEnrolledStudent(
            studentId: 's1',
            // No session 999 is seeded anywhere.
            newPosition: const CurriculumPosition(
              level: 1,
              juz: 30,
              session: 999,
            ),
            actor: supervisor(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
