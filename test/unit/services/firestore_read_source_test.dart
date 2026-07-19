import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/services/firestore_read_source.dart';

void main() {
  test('online reads use Firestore defaults (server first)', () {
    final read = FirestoreReadSource(isOnline: () => true);
    expect(read.isOnline, isTrue);
    expect(read.optionsOrNull, isNull);
  });

  test('offline reads are pinned to the local cache', () {
    final read = FirestoreReadSource(isOnline: () => false);
    expect(read.isOnline, isFalse);
    expect(read.optionsOrNull?.source, Source.cache);
  });

  test('the decision is looked up per read, not frozen at construction', () {
    var online = true;
    final read = FirestoreReadSource(isOnline: () => online);
    expect(read.optionsOrNull, isNull);
    online = false;
    expect(read.optionsOrNull?.source, Source.cache);
  });

  test('query and doc reads still resolve through the helper', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('c').doc('d').set({'x': 1});
    for (final online in [true, false]) {
      final read = FirestoreReadSource(isOnline: () => online);
      final query = await read.getQuery(
        firestore.collection('c').where('x', isEqualTo: 1),
      );
      expect(query.docs, hasLength(1));
      final doc = await read.getDoc(firestore.collection('c').doc('d'));
      expect(doc.exists, isTrue);
    }
  });
}
