import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/institute_model.dart';
import 'package:al_rasikhoon/data/repositories/institute_repository.dart';

void main() {
  group('InstituteRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InstituteRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InstituteRepository(firestore: fakeFirestore);
    });

    group('createInstitute', () {
      test('creates institute with all fields', () async {
        final institute = await repository.createInstitute(
          name: 'معهد الراسخون',
          location: 'الرياض',
          createdBy: 'admin1',
        );

        expect(institute.name, 'معهد الراسخون');
        expect(institute.location, 'الرياض');
        expect(institute.createdBy, 'admin1');
        expect(institute.isActive, true);
      });

      test('persists to Firestore', () async {
        final institute = await repository.createInstitute(
          name: 'معهد التقوى',
          location: 'جدة',
          createdBy: 'admin1',
        );

        final doc = await fakeFirestore
            .collection('institutes')
            .doc(institute.id)
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['name'], 'معهد التقوى');
      });
    });

    group('getInstituteById', () {
      test('returns institute when exists', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد النور',
          'location': 'مكة',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final institute = await repository.getInstituteById('i1');

        expect(institute, isNotNull);
        expect(institute?.name, 'معهد النور');
      });

      test('returns null when not found', () async {
        final institute = await repository.getInstituteById('nonexistent');
        expect(institute, isNull);
      });
    });

    group('getInstitutes', () {
      test('returns only active institutes', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد فعال',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('institutes').doc('i2').set({
          'name': 'معهد غير فعال',
          'location': 'جدة',
          'created_by': 'admin1',
          'is_active': false,
          'created_at': Timestamp.now(),
        });

        final institutes = await repository.getInstitutes();

        expect(institutes.length, 1);
        expect(institutes.first.name, 'معهد فعال');
      });

      test('returns empty list when no institutes', () async {
        final institutes = await repository.getInstitutes();
        expect(institutes, isEmpty);
      });
    });

    group('updateInstitute', () {
      test('updates institute fields', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'الاسم القديم',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        final institute = InstituteModel(
          id: 'i1',
          name: 'الاسم الجديد',
          location: 'جدة',
          createdBy: 'admin1',
          createdAt: DateTime.now(),
        );

        await repository.updateInstitute(institute);

        final doc = await fakeFirestore.collection('institutes').doc('i1').get();
        expect(doc.data()?['name'], 'الاسم الجديد');
        expect(doc.data()?['location'], 'جدة');
      });
    });

    group('deleteInstitute', () {
      test('soft deletes by setting is_active to false', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await repository.deleteInstitute('i1');

        final doc = await fakeFirestore.collection('institutes').doc('i1').get();
        expect(doc.data()?['is_active'], false);
      });
    });

    group('assignTeacherToInstitute', () {
      test('creates teacher-institute assignment', () async {
        await repository.assignTeacherToInstitute(
          teacherId: 'teacher1',
          instituteId: 'institute1',
        );

        final doc = await fakeFirestore
            .collection('teacher_institutes')
            .doc('teacher1_institute1')
            .get();
        expect(doc.exists, true);
        expect(doc.data()?['teacher_id'], 'teacher1');
        expect(doc.data()?['institute_id'], 'institute1');
        expect(doc.data()?['is_active'], true);
      });
    });

    group('removeTeacherFromInstitute', () {
      test('soft removes teacher assignment', () async {
        await fakeFirestore
            .collection('teacher_institutes')
            .doc('teacher1_institute1')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'institute1',
          'is_active': true,
        });

        await repository.removeTeacherFromInstitute(
          teacherId: 'teacher1',
          instituteId: 'institute1',
        );

        final doc = await fakeFirestore
            .collection('teacher_institutes')
            .doc('teacher1_institute1')
            .get();
        expect(doc.data()?['is_active'], false);
      });
    });

    group('getInstitutesForTeacher', () {
      test('returns institutes assigned to teacher', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد 1',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });
        await fakeFirestore.collection('institutes').doc('i2').set({
          'name': 'معهد 2',
          'location': 'جدة',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t1_i1')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'i1',
          'is_active': true,
        });
        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t1_i2')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'i2',
          'is_active': true,
        });

        final institutes = await repository.getInstitutesForTeacher('teacher1');

        expect(institutes.length, 2);
      });

      test('excludes inactive assignments', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t1_i1')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'i1',
          'is_active': false,
        });

        final institutes = await repository.getInstitutesForTeacher('teacher1');

        expect(institutes, isEmpty);
      });

      test('returns empty when teacher has no assignments', () async {
        final institutes =
            await repository.getInstitutesForTeacher('unassigned');

        expect(institutes, isEmpty);
      });
    });

    group('getTeacherIdsForInstitute', () {
      test('returns teacher IDs for institute', () async {
        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t1_i1')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'institute1',
          'is_active': true,
        });
        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t2_i1')
            .set({
          'teacher_id': 'teacher2',
          'institute_id': 'institute1',
          'is_active': true,
        });

        final teacherIds =
            await repository.getTeacherIdsForInstitute('institute1');

        expect(teacherIds.length, 2);
        expect(teacherIds, containsAll(['teacher1', 'teacher2']));
      });

      test('excludes inactive teachers', () async {
        await fakeFirestore
            .collection('teacher_institutes')
            .doc('t1_i1')
            .set({
          'teacher_id': 'teacher1',
          'institute_id': 'institute1',
          'is_active': false,
        });

        final teacherIds =
            await repository.getTeacherIdsForInstitute('institute1');

        expect(teacherIds, isEmpty);
      });
    });

    group('supervisor assignment', () {
      test('assigns and retrieves supervisor for institute', () async {
        await fakeFirestore.collection('institutes').doc('i1').set({
          'name': 'معهد',
          'location': 'الرياض',
          'created_by': 'admin1',
          'is_active': true,
          'created_at': Timestamp.now(),
        });

        await repository.assignSupervisorToInstitute(
          supervisorId: 'supervisor1',
          instituteId: 'i1',
        );

        final institutes =
            await repository.getInstitutesForSupervisor('supervisor1');
        expect(institutes.length, 1);

        final supervisorIds =
            await repository.getSupervisorIdsForInstitute('i1');
        expect(supervisorIds, contains('supervisor1'));
      });

      test('removes supervisor assignment', () async {
        await fakeFirestore
            .collection('supervisor_institutes')
            .doc('supervisor1_i1')
            .set({
          'supervisor_id': 'supervisor1',
          'institute_id': 'i1',
          'is_active': true,
        });

        await repository.removeSupervisorFromInstitute(
          supervisorId: 'supervisor1',
          instituteId: 'i1',
        );

        final doc = await fakeFirestore
            .collection('supervisor_institutes')
            .doc('supervisor1_i1')
            .get();
        expect(doc.data()?['is_active'], false);
      });
    });
  });
}
