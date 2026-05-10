import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class FirebaseService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  // Auth methods
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  bool get isAuthenticated => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Email/Password auth — feeds the synthesized
  // '<username>@alrasikhoon.local' email under the hood.
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Atomic server-side account provisioning. Creates both the Firebase Auth
  // user AND the users/{uid} Firestore profile in one call (with rollback
  // on partial failure). The client SDK's createUserWithEmailAndPassword
  // auto-signs-in the new user and would evict the caller's session — so
  // admin/teacher account creation goes through this Cloud Function instead.
  Future<String> provisionUserAccount({
    required String email,
    required String password,
    required String role,
    required String name,
    required String username,
    String? phone,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createUserAccount',
    );
    final result = await callable.call<Map<Object?, Object?>>({
      'email': email,
      'password': password,
      'role': role,
      'name': name,
      'username': username,
      'phone': phone,
    });
    final uid = result.data['uid'];
    if (uid is! String || uid.isEmpty) {
      throw StateError('createUserAccount returned no uid');
    }
    return uid;
  }

  // Firestore helpers
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  DocumentReference<Map<String, dynamic>> document(String path) {
    return _firestore.doc(path);
  }

  WriteBatch batch() {
    return _firestore.batch();
  }
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
