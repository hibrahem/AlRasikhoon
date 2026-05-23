import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';

void main() {
  group('UserRole', () {
    group('value', () {
      test('superAdmin returns super_admin', () {
        expect(UserRole.superAdmin.value, 'super_admin');
      });

      test('supervisor returns supervisor', () {
        expect(UserRole.supervisor.value, 'supervisor');
      });

      test('teacher returns teacher', () {
        expect(UserRole.teacher.value, 'teacher');
      });

      test('student returns student', () {
        expect(UserRole.student.value, 'student');
      });

      test('guardian returns guardian', () {
        expect(UserRole.guardian.value, 'guardian');
      });
    });

    group('nameAr', () {
      test('superAdmin returns مدير النظام', () {
        expect(UserRole.superAdmin.nameAr, 'مدير النظام');
      });

      test('supervisor returns مشرف', () {
        expect(UserRole.supervisor.nameAr, 'مشرف');
      });

      test('teacher returns معلم', () {
        expect(UserRole.teacher.nameAr, 'معلم');
      });

      test('student returns طالب', () {
        expect(UserRole.student.nameAr, 'طالب');
      });

      test('guardian returns ولي أمر', () {
        expect(UserRole.guardian.nameAr, 'ولي أمر');
      });
    });

    group('nameEn', () {
      test('superAdmin returns Super Admin', () {
        expect(UserRole.superAdmin.nameEn, 'Super Admin');
      });

      test('supervisor returns Supervisor', () {
        expect(UserRole.supervisor.nameEn, 'Supervisor');
      });

      test('teacher returns Teacher', () {
        expect(UserRole.teacher.nameEn, 'Teacher');
      });

      test('student returns Student', () {
        expect(UserRole.student.nameEn, 'Student');
      });

      test('guardian returns Guardian', () {
        expect(UserRole.guardian.nameEn, 'Guardian');
      });
    });

    group('fromString', () {
      test('converts super_admin to superAdmin', () {
        expect(
          UserRoleExtension.fromString('super_admin'),
          UserRole.superAdmin,
        );
      });

      test('converts supervisor to supervisor', () {
        expect(UserRoleExtension.fromString('supervisor'), UserRole.supervisor);
      });

      test('converts teacher to teacher', () {
        expect(UserRoleExtension.fromString('teacher'), UserRole.teacher);
      });

      test('converts student to student', () {
        expect(UserRoleExtension.fromString('student'), UserRole.student);
      });

      test('converts guardian to guardian', () {
        expect(UserRoleExtension.fromString('guardian'), UserRole.guardian);
      });

      test('defaults to student for invalid role', () {
        expect(UserRoleExtension.fromString('invalid'), UserRole.student);
      });

      test('defaults to student for empty string', () {
        expect(UserRoleExtension.fromString(''), UserRole.student);
      });
    });
  });

  group('UserAuthProvider', () {
    group('value', () {
      test('emailPassword returns email_password', () {
        expect(UserAuthProvider.emailPassword.value, 'email_password');
      });

      test('pending returns pending', () {
        expect(UserAuthProvider.pending.value, 'pending');
      });
    });

    group('fromString', () {
      test('converts email_password to emailPassword', () {
        expect(
          UserAuthProviderExtension.fromString('email_password'),
          UserAuthProvider.emailPassword,
        );
      });

      test('converts pending to pending', () {
        expect(
          UserAuthProviderExtension.fromString('pending'),
          UserAuthProvider.pending,
        );
      });

      test('legacy google value falls back to pending', () {
        expect(
          UserAuthProviderExtension.fromString('google'),
          UserAuthProvider.pending,
        );
      });

      test('legacy email_link value falls back to pending', () {
        expect(
          UserAuthProviderExtension.fromString('email_link'),
          UserAuthProvider.pending,
        );
      });

      test('defaults to pending for invalid value', () {
        expect(
          UserAuthProviderExtension.fromString('invalid'),
          UserAuthProvider.pending,
        );
      });

      test('defaults to pending for null', () {
        expect(
          UserAuthProviderExtension.fromString(null),
          UserAuthProvider.pending,
        );
      });

      test('defaults to pending for empty string', () {
        expect(
          UserAuthProviderExtension.fromString(''),
          UserAuthProvider.pending,
        );
      });
    });
  });

  group('UserModel', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('constructor', () {
      test('creates model with required fields', () {
        final now = DateTime.now();
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.teacher,
          createdAt: now,
        );

        expect(user.id, 'user123');
        expect(user.email, 'test@example.com');
        expect(user.phone, '+966512345678');
        expect(user.name, 'Test User');
        expect(user.role, UserRole.teacher);
        expect(user.createdAt, now);
        expect(user.updatedAt, isNull);
        expect(user.isActive, true);
      });

      test('defaults username to empty string', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        expect(user.username, '');
      });

      test('allows setting username', () {
        final user = UserModel(
          id: 'user123',
          username: 'mohammed.a',
          email: 'test@example.com',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        expect(user.username, 'mohammed.a');
      });

      test('defaults isActive to true', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        expect(user.isActive, true);
      });

      test('defaults authProvider to pending', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        expect(user.authProvider, UserAuthProvider.pending);
      });

      test('defaults instituteId to null', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          name: 'Test User',
          role: UserRole.supervisor,
          createdAt: DateTime.now(),
        );

        expect(user.instituteId, isNull);
      });

      test('allows setting instituteId for a supervisor', () {
        final user = UserModel(
          id: 'sup123',
          email: 'test@example.com',
          name: 'Supervisor',
          role: UserRole.supervisor,
          instituteId: 'inst_abc',
          createdAt: DateTime.now(),
        );

        expect(user.instituteId, 'inst_abc');
        expect(user.role, UserRole.supervisor);
      });

      test('allows setting authProvider', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.student,
          authProvider: UserAuthProvider.emailPassword,
          createdAt: DateTime.now(),
        );

        expect(user.authProvider, UserAuthProvider.emailPassword);
      });
    });

    group('fromFirestore', () {
      test('deserializes all fields correctly', () async {
        final createdAt = DateTime(2024, 1, 15, 10, 30);
        final updatedAt = DateTime(2024, 1, 16, 14, 0);

        await fakeFirestore.collection('users').doc('user123').set({
          'username': 'mohammed.a',
          'phone': '+966512345678',
          'name': 'محمد أحمد',
          'role': 'teacher',
          'created_at': Timestamp.fromDate(createdAt),
          'updated_at': Timestamp.fromDate(updatedAt),
          'is_active': true,
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.id, 'user123');
        expect(user.username, 'mohammed.a');
        expect(user.phone, '+966512345678');
        expect(user.name, 'محمد أحمد');
        expect(user.role, UserRole.teacher);
        expect(user.createdAt.year, createdAt.year);
        expect(user.createdAt.month, createdAt.month);
        expect(user.createdAt.day, createdAt.day);
        expect(user.updatedAt?.year, updatedAt.year);
        expect(user.isActive, true);
      });

      test('deserializes institute_id for a supervisor', () async {
        await fakeFirestore.collection('users').doc('sup123').set({
          'username': 'super.a',
          'name': 'Supervisor',
          'role': 'supervisor',
          'institute_id': 'inst_abc',
          'is_active': true,
        });

        final doc =
            await fakeFirestore.collection('users').doc('sup123').get();
        final user = UserModel.fromFirestore(doc);

        expect(user.role, UserRole.supervisor);
        expect(user.instituteId, 'inst_abc');
      });

      test('institute_id is null when missing', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'name': 'Teacher',
          'role': 'teacher',
        });

        final doc =
            await fakeFirestore.collection('users').doc('user123').get();
        final user = UserModel.fromFirestore(doc);

        expect(user.instituteId, isNull);
      });

      test('defaults username to empty string when missing', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test',
          'role': 'student',
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.username, '');
      });

      test('handles missing optional fields', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'phone': '+966512345678',
          'name': 'Test',
          'role': 'student',
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.updatedAt, isNull);
        expect(user.isActive, true);
      });

      test('defaults to student role for missing role', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'phone': '+966512345678',
          'name': 'Test',
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.role, UserRole.student);
      });

      test('handles empty phone and name gracefully', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'role': 'teacher',
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.phone, isNull);
        expect(user.name, '');
        expect(user.email, '');
      });

      test('deserializes email_password auth_provider correctly', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'auth_provider': 'email_password',
          'is_active': true,
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.authProvider, UserAuthProvider.emailPassword);
      });

      test('legacy google auth_provider falls back to pending', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'auth_provider': 'google',
          'is_active': true,
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.authProvider, UserAuthProvider.pending);
      });

      test('legacy email_link auth_provider falls back to pending', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'auth_provider': 'email_link',
          'is_active': true,
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.authProvider, UserAuthProvider.pending);
      });

      test('defaults auth_provider to pending when missing', () async {
        await fakeFirestore.collection('users').doc('user123').set({
          'email': 'test@example.com',
          'name': 'Test User',
          'role': 'teacher',
          'is_active': true,
        });

        final doc = await fakeFirestore
            .collection('users')
            .doc('user123')
            .get();
        final user = UserModel.fromFirestore(doc);

        expect(user.authProvider, UserAuthProvider.pending);
      });
    });

    group('toFirestore', () {
      test('serializes all fields correctly', () {
        final createdAt = DateTime(2024, 1, 15, 10, 30);
        final updatedAt = DateTime(2024, 1, 16, 14, 0);

        final user = UserModel(
          id: 'user123',
          username: 'mohammed.a',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'محمد أحمد',
          role: UserRole.supervisor,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isActive: false,
        );

        final map = user.toFirestore();

        expect(map['username'], 'mohammed.a');
        expect(map['email'], 'test@example.com');
        expect(map['phone'], '+966512345678');
        expect(map['name'], 'محمد أحمد');
        expect(map['role'], 'supervisor');
        expect(map['is_active'], false);
        expect((map['created_at'] as Timestamp).toDate().year, createdAt.year);
        expect((map['updated_at'] as Timestamp).toDate().year, updatedAt.year);
      });

      test('serializes institute_id for a supervisor', () {
        final user = UserModel(
          id: 'sup123',
          username: 'super.a',
          email: 'test@example.com',
          name: 'Supervisor',
          role: UserRole.supervisor,
          instituteId: 'inst_abc',
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['institute_id'], 'inst_abc');
        expect(map['role'], 'supervisor');
      });

      test('serializes null institute_id when not set', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          name: 'Teacher',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['institute_id'], isNull);
      });

      test('serializes empty username when not set', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['username'], '');
      });

      test('handles null updatedAt', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['updated_at'], isNull);
      });

      test('serializes auth_provider correctly', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.student,
          authProvider: UserAuthProvider.emailPassword,
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['auth_provider'], 'email_password');
      });

      test('serializes pending auth_provider correctly', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final map = user.toFirestore();

        expect(map['auth_provider'], 'pending');
      });
    });

    group('copyWith', () {
      test('updates single field', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Original Name',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final updated = user.copyWith(name: 'New Name');

        expect(updated.name, 'New Name');
        expect(updated.id, user.id);
        expect(updated.email, user.email);
        expect(updated.phone, user.phone);
        expect(updated.role, user.role);
      });

      test('preserves unchanged fields', () {
        final createdAt = DateTime(2024, 1, 15);
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.teacher,
          createdAt: createdAt,
          isActive: false,
        );

        final updated = user.copyWith(name: 'New Name');

        expect(updated.createdAt, createdAt);
        expect(updated.isActive, false);
      });

      test('can update multiple fields', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final updated = user.copyWith(
          name: 'New Name',
          role: UserRole.teacher,
          isActive: false,
        );

        expect(updated.name, 'New Name');
        expect(updated.role, UserRole.teacher);
        expect(updated.isActive, false);
      });

      test('can update username', () {
        final user = UserModel(
          id: 'user123',
          username: 'old_name',
          email: 'test@example.com',
          name: 'Test',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final updated = user.copyWith(username: 'new_name');

        expect(updated.username, 'new_name');
        expect(updated.id, user.id);
        expect(updated.name, user.name);
      });

      test('can update instituteId', () {
        final user = UserModel(
          id: 'sup123',
          email: 'test@example.com',
          name: 'Supervisor',
          role: UserRole.supervisor,
          createdAt: DateTime.now(),
        );

        final updated = user.copyWith(instituteId: 'inst_xyz');

        expect(updated.instituteId, 'inst_xyz');
        expect(updated.id, user.id);
        expect(updated.role, UserRole.supervisor);
      });

      test('can update authProvider', () {
        final user = UserModel(
          id: 'user123',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test',
          role: UserRole.student,
          authProvider: UserAuthProvider.pending,
          createdAt: DateTime.now(),
        );

        final updated = user.copyWith(
          authProvider: UserAuthProvider.emailPassword,
        );

        expect(updated.authProvider, UserAuthProvider.emailPassword);
        expect(updated.name, 'Test'); // Other fields preserved
      });
    });

    group('equality', () {
      test('users with same id are equal', () {
        final user1 = UserModel(
          id: 'user123',
          email: 'user1@example.com',
          phone: '+966512345678',
          name: 'User 1',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final user2 = UserModel(
          id: 'user123',
          email: 'user2@example.com',
          phone: '+966599999999',
          name: 'Different Name',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
        );

        expect(user1, equals(user2));
      });

      test('users with different ids are not equal', () {
        final user1 = UserModel(
          id: 'user123',
          email: 'user@example.com',
          phone: '+966512345678',
          name: 'Same Name',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final user2 = UserModel(
          id: 'user456',
          email: 'user@example.com',
          phone: '+966512345678',
          name: 'Same Name',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        expect(user1, isNot(equals(user2)));
      });

      test('hashCode is consistent with equality', () {
        final user1 = UserModel(
          id: 'user123',
          email: 'user1@example.com',
          phone: '+966512345678',
          name: 'User 1',
          role: UserRole.student,
          createdAt: DateTime.now(),
        );

        final user2 = UserModel(
          id: 'user123',
          email: 'user2@example.com',
          phone: '+966599999999',
          name: 'Different',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
        );

        expect(user1.hashCode, equals(user2.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final user = UserModel(
          id: 'user123',
          username: 'test_user',
          email: 'test@example.com',
          phone: '+966512345678',
          name: 'Test User',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
        );

        final str = user.toString();

        expect(str, contains('user123'));
        expect(str, contains('test_user'));
        expect(str, contains('Test User'));
        expect(str, contains('teacher'));
      });
    });
  });
}
