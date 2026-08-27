import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_gate.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_runtime.dart';
import 'package:al_rasikhoon/data/services/shared_preferences_provider.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/features/settings/providers/telemetry_enabled_provider.dart';

/// Stands in for the vendor SDKs' collection switches.
class _RecordingRuntime implements TelemetryRuntime {
  final List<bool> calls = [];

  @override
  Future<void> setEnabled(bool enabled) async => calls.add(enabled);
}

Future<ProviderContainer> _container(
  Map<String, Object> initial,
  TelemetryGate gate, {
  TelemetryRuntime? runtime,
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      telemetryGateProvider.overrideWithValue(gate),
      if (runtime != null) telemetryRuntimeProvider.overrideWithValue(runtime),
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

  test('opting out also switches the native sdks off', () async {
    final runtime = _RecordingRuntime();
    final container = await _container(
      {},
      TelemetryGate(isOpen: true),
      runtime: runtime,
    );
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(false);
    await Future<void>.delayed(Duration.zero);

    // The gate alone would leave Firebase Analytics auto-collection and
    // Sentry's native crash/session handlers running.
    expect(runtime.calls, [false]);
  });

  test('opting back in switches the native sdks on again', () async {
    final runtime = _RecordingRuntime();
    final container = await _container(
      {'telemetry_enabled': false},
      TelemetryGate(isOpen: false),
      runtime: runtime,
    );
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(true);
    await Future<void>.delayed(Duration.zero);

    expect(runtime.calls, [true]);
  });

  test('opting back in reopens the gate', () async {
    final gate = TelemetryGate(isOpen: false);
    final container = await _container({'telemetry_enabled': false}, gate);
    addTearDown(container.dispose);

    container.read(telemetryEnabledProvider.notifier).setEnabled(true);

    expect(gate.isOpen, isTrue);
  });
}
