import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

/// Local, synchronous cache of the signed-in user's profile.
///
/// Backed by an already-open Hive box so [readUser] can run synchronously
/// during app boot (before the first frame). This is what lets the router
/// route a returning user optimistically, without waiting on Firestore.
class SessionCache {
  final Box _box;

  SessionCache(this._box);

  /// The cached user, or null if none is stored or the data is unreadable.
  UserModel? readUser() {
    final raw = _box.get(AppConstants.keyCachedUser);
    if (raw is! String) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUser(UserModel user) async {
    await _box.put(AppConstants.keyCachedUser, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _box.delete(AppConstants.keyCachedUser);
  }
}

/// Overridden in `main()` with the box opened before `runApp`.
final sessionBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError('session box not opened');
});

final sessionCacheProvider = Provider<SessionCache>((ref) {
  return SessionCache(ref.watch(sessionBoxProvider));
});
