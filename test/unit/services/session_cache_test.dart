import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:al_rasikhoon/core/constants/app_constants.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/services/session_cache.dart';

UserModel _user({String id = 'u1', UserRole role = UserRole.teacher}) {
  return UserModel(
    id: id,
    username: 'ustadh',
    email: 'u@x.local',
    name: 'الأستاذ',
    role: role,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  late Directory tempDir;
  late Box box;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_cache_test');
    Hive.init(tempDir.path);
    box = await Hive.openBox(AppConstants.boxSession);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('readUser returns null when nothing is cached', () {
    final cache = SessionCache(box);
    expect(cache.readUser(), isNull);
  });

  test('cacheUser then readUser round-trips the user', () async {
    final cache = SessionCache(box);
    await cache.cacheUser(_user(id: 'abc', role: UserRole.supervisor));

    final restored = cache.readUser();
    expect(restored, isNotNull);
    expect(restored!.id, 'abc');
    expect(restored.role, UserRole.supervisor);
  });

  test('clear removes the cached user', () async {
    final cache = SessionCache(box);
    await cache.cacheUser(_user());
    await cache.clear();
    expect(cache.readUser(), isNull);
  });

  test('readUser returns null on corrupt cached data', () async {
    await box.put(AppConstants.keyCachedUser, 'not-json');
    final cache = SessionCache(box);
    expect(cache.readUser(), isNull);
  });
}
