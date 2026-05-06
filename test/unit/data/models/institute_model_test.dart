import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/institute_model.dart';

void main() {
  group('InstituteModel', () {
    test('institute is active by default', () {
      final inst = InstituteModel(
        id: 'i1',
        name: 'معهد تجريبي',
        location: 'الرياض',
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(inst.isActive, isTrue);
    });

    test('copyWith with isActive=false models a soft delete', () {
      final inst = InstituteModel(
        id: 'i1',
        name: 'معهد تجريبي',
        location: 'الرياض',
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );

      final softDeleted = inst.copyWith(isActive: false);

      expect(softDeleted.isActive, isFalse);
      expect(softDeleted.id, inst.id);
      expect(softDeleted.name, inst.name);
    });

    test('copyWith updates a single field and leaves others unchanged', () {
      final inst = InstituteModel(
        id: 'i1',
        name: 'old name',
        location: 'الرياض',
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );

      final renamed = inst.copyWith(name: 'new name');

      expect(renamed.name, 'new name');
      expect(renamed.location, inst.location);
      expect(renamed.createdBy, inst.createdBy);
      expect(renamed.createdAt, inst.createdAt);
      expect(renamed.isActive, inst.isActive);
    });

    test('equality based on id only, not other fields', () {
      final a = InstituteModel(
        id: 'same',
        name: 'A',
        location: 'X',
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );
      final b = InstituteModel(
        id: 'same',
        name: 'B',
        location: 'Y',
        createdBy: 'other',
        createdAt: DateTime(2026, 2, 2),
      );
      final c = InstituteModel(
        id: 'different',
        name: 'A',
        location: 'X',
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('toFirestore + fromFirestore round-trip preserves fields', () async {
      final original = InstituteModel(
        id: 'i1',
        name: 'معهد الرياض',
        location: 'الرياض',
        createdBy: 'admin_1',
        createdAt: DateTime.utc(2026, 1, 15, 10, 30),
        updatedAt: DateTime.utc(2026, 2, 1, 12),
        isActive: true,
      );

      final fake = FakeFirebaseFirestore();
      await fake
          .collection('institutes')
          .doc(original.id)
          .set(original.toFirestore());
      final DocumentSnapshot doc = await fake
          .collection('institutes')
          .doc(original.id)
          .get();

      final round = InstituteModel.fromFirestore(doc);

      expect(round.id, original.id);
      expect(round.name, original.name);
      expect(round.location, original.location);
      expect(round.createdBy, original.createdBy);
      // Timestamp.fromDate / toDate preserves the instant but normalizes the
      // DateTime to local time, so equality on the DateTime objects fails
      // across UTC offsets — compare the instants instead.
      expect(round.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
      expect(round.updatedAt!.isAtSameMomentAs(original.updatedAt!), isTrue);
      expect(round.isActive, original.isActive);
    });

    test('fromFirestore tolerates missing optional fields', () async {
      final fake = FakeFirebaseFirestore();
      await fake.collection('institutes').doc('i_partial').set({
        'name': 'Partial',
        'location': 'Riyadh',
        'created_by': 'admin',
        'created_at': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      final DocumentSnapshot doc = await fake
          .collection('institutes')
          .doc('i_partial')
          .get();

      final inst = InstituteModel.fromFirestore(doc);

      expect(inst.updatedAt, isNull);
      expect(inst.isActive, isTrue);
    });
  });
}
