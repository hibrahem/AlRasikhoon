import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/telemetry/telemetry_gate.dart';
import '../../../data/services/shared_preferences_provider.dart';
import '../../../data/services/telemetry/telemetry_providers.dart';

final telemetryEnabledProvider =
    NotifierProvider<TelemetryEnabledNotifier, bool>(
      TelemetryEnabledNotifier.new,
    );

/// The user's choice about diagnostics, persisted and applied immediately.
///
/// The same key is read in `main()` before `runApp`, so the choice is already
/// in force for the very first frame; flipping it here moves the shared
/// [TelemetryGate] so no restart is needed.
class TelemetryEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(kTelemetryEnabledKey) ??
        true;
  }

  void setEnabled(bool value) {
    ref.read(sharedPreferencesProvider).setBool(kTelemetryEnabledKey, value);
    final gate = ref.read(telemetryGateProvider);
    value ? gate.open() : gate.close();
    state = value;
  }
}
