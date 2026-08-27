import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/telemetry/sentry_error_reporter.dart';

class _FakeSink implements SentrySink {
  final List<String> captured = [];
  final List<String> breadcrumbs = [];
  Map<String, String> lastTags = const {};
  String? lastUserId;

  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  ) {
    captured.add('$error|$reason');
    lastTags = tags;
    lastUserId = userId;
  }

  @override
  void breadcrumb(String message, String? category) {
    breadcrumbs.add(message);
  }
}

void main() {
  test('a report never forwards a student synthetic email to the sink', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.recordError(
      Exception('no user for ahmad.ali@alrasikhoon.local'),
      StackTrace.current,
      reason: 'login failed for ahmad.ali@alrasikhoon.local',
    );

    expect(sink.captured.single, isNot(contains('ahmad.ali')));
    expect(sink.captured.single, contains('<redacted>'));
  });

  test('a report never forwards a raw document id to the sink', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.recordError(
      Exception('PERMISSION_DENIED on students/aB3xY9kL2mN7pQ4rS8tU'),
      null,
    );

    expect(sink.captured.single, isNot(contains('aB3xY9kL2mN7pQ4rS8tU')));
    expect(sink.captured.single, contains('students/:id'));
  });

  test('a closed gate suppresses every report and breadcrumb', () {
    final sink = _FakeSink();
    final gate = TelemetryGate(isOpen: false);
    final reporter = SentryErrorReporter(gate: gate, sink: sink);

    reporter.recordError(Exception('boom'), null);
    reporter.addBreadcrumb('opened screen');

    expect(sink.captured, isEmpty);
    expect(sink.breadcrumbs, isEmpty);

    gate.open();
    reporter.recordError(Exception('boom'), null);
    expect(sink.captured, hasLength(1));
  });

  test('context is forwarded as tags with the uid kept out of them', () {
    final sink = _FakeSink();
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    );

    reporter.updateContext(
      const TelemetryContext(
        userId: 'uid123',
        role: 'teacher',
        instituteId: 'inst456',
        route: '/students/:id',
        connectivity: 'offline',
      ),
    );
    reporter.recordError(Exception('boom'), null);

    expect(sink.lastTags['role'], 'teacher');
    expect(sink.lastTags['connectivity'], 'offline');
    expect(sink.lastTags.values, isNot(contains('uid123')));
    expect(sink.lastUserId, 'uid123');
  });

  test('a sink failure is swallowed rather than propagated', () {
    final reporter = SentryErrorReporter(
      gate: TelemetryGate(isOpen: true),
      sink: _ThrowingSink(),
    );
    expect(
      () => reporter.recordError(Exception('boom'), null),
      returnsNormally,
    );
    expect(() => reporter.addBreadcrumb('x'), returnsNormally);
  });
}

class _ThrowingSink implements SentrySink {
  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
  ) {
    throw Exception('sink is broken');
  }

  @override
  void breadcrumb(String message, String? category) {
    throw Exception('sink is broken');
  }
}
