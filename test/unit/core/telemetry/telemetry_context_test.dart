import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';

void main() {
  test('empty context carries no identifying values', () {
    expect(TelemetryContext.empty.userId, isNull);
    expect(TelemetryContext.empty.role, isNull);
    expect(TelemetryContext.empty.toTags(), isEmpty);
  });

  test('context carries role institute and connectivity as tags', () {
    const context = TelemetryContext(
      userId: 'uid123',
      role: 'teacher',
      instituteId: 'inst456',
      route: '/students/:id',
      connectivity: 'offline',
    );

    expect(context.toTags(), {
      'role': 'teacher',
      'institute_id': 'inst456',
      'route': '/students/:id',
      'connectivity': 'offline',
    });
  });

  test('user id is not exposed as a tag', () {
    const context = TelemetryContext(userId: 'uid123');
    expect(context.toTags().values, isNot(contains('uid123')));
  });

  test('route is templated when the context is built', () {
    final context = TelemetryContext.empty.copyWith(
      route: '/students/aB3xY9kL2mN7pQ4rS8tU',
    );
    expect(context.route, '/students/:id');
  });

  test('copyWith preserves untouched fields', () {
    const original = TelemetryContext(userId: 'uid123', role: 'teacher');
    final updated = original.copyWith(connectivity: 'online');
    expect(updated.userId, 'uid123');
    expect(updated.role, 'teacher');
    expect(updated.connectivity, 'online');
  });
}
