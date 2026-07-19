import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/connectivity_provider.dart';

/// Decides where repository reads resolve from, per read, based on live
/// connectivity (al_rasikhoon-gy4).
///
/// Firestore's default read behaviour (`Source.serverAndCache`) tries the
/// backend FIRST and serves the cache only after that attempt fails. With no
/// connectivity, "fails" is not instant — the SDK waits to conclude it is
/// offline, and flows that chain many sequential reads (the supervisor's
/// students list walks institutes → students → one user doc per student) pay
/// that wait once per read, turning an instant cache load into minutes.
///
/// Offline, reads are therefore pinned to [Source.cache]: served from disk
/// with zero network wait. Online, Firestore's default stands — this class
/// must never make ONLINE reads staler than they are today.
class FirestoreReadSource {
  final bool Function() _isOnline;

  const FirestoreReadSource({required bool Function() isOnline})
    : _isOnline = isOnline;

  /// The no-op policy: every read uses Firestore's default behaviour. The
  /// constructor default for repositories, so tests and callers that never
  /// think about connectivity keep today's semantics.
  const FirestoreReadSource.alwaysOnline() : _isOnline = _online;

  static bool _online() => true;

  /// Looked up per call — connectivity changes take effect on the very next
  /// read, with no rebuild of the repositories.
  bool get isOnline => _isOnline();

  /// The options for a read issued NOW: null means "use Firestore's
  /// default"; offline it pins the read to the local cache.
  GetOptions? get optionsOrNull =>
      isOnline ? null : const GetOptions(source: Source.cache);

  /// Runs [query] against the source [optionsOrNull] resolves to. A
  /// cache-pinned query never throws for lack of data — Firestore evaluates
  /// it over whatever documents the cache holds — so an empty result IS the
  /// honest offline answer.
  Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query,
  ) {
    final options = optionsOrNull;
    return options == null ? query.get() : query.get(options);
  }

  /// Reads [ref] from the source [optionsOrNull] resolves to. Unlike a
  /// query, a cache-pinned DOCUMENT read throws when the document is not
  /// cached — that one case falls back to the default (server-first) read,
  /// so a cold cache degrades to today's behaviour instead of a hard error.
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final options = optionsOrNull;
    if (options == null) return ref.get();
    try {
      return await ref.get(options);
    } on FirebaseException {
      return ref.get();
    }
  }
}

final firestoreReadSourceProvider = Provider<FirestoreReadSource>((ref) {
  // A PERSISTENT subscription, not a per-read `ref.read`: reads happen on
  // hot paths, and a standing listener also means a connectivity-stream
  // error (no plugin in a unit-test harness) is delivered to a live listener
  // chain — handled state, never an unhandled zone error.
  //
  // Connectivity UNKNOWN means "online": the default read behaviour is the
  // safe one, and only a positively-offline signal justifies pinning reads
  // to the cache.
  var online = true;
  ref.listen(
    isConnectedProvider,
    (_, next) => online = next,
    fireImmediately: true,
  );
  return FirestoreReadSource(isOnline: () => online);
});
