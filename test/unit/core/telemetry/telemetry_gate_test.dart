import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';

void main() {
  test('a gate opens by default when telemetry is permitted', () {
    expect(TelemetryGate(isOpen: true).isOpen, isTrue);
  });

  test('a closed gate stays closed until explicitly opened', () {
    final gate = TelemetryGate(isOpen: false);
    expect(gate.isOpen, isFalse);
    gate.open();
    expect(gate.isOpen, isTrue);
    gate.close();
    expect(gate.isOpen, isFalse);
  });

  test('the telemetry opt-out preference key is pinned so a rename cannot '
      'silently orphan existing users\' opt-outs', () {
    expect(kTelemetryEnabledKey, 'telemetry_enabled');
  });
}
