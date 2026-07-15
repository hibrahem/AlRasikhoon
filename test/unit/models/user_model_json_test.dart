import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';

void main() {
  test('UserModel survives a toJson/fromJson round-trip with all fields', () {
    final original = UserModel(
      id: 'user-123',
      username: 'ustadh',
      email: 'ustadh@alrasikhoon.local',
      phone: '0500000000',
      name: 'الأستاذ',
      role: UserRole.teacher,
      authProvider: UserAuthProvider.emailPassword,
      instituteId: 'inst-9',
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      updatedAt: DateTime.utc(2026, 6, 7, 8, 9, 10),
      isActive: true,
    );

    final restored = UserModel.fromJson(original.toJson());

    expect(restored.id, 'user-123');
    expect(restored.username, 'ustadh');
    expect(restored.email, 'ustadh@alrasikhoon.local');
    expect(restored.phone, '0500000000');
    expect(restored.name, 'الأستاذ');
    expect(restored.role, UserRole.teacher);
    expect(restored.authProvider, UserAuthProvider.emailPassword);
    expect(restored.instituteId, 'inst-9');
    expect(restored.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(restored.updatedAt, DateTime.utc(2026, 6, 7, 8, 9, 10));
    expect(restored.isActive, true);
  });

  test('fromJson tolerates a null updatedAt and defaults isActive to true', () {
    final json = {
      'id': 'u1',
      'username': 's',
      'email': 's@x.local',
      'phone': null,
      'name': 'n',
      'role': 'student',
      'auth_provider': 'pending',
      'institute_id': null,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updated_at': null,
    };

    final user = UserModel.fromJson(json);

    expect(user.updatedAt, isNull);
    expect(user.isActive, true);
    expect(user.role, UserRole.student);
  });
}
