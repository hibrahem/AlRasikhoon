import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/repositories/user_repository.dart';

/// Wraps a [FakeFirebaseFirestore] but makes `delete()` on a specific
/// `<collection>/<docId>` path throw a `permission-denied` FirebaseException —
/// simulating the real Firestore rule rejection during legacy-doc migration.
class _DeleteDeniedFirestore extends Mock implements FirebaseFirestore {
  _DeleteDeniedFirestore(this._delegate, this._denyCollection, this._denyDocId);

  final FirebaseFirestore _delegate;
  final String _denyCollection;
  final String _denyDocId;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final inner = _delegate.collection(path);
    if (path == _denyCollection) {
      return _DeleteDeniedCollection(inner, _denyDocId);
    }
    return inner;
  }
}

// `CollectionReference` (via its sealed ancestor `Query`) is `sealed` in
// cloud_firestore v6+. mocktail's only mechanism for a test double is
// `extends Mock implements <type>`; there is no non-sealed seam to inject the
// simulated `permission-denied` on `delete()`. Scoped to this one declaration.
// ignore: subtype_of_sealed_class
class _DeleteDeniedCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {
  _DeleteDeniedCollection(this._delegate, this._denyDocId);

  final CollectionReference<Map<String, dynamic>> _delegate;
  final String _denyDocId;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final inner = _delegate.doc(path);
    if (path == _denyDocId) {
      return _DeleteDeniedDocument(inner);
    }
    return inner;
  }
}

// `DocumentReference` is `sealed` in cloud_firestore v6+. Same rationale as
// `_DeleteDeniedCollection` above: mocktail requires `implements` of the
// sealed type to override `delete()` with the simulated failure. Scoped here.
// ignore: subtype_of_sealed_class
class _DeleteDeniedDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {
  _DeleteDeniedDocument(this._delegate);

  final DocumentReference<Map<String, dynamic>> _delegate;

  @override
  Future<void> delete() {
    return Future.error(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      _delegate.get(options);
}

void main() {
  group('UserRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = UserRepository(firestore: fakeFirestore);
    });

    group('createUser', () {
      test('creates user with all required fields', () async {
        final user = await repository.createUser(
          id: 'user123',
          username: 'mohammed.a',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'محمد أحمد',
          role: UserRole.teacher,
        );

        expect(user.id, 'user123');
        expect(user.username, 'mohammed.a');
        expect(user.email, 'test@example.com');
        expect(user.phone, '+966512345678');
        expect(user.name, 'محمد أحمد');
        expect(user.role, UserRole.teacher);
        expect(user.isActive, true);
      });

      test('persists user to Firestore with username', () async {
        await repository.createUser(
          id: 'user123',
          username: 'test_user',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.student,
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['username'], 'test_user');
        expect(doc.data()?['email'], 'test@example.com');
        expect(doc.data()?['phone'], '+966512345678');
        expect(doc.data()?['name'], 'Test User');
        expect(doc.data()?['role'], 'student');
      });

      test('lowercases username', () async {
        final user = await repository.createUser(
          id: 'user123',
          username: 'Mohammed_A',
          email: 'test@example.com',
          name: 'Test',
          role: UserRole.student,
        );

        expect(user.username, 'mohammed_a');
      });
    });

    group('getUserById', () {
      test('returns user when exists', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'phone': '+966512345678',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.getUserById('user123');

        expect(user, isNotNull);
        expect(user?.id, 'user123');
        expect(user?.name, 'Test User');
        expect(user?.role, UserRole.teacher);
      });

      test('returns null when user does not exist', () async {
        final user = await repository.getUserById('nonexistent');

        expect(user, isNull);
      });
    });

    group('getUserByEmail', () {
      test('finds user by email', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.getUserByEmail('test@example.com');

        expect(user, isNotNull);
        expect(user?.email, 'test@example.com');
      });

      test('returns null when email not found', () async {
        final user = await repository.getUserByEmail('nonexistent@example.com');

        expect(user, isNull);
      });

      test('matches lowercase email', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.getUserByEmail('test@example.com');

        expect(user, isNotNull);
      });
    });

    group('getUserByUsername', () {
      test('finds user by username', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'username': 'mohammed.a',
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.getUserByUsername('mohammed.a');

        expect(user, isNotNull);
        expect(user?.id, 'user123');
        expect(user?.username, 'mohammed.a');
      });

      test('returns null when username not found', () async {
        final user = await repository.getUserByUsername('nobody');

        expect(user, isNull);
      });

      test('matches lowercase form', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'username': 'mohammed.a',
          'email': 'test@example.com',
          'name': 'Test',
          'role': 'student',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.getUserByUsername('Mohammed.A');

        expect(user, isNotNull);
        expect(user?.username, 'mohammed.a');
      });
    });

    group('updateUser', () {
      test('updates user fields', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'phone': '+966512345678',
          'name': 'Original Name',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Updated Name',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
          isActive: false,
        );

        await repository.updateUser(user);

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        expect(doc.data()?['name'], 'Updated Name');
        expect(doc.data()?['is_active'], false);
      });
    });

    group('deleteUser', () {
      test('soft deletes user by setting is_active to false', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'phone': '+966512345678',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await repository.deleteUser('user123');

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['is_active'], false);
      });
    });

    group('getUsersByRole', () {
      setUp(() async {
        // Create users with different roles
        await fakeFirestore.collection('users').doc('teacher1').set({
          'phone': '+966512345671',
          'name': 'Teacher 1',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('users').doc('teacher2').set({
          'phone': '+966512345672',
          'name': 'Teacher 2',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('users').doc('student1').set({
          'phone': '+966512345673',
          'name': 'Student 1',
          'role': 'student',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('users').doc('inactiveTeacher').set({
          'phone': '+966512345674',
          'name': 'Inactive Teacher',
          'role': 'teacher',
          'is_active': false,
          'created_at': Timestamp.now(),
        });
      });

      test('returns only active users with specified role', () async {
        final teachers = await repository.getUsersByRole(UserRole.teacher);

        expect(teachers.length, 2);
        expect(teachers.every((t) => t.role == UserRole.teacher), true);
        expect(teachers.every((t) => t.isActive), true);
      });

      test('excludes inactive users', () async {
        final teachers = await repository.getUsersByRole(UserRole.teacher);

        expect(teachers.any((t) => t.name == 'Inactive Teacher'), false);
      });
    });

    group('getTeachers', () {
      test('returns all active teachers', () async {
        await fakeFirestore.collection('users').doc('teacher1').set({
          'phone': '+966512345671',
          'name': 'Teacher 1',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final teachers = await repository.getTeachers();

        expect(teachers.isNotEmpty, true);
        expect(teachers.first.role, UserRole.teacher);
      });
    });

    group('getSupervisors', () {
      test('returns all active supervisors', () async {
        await fakeFirestore.collection('users').doc('supervisor1').set({
          'phone': '+966512345671',
          'name': 'Supervisor 1',
          'role': 'supervisor',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final supervisors = await repository.getSupervisors();

        expect(supervisors.isNotEmpty, true);
        expect(supervisors.first.role, UserRole.supervisor);
      });
    });

    group('migrateUserToFirebaseUid', () {
      test('creates new document with Firebase UID', () async {
        await fakeFirestore.collection('users').doc('oldId123').set({
          'phone': '+966512345678',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.migrateUserToFirebaseUid(
          oldId: 'oldId123',
          newFirebaseUid: 'firebaseUid456',
        );

        expect(user, isNotNull);
        expect(user?.id, 'firebaseUid456');
      });

      test('deletes old document after migration', () async {
        await fakeFirestore.collection('users').doc('oldId123').set({
          'phone': '+966512345678',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await repository.migrateUserToFirebaseUid(
          oldId: 'oldId123',
          newFirebaseUid: 'firebaseUid456',
        );

        final oldDoc = await fakeFirestore
            .collection('users')
            .doc('oldId123')
            .get();
        expect(oldDoc.exists, false);
      });

      test('preserves user data during migration', () async {
        await fakeFirestore.collection('users').doc('oldId123').set({
          'phone': '+966512345678',
          'name': 'محمد أحمد',
          'role': 'supervisor',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.migrateUserToFirebaseUid(
          oldId: 'oldId123',
          newFirebaseUid: 'firebaseUid456',
        );

        expect(user?.phone, '+966512345678');
        expect(user?.name, 'محمد أحمد');
        expect(user?.role, UserRole.supervisor);
      });

      test('returns existing user when IDs are same', () async {
        await fakeFirestore.collection('users').doc('sameId').set({
          'phone': '+966512345678',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final user = await repository.migrateUserToFirebaseUid(
          oldId: 'sameId',
          newFirebaseUid: 'sameId',
        );

        expect(user, isNotNull);
        expect(user?.id, 'sameId');

        // Document should still exist
        final doc = await fakeFirestore.collection('users').doc('sameId').get();
        expect(doc.exists, true);
      });

      test('returns null when old document does not exist', () async {
        final user = await repository.migrateUserToFirebaseUid(
          oldId: 'nonexistent',
          newFirebaseUid: 'newId',
        );

        expect(user, isNull);
      });

      test(
        'returns migrated user even when deleting old doc is denied',
        () async {
          await fakeFirestore.collection('users').doc('oldId123').set({
            'email': 'test@example.com',
            'phone': '+966512345678',
            'name': 'Test User',
            'role': 'teacher',
            'is_active': true,
            'created_at': Timestamp.now(),
          });

          final firestore = _DeleteDeniedFirestore(
            fakeFirestore,
            'users',
            'oldId123',
          );
          final repoWithDeniedDelete = UserRepository(firestore: firestore);

          final user = await repoWithDeniedDelete.migrateUserToFirebaseUid(
            oldId: 'oldId123',
            newFirebaseUid: 'firebaseUid456',
          );

          expect(user, isNotNull);
          expect(user?.id, 'firebaseUid456');
          expect(user?.email, 'test@example.com');

          // The new UID-keyed doc was successfully written.
          final newDoc = await fakeFirestore
              .collection('users')
              .doc('firebaseUid456')
              .get();
          expect(newDoc.exists, true);
        },
      );
    });

    group('searchUsers', () {
      setUp(() async {
        await fakeFirestore.collection('users').doc('user1').set({
          'phone': '+966512345671',
          'name': 'محمد أحمد',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('users').doc('user2').set({
          'phone': '+966512345672',
          'name': 'أحمد علي',
          'role': 'student',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('users').doc('user3').set({
          'phone': '+966512345673',
          'name': 'عبدالله',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
      });

      test('searches by name substring', () async {
        final results = await repository.searchUsers('أحمد');

        expect(results.length, 2);
      });

      test('searches by phone substring', () async {
        final results = await repository.searchUsers('512345671');

        expect(results.length, 1);
        expect(results.first.name, 'محمد أحمد');
      });

      test('filters by role when specified', () async {
        final results = await repository.searchUsers(
          'أحمد',
          role: UserRole.teacher,
        );

        expect(results.length, 1);
        expect(results.first.role, UserRole.teacher);
      });
    });

    group('streamUser', () {
      test('emits user when document changes', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'phone': '+966512345678',
          'name': 'Initial Name',
          'role': 'teacher',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final stream = repository.streamUser('user123');

        expectLater(
          stream,
          emitsInOrder([
            isA<UserModel>().having((u) => u.name, 'name', 'Initial Name'),
          ]),
        );
      });

      test('emits null when document does not exist', () async {
        final stream = repository.streamUser('nonexistent');

        expectLater(stream, emits(isNull));
      });
    });
  });
}
