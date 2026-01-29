import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  superAdmin,
  supervisor,
  teacher,
  student,
  guardian,
}

extension UserRoleExtension on UserRole {
  String get value {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.student:
        return 'student';
      case UserRole.guardian:
        return 'guardian';
    }
  }

  String get nameAr {
    switch (this) {
      case UserRole.superAdmin:
        return 'مدير النظام';
      case UserRole.supervisor:
        return 'مشرف';
      case UserRole.teacher:
        return 'معلم';
      case UserRole.student:
        return 'طالب';
      case UserRole.guardian:
        return 'ولي أمر';
    }
  }

  String get nameEn {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.guardian:
        return 'Guardian';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'supervisor':
        return UserRole.supervisor;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'guardian':
        return UserRole.guardian;
      default:
        return UserRole.student;
    }
  }
}

class UserModel {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      phone: data['phone'] ?? '',
      name: data['name'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'student'),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phone': phone,
      'name': name,
      'role': role.value,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, phone: $phone, role: ${role.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
