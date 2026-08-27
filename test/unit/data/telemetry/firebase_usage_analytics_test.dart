import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/telemetry/firebase_usage_analytics.dart';

class _FakeSink implements AnalyticsSink {
  final List<({String name, Map<String, Object> parameters})> events = [];
  final Map<String, String?> properties = {};

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    events.add((name: name, parameters: parameters));
  }

  @override
  void setUserProperty(String name, String? value) {
    properties[name] = value;
  }
}

void main() {
  test('a recorded event reaches the sink with bucketed parameters', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    ).record(const SessionAbandoned(step: 'saving'));

    expect(sink.events.single.name, 'session_abandoned');
    expect(sink.events.single.parameters, {'step': 'saving'});
  });

  test('user properties carry role and institute but never a user id', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    ).setUserProperties(role: 'teacher', instituteId: 'inst456');

    expect(sink.properties, {'role': 'teacher', 'institute_id': 'inst456'});
    expect(sink.properties.keys, isNot(contains('user_id')));
  });

  test('signing out clears the role and institute user properties', () {
    final sink = _FakeSink();
    final analytics = FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    )..setUserProperties(role: 'teacher', instituteId: 'inst456');

    analytics.clearUserProperties();

    // Halaqa devices are shared: a null value is how Firebase removes a
    // property, so the next user's events carry neither.
    expect(sink.properties, {'role': null, 'institute_id': null});
  });

  test('clearing user properties is not blocked by a closed gate', () {
    final sink = _FakeSink();
    // The user opted out mid-session, after the properties were already set.
    FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: false),
      sink: sink,
    ).clearUserProperties();

    expect(sink.properties, {'role': null, 'institute_id': null});
  });

  test('a closed gate suppresses every event', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(gate: TelemetryGate(isOpen: false), sink: sink)
      ..record(const TalqeenCompleted())
      ..setUserProperties(role: 'teacher', instituteId: 'i1')
      ..recordScreenView('/students/:id');

    expect(sink.events, isEmpty);
    expect(sink.properties, isEmpty);
  });

  test('a screen view is templated before it reaches the sink', () {
    final sink = _FakeSink();
    FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: sink,
    ).recordScreenView('/students/aB3xY9kL2mN7pQ4rS8tU');

    expect(sink.events.single.parameters['screen_name'], '/students/:id');
  });

  test('a sink failure is swallowed rather than propagated', () {
    final analytics = FirebaseUsageAnalytics(
      gate: TelemetryGate(isOpen: true),
      sink: _ThrowingSink(),
    );
    expect(() => analytics.record(const TalqeenCompleted()), returnsNormally);
  });
}

class _ThrowingSink implements AnalyticsSink {
  @override
  void logEvent(String name, Map<String, Object> parameters) {
    throw Exception('sink is broken');
  }

  @override
  void setUserProperty(String name, String? value) {
    throw Exception('sink is broken');
  }
}
