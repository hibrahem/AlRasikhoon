import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.collectionUsers);

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get user by phone number
  Future<UserModel?> getUserByPhone(String phone) async {
    final query = await _usersCollection
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return UserModel.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Create new user
  Future<UserModel> createUser({
    required String id,
    required String phone,
    required String name,
    required UserRole role,
  }) async {
    final user = UserModel(
      id: id,
      phone: phone,
      name: name,
      role: role,
      createdAt: DateTime.now(),
    );

    await _usersCollection.doc(id).set(user.toFirestore());
    return user;
  }

  /// Update user
  Future<void> updateUser(UserModel user) async {
    await _usersCollection.doc(user.id).update({
      ...user.toFirestore(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete user (soft delete)
  Future<void> deleteUser(String userId) async {
    await _usersCollection.doc(userId).update({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get all users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final query = await _usersCollection
        .where('role', isEqualTo: role.value)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get();

    return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Get all teachers
  Future<List<UserModel>> getTeachers() async {
    return getUsersByRole(UserRole.teacher);
  }

  /// Get all supervisors
  Future<List<UserModel>> getSupervisors() async {
    return getUsersByRole(UserRole.supervisor);
  }

  /// Stream user changes
  Stream<UserModel?> streamUser(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Migrate user document from old ID to Firebase UID
  /// This is needed when users are created by admin before they login
  Future<UserModel?> migrateUserToFirebaseUid({
    required String oldId,
    required String newFirebaseUid,
  }) async {
    // Don't migrate if IDs are the same
    if (oldId == newFirebaseUid) {
      return getUserById(oldId);
    }

    final oldDoc = await _usersCollection.doc(oldId).get();
    if (!oldDoc.exists) return null;

    final userData = oldDoc.data()!;

    // Create new document with Firebase UID
    await _usersCollection.doc(newFirebaseUid).set({
      ...userData,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Delete old document
    await _usersCollection.doc(oldId).delete();

    // Return the user with new ID
    final newDoc = await _usersCollection.doc(newFirebaseUid).get();
    if (newDoc.exists) {
      return UserModel.fromFirestore(newDoc);
    }
    return null;
  }

  /// Search users by name
  Future<List<UserModel>> searchUsers(String query, {UserRole? role}) async {
    Query<Map<String, dynamic>> baseQuery = _usersCollection
        .where('is_active', isEqualTo: true);

    if (role != null) {
      baseQuery = baseQuery.where('role', isEqualTo: role.value);
    }

    // Firestore doesn't support full-text search, so we'll get all and filter
    final result = await baseQuery.get();

    return result.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) =>
            user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.phone.contains(query))
        .toList();
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return UserRepository(firestore: firestore);
});
