import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/features/settings/providers/telemetry_enabled_provider.dart';

Future<ProviderContainer> _container(
  Map<String, Object> initial,
  TelemetryGate gate,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      telemetryGateProvider.overrideWithValue(gate),
    ],
  );
}

void main() {
  test('telemetry is enabled by default when nothing is stored', () async {
    final container = await _container({}, TelemetryGate(isOpen: true));
    addTearDown(container.dispose);
    expect(container.read(telemetryEnabledProvider), isTrue);
  });

  test('a stored opt-out is honoured on start', () async {
    final container = await _container({
      'telemetry_enabled': false,
    }, TelemetryGate(isOpen: false));
    addTearDown(container.dispose);
    expect(container.read(telemetryEnabledProvider), isFalse);
  });

  test('opting out closes the gate immediately without a restart', () async {
    final gate = TelemetryGate(isOpen: true);
    final container = await _container({}, gate);
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(false);

    expect(container.read(telemetryEnabledProvider), isFalse);
    expect(gate.isOpen, isFalse);
  });

  test('opting back in reopens the gate', () async {
    final gate = TelemetryGate(isOpen: false);
    final container = await _container({'telemetry_enabled': false}, gate);
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(true);

    expect(gate.isOpen, isTrue);
  });
}
