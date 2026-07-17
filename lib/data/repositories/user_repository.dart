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

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    final query = await _usersCollection
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return UserModel.fromFirestore(query.docs.first);
    }
    return null;
  }

  /// Get user by username — the user-visible login identifier.
  Future<UserModel?> getUserByUsername(String username) async {
    final query = await _usersCollection
        .where('username', isEqualTo: username.toLowerCase())
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
    required String username,
    required String email,
    required String name,
    required UserRole role,
    String? phone,
    UserAuthProvider authProvider = UserAuthProvider.emailPassword,
  }) async {
    final user = UserModel(
      id: id,
      username: username.toLowerCase(),
      email: email.toLowerCase(),
      phone: phone,
      name: name,
      role: role,
      authProvider: authProvider,
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

  /// Update just the editable profile fields (name, phone).
  ///
  /// A targeted partial update rather than a full [updateUser] doc rewrite:
  /// the security rules freeze `role`/`institute_id` on self-edits, and a
  /// partial update provably never touches them. A null [phone] clears the
  /// stored number.
  Future<void> updateProfileFields({
    required String userId,
    required String name,
    String? phone,
  }) async {
    await _usersCollection.doc(userId).update({
      'name': name,
      'phone': phone,
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

  /// Get all users by role.
  ///
  /// [source] controls Firestore read behaviour. The default
  /// ([Source.serverAndCache]) is fine for normal list loads. Pass
  /// [Source.server] immediately after a server-side write (e.g. an
  /// account provisioned by the `createUserAccount` Cloud Function) to
  /// bypass the local cache, which has no copy of the freshly-written
  /// doc and would otherwise serve a stale result set.
  Future<List<UserModel>> getUsersByRole(
    UserRole role, {
    Source source = Source.serverAndCache,
  }) async {
    final query = await _usersCollection
        .where('role', isEqualTo: role.value)
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .get(GetOptions(source: source));

    return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Get all teachers.
  ///
  /// See [getUsersByRole] for the [source] semantics.
  Future<List<UserModel>> getTeachers({
    Source source = Source.serverAndCache,
  }) async {
    return getUsersByRole(UserRole.teacher, source: source);
  }

  /// Polls the teachers collection from the server until the teacher with
  /// [uid] is visible, or [maxAttempts] is exhausted.
  ///
  /// A teacher created via the `createUserAccount` Cloud Function is written
  /// server-side, so the client SDK has no local copy and a single immediate
  /// `get()` can race the write's propagation to the query index — the new
  /// teacher intermittently fails to appear in the list (issue #21). This
  /// performs a deterministic, server-sourced read-after-write confirmation
  /// (bounded retries) rather than relying on a fixed delay, returning the
  /// first result set that contains [uid] (or the last fetched set if the
  /// budget is exhausted).
  Future<List<UserModel>> getTeachersConfirmingUid(
    String uid, {
    int maxAttempts = 5,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) async {
    List<UserModel> teachers = const [];
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      teachers = await getTeachers(source: Source.server);
      if (teachers.any((t) => t.id == uid)) {
        return teachers;
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(retryDelay);
      }
    }
    return teachers;
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
    UserAuthProvider? authProvider,
  }) async {
    // Don't migrate if IDs are the same
    if (oldId == newFirebaseUid) {
      // Still update auth_provider if specified
      if (authProvider != null) {
        await _usersCollection.doc(oldId).update({
          'auth_provider': authProvider.value,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      return getUserById(oldId);
    }

    final oldDoc = await _usersCollection.doc(oldId).get();
    if (!oldDoc.exists) return null;

    final userData = oldDoc.data()!;

    // Create new document with Firebase UID
    await _usersCollection.doc(newFirebaseUid).set({
      ...userData,
      if (authProvider != null) 'auth_provider': authProvider.value,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Delete old document. Best-effort: a legacy doc whose email no longer
    // matches the auth token (or that was already deleted by a concurrent
    // migration) must not fail sign-in — the new UID-keyed doc already exists.
    try {
      await _usersCollection.doc(oldId).delete();
    } catch (_) {}

    // Update any student records that reference the old user ID
    final studentsQuery = await _firestore
        .collection(AppConstants.collectionStudents)
        .where('user_id', isEqualTo: oldId)
        .get();

    for (final studentDoc in studentsQuery.docs) {
      await studentDoc.reference.update({
        'user_id': newFirebaseUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    // Return the user with new ID
    final newDoc = await _usersCollection.doc(newFirebaseUid).get();
    if (newDoc.exists) {
      return UserModel.fromFirestore(newDoc);
    }
    return null;
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query, {UserRole? role}) async {
    Query<Map<String, dynamic>> baseQuery = _usersCollection.where(
      'is_active',
      isEqualTo: true,
    );

    if (role != null) {
      baseQuery = baseQuery.where('role', isEqualTo: role.value);
    }

    // Firestore doesn't support full-text search, so we'll get all and filter
    final result = await baseQuery.get();

    return result.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where(
          (user) =>
              user.name.toLowerCase().contains(query.toLowerCase()) ||
              user.email.toLowerCase().contains(query.toLowerCase()) ||
              (user.phone?.contains(query) ?? false),
        )
        .toList();
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return UserRepository(firestore: firestore);
});
