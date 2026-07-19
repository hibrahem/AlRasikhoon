import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/institute_model.dart';
import '../services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../services/firestore_read_source.dart';

class InstituteRepository {
  final FirebaseFirestore _firestore;

  /// Where reads resolve from — offline they pin to the local cache instead
  /// of waiting out a doomed server attempt (al_rasikhoon-gy4).
  final FirestoreReadSource _read;

  InstituteRepository({FirebaseFirestore? firestore, FirestoreReadSource? readSource})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _read = readSource ?? const FirestoreReadSource.alwaysOnline();

  CollectionReference<Map<String, dynamic>> get _institutesCollection =>
      _firestore.collection(AppConstants.collectionInstitutes);

  CollectionReference<Map<String, dynamic>> get _teacherInstitutesCollection =>
      _firestore.collection(AppConstants.collectionTeacherInstitutes);

  CollectionReference<Map<String, dynamic>> get _supervisorInstitutesCollection =>
      _firestore.collection(AppConstants.collectionSupervisorInstitutes);

  /// Get all institutes
  Future<List<InstituteModel>> getInstitutes() async {
    final query = await _read.getQuery(_institutesCollection
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        );

    return query.docs.map((doc) => InstituteModel.fromFirestore(doc)).toList();
  }

  /// Get institute by ID
  Future<InstituteModel?> getInstituteById(String instituteId) async {
    final doc = await _read.getDoc(_institutesCollection.doc(instituteId));
    if (doc.exists) {
      return InstituteModel.fromFirestore(doc);
    }
    return null;
  }

  /// Create new institute
  Future<InstituteModel> createInstitute({
    required String name,
    required String location,
    required String createdBy,
  }) async {
    final docRef = _institutesCollection.doc();
    final institute = InstituteModel(
      id: docRef.id,
      name: name,
      location: location,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await docRef.set(institute.toFirestore());
    return institute;
  }

  /// Update institute
  Future<void> updateInstitute(InstituteModel institute) async {
    await _institutesCollection.doc(institute.id).update({
      ...institute.toFirestore(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete institute (soft delete)
  Future<void> deleteInstitute(String instituteId) async {
    await _institutesCollection.doc(instituteId).update({
      'is_active': false,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Assign teacher to institute
  Future<void> assignTeacherToInstitute({
    required String teacherId,
    required String instituteId,
  }) async {
    final docId = '${teacherId}_$instituteId';
    await _teacherInstitutesCollection.doc(docId).set({
      'teacher_id': teacherId,
      'institute_id': instituteId,
      'assigned_at': FieldValue.serverTimestamp(),
      'is_active': true,
    });
  }

  /// Remove teacher from institute
  Future<void> removeTeacherFromInstitute({
    required String teacherId,
    required String instituteId,
  }) async {
    final docId = '${teacherId}_$instituteId';
    await _teacherInstitutesCollection.doc(docId).update({
      'is_active': false,
      'removed_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get institutes for teacher
  Future<List<InstituteModel>> getInstitutesForTeacher(String teacherId) async {
    final assignments = await _read.getQuery(_teacherInstitutesCollection
        .where('teacher_id', isEqualTo: teacherId)
        .where('is_active', isEqualTo: true)
        );

    final instituteIds = assignments.docs
        .map((doc) => doc.data()['institute_id'] as String)
        .toList();

    if (instituteIds.isEmpty) return [];

    final institutes = await Future.wait(
      instituteIds.map((id) => getInstituteById(id)),
    );

    return institutes.whereType<InstituteModel>().toList();
  }

  /// Get teachers for institute
  Future<List<String>> getTeacherIdsForInstitute(String instituteId) async {
    final assignments = await _read.getQuery(_teacherInstitutesCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('is_active', isEqualTo: true)
        );

    return assignments.docs
        .map((doc) => doc.data()['teacher_id'] as String)
        .toList();
  }

  /// Assign supervisor to institute
  Future<void> assignSupervisorToInstitute({
    required String supervisorId,
    required String instituteId,
  }) async {
    final docId = '${supervisorId}_$instituteId';
    await _supervisorInstitutesCollection.doc(docId).set({
      'supervisor_id': supervisorId,
      'institute_id': instituteId,
      'assigned_at': FieldValue.serverTimestamp(),
      'is_active': true,
    });
  }

  /// Remove supervisor from institute
  Future<void> removeSupervisorFromInstitute({
    required String supervisorId,
    required String instituteId,
  }) async {
    final docId = '${supervisorId}_$instituteId';
    await _supervisorInstitutesCollection.doc(docId).update({
      'is_active': false,
      'removed_at': FieldValue.serverTimestamp(),
    });
  }

  /// Get institutes for supervisor
  Future<List<InstituteModel>> getInstitutesForSupervisor(String supervisorId) async {
    final assignments = await _read.getQuery(_supervisorInstitutesCollection
        .where('supervisor_id', isEqualTo: supervisorId)
        .where('is_active', isEqualTo: true)
        );

    final instituteIds = assignments.docs
        .map((doc) => doc.data()['institute_id'] as String)
        .toList();

    if (instituteIds.isEmpty) return [];

    final institutes = await Future.wait(
      instituteIds.map((id) => getInstituteById(id)),
    );

    return institutes.whereType<InstituteModel>().toList();
  }

  /// Get supervisors for institute
  Future<List<String>> getSupervisorIdsForInstitute(String instituteId) async {
    final assignments = await _read.getQuery(_supervisorInstitutesCollection
        .where('institute_id', isEqualTo: instituteId)
        .where('is_active', isEqualTo: true)
        );

    return assignments.docs
        .map((doc) => doc.data()['supervisor_id'] as String)
        .toList();
  }

  /// Stream institutes
  Stream<List<InstituteModel>> streamInstitutes() {
    return _institutesCollection
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InstituteModel.fromFirestore(doc))
            .toList());
  }
}

final instituteRepositoryProvider = Provider<InstituteRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return InstituteRepository(
    firestore: firestore,
    readSource: ref.watch(firestoreReadSourceProvider),
  );
});
