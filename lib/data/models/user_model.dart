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

enum UserAuthProvider {
  google,
  emailPassword,
  emailLink,
  pending,
}

extension UserAuthProviderExtension on UserAuthProvider {
  String get value {
    switch (this) {
      case UserAuthProvider.google:
        return 'google';
      case UserAuthProvider.emailPassword:
        return 'email_password';
      case UserAuthProvider.emailLink:
        return 'email_link';
      case UserAuthProvider.pending:
        return 'pending';
    }
  }

  static UserAuthProvider fromString(String? value) {
    switch (value) {
      case 'google':
        return UserAuthProvider.google;
      case 'email_password':
        return UserAuthProvider.emailPassword;
      case 'email_link':
        return UserAuthProvider.emailLink;
      case 'pending':
        return UserAuthProvider.pending;
      default:
        return UserAuthProvider.pending;
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String? phone;
  final String name;
  final UserRole role;
  final UserAuthProvider authProvider;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const UserModel({
    required this.id,
    required this.email,
    this.phone,
    required this.name,
    required this.role,
    this.authProvider = UserAuthProvider.pending,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      phone: data['phone'],
      name: data['name'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'student'),
      authProvider: UserAuthProviderExtension.fromString(data['auth_provider']),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'phone': phone,
      'name': name,
      'role': role.value,
      'auth_provider': authProvider.value,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? name,
    UserRole? role,
    UserAuthProvider? authProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: ${role.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
