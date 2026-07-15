import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';

enum UserRole { superAdmin, supervisor, teacher, student, guardian }

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

enum UserAuthProvider { emailPassword, pending }

extension UserAuthProviderExtension on UserAuthProvider {
  String get value {
    switch (this) {
      case UserAuthProvider.emailPassword:
        return 'email_password';
      case UserAuthProvider.pending:
        return 'pending';
    }
  }

  static UserAuthProvider fromString(String? value) {
    switch (value) {
      case 'email_password':
        return UserAuthProvider.emailPassword;
      default:
        return UserAuthProvider.pending;
    }
  }
}

class UserModel {
  final String id;
  final String username;
  final String email;
  final String? phone;
  final String name;
  final UserRole role;
  final UserAuthProvider authProvider;

  /// The institute this user is bound to. Set for supervisors (one institute
  /// per supervisor); null for other roles. Carried on the account record so
  /// the supervisor permission/scoping model can enforce it.
  final String? instituteId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const UserModel({
    required this.id,
    this.username = '',
    required this.email,
    this.phone,
    required this.name,
    required this.role,
    this.authProvider = UserAuthProvider.pending,
    this.instituteId,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      username: (data['username'] as String?) ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      name: data['name'] ?? '',
      role: UserRoleExtension.fromString(data['role'] ?? 'student'),
      authProvider: UserAuthProviderExtension.fromString(data['auth_provider']),
      instituteId: data['institute_id'] as String?,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role.value,
      'auth_provider': authProvider.value,
      'institute_id': instituteId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_active': isActive,
    };
  }

  /// Framework-free JSON for the local session cache. Unlike [toFirestore],
  /// this includes the [id] and uses ISO-8601 date strings (no Firestore
  /// Timestamp), so it round-trips through plain storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'name': name,
      'role': role.value,
      'auth_provider': authProvider.value,
      'institute_id': instituteId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      name: (json['name'] as String?) ?? '',
      role: UserRoleExtension.fromString(
        (json['role'] as String?) ?? 'student',
      ),
      authProvider: UserAuthProviderExtension.fromString(
        json['auth_provider'] as String?,
      ),
      instituteId: json['institute_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    String? name,
    UserRole? role,
    UserAuthProvider? authProvider,
    String? instituteId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      authProvider: authProvider ?? this.authProvider,
      instituteId: instituteId ?? this.instituteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// The user-visible login name — never the synthesized auth email.
  ///
  /// Prefers the stored [username]; falls back to stripping the synthesized
  /// `@${AppConstants.synthesizedEmailDomain}` domain off legacy records that
  /// predate the username field. A genuinely non-synthesized email (or an
  /// empty one) is returned unchanged.
  String get displayUsername {
    if (username.isNotEmpty) return username;
    final suffix = '@${AppConstants.synthesizedEmailDomain}';
    if (email.endsWith(suffix)) {
      return email.substring(0, email.length - suffix.length);
    }
    return email;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, username: $username, name: $name, role: ${role.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
