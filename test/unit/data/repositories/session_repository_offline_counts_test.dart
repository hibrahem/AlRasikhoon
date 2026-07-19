import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/repositories/session_repository.dart';
import 'package:al_rasikhoon/data/services/firestore_read_source.dart';

void main() {
  test(
    'count falls back to cached query size when aggregation is unavailable',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('sard_records').add({
        'student_id': 's1',
        'curriculum_session_id': 'c1',
      });
      await firestore.collection('sard_records').add({
        'student_id': 's1',
        'curriculum_session_id': 'c1',
      });
      final repo = SessionRepository(firestore: firestore);
      final query = firestore
          .collection('sard_records')
          .where('student_id', isEqualTo: 's1')
          .where('curriculum_session_id', isEqualTo: 'c1');

      // The offline path: the server-only aggregation throws, the fallback
      // counts the cached result set instead.
      final n = await repo.countWithCacheFallback(
        query,
        primary: () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      expect(n, 2);
    },
  );

  test(
    'sard attempt count still counts normally when aggregation works',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('sard_records').add({
        'student_id': 's1',
        'curriculum_session_id': 'c1',
      });
      await firestore.collection('sard_records').add({
        'student_id': 's1',
        'curriculum_session_id': 'c1',
      });
      await firestore.collection('sard_records').add({
        'student_id': 's1',
        'curriculum_session_id': 'other',
      });
      final repo = SessionRepository(firestore: firestore);
      final n = await repo.getSardAttemptCount(
        studentId: 's1',
        curriculumSessionId: 'c1',
      );
      expect(n, 2);
    },
  );

  test('offline, the count never attempts the server-only aggregation', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('sard_records').add({
      'student_id': 's1',
      'curriculum_session_id': 'c1',
    });
    final repo = SessionRepository(
      firestore: firestore,
      readSource: FirestoreReadSource(isOnline: () => false),
    );
    final query = firestore
        .collection('sard_records')
        .where('student_id', isEqualTo: 's1');

    var primaryCalled = false;
    final n = await repo.countWithCacheFallback(
      query,
      primary: () async {
        primaryCalled = true;
        return 99;
      },
    );

    expect(primaryCalled, isFalse,
        reason: 'aggregations are server-only; offline they can only hang');
    expect(n, 1);
  });
}
