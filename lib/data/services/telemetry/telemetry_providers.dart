import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/firebase_emulator_config.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/telemetry_runtime.dart';
import '../../../core/telemetry/usage_analytics.dart';
import 'firebase_usage_analytics.dart';
import 'noop_telemetry.dart';
import 'platform_telemetry_runtime.dart';
import 'sentry_error_reporter.dart';

/// Supplied at build time: `--dart-define=SENTRY_DSN=...`. Empty by default so
/// local runs and CI (which have no secret) fall back to the no-op adapter.
const String kSentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Pure predicate so the four disable conditions are directly testable.
bool telemetryIsPermitted({
  required bool isDebug,
  required bool isEmulator,
  required String dsn,
}) {
  if (isDebug) return false;
  if (isEmulator) return false;
  if (dsn.isEmpty) return false;
  return true;
}

/// Builds the object that owns the vendor SDKs' collection switches.
///
/// Always a live runtime on a real device, even when telemetry is not
/// permitted: Firebase Analytics auto-collection has to be switched OFF in
/// exactly those builds, and only a live sink can do that.
TelemetryRuntime createTelemetryRuntime({
  required TelemetryGate gate,
  required String dsn,
}) {
  return PlatformTelemetryRuntime(
    sink: LiveTelemetryPlatformSink(dsn: dsn, gate: gate),
    permitted: telemetryIsPermitted(
      isDebug: kDebugMode,
      isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
      dsn: dsn,
    ),
  );
}

/// Returns the live reporter, or the no-op reporter when telemetry is not
/// permitted.
///
/// Deliberately does NOT initialise Sentry — [TelemetryRuntime] owns that, so
/// that an opted-out user never has the SDK started in the first place. The
/// reporter is safe to hold either way: it checks the gate before emitting,
/// and its sink is a no-op while the SDK is down.
ErrorReporter createErrorReporter({
  required TelemetryGate gate,
  required String dsn,
}) {
  final permitted = telemetryIsPermitted(
    isDebug: kDebugMode,
    isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
    dsn: dsn,
  );
  if (!permitted) return const NoopErrorReporter();
  return SentryErrorReporter(gate: gate, sink: const LiveSentrySink());
}

/// Overridden in `main()` with the instance created before `runApp`. Defaults
/// to the no-op adapter — the same fallback `createErrorReporter` itself
/// returns on every degraded path — so code that reads this provider without
/// an override (a widget-test harness with no Firebase) degrades safely
/// instead of taking the app down with it.
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => const NoopErrorReporter(),
);

/// Analytics has no separate initialisation and no DSN; it rides the same
/// permission predicate as the error reporter.
UsageAnalytics createUsageAnalytics({
  required TelemetryGate gate,
  required String dsn,
}) {
  final permitted = telemetryIsPermitted(
    isDebug: kDebugMode,
    isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
    dsn: dsn,
  );
  if (!permitted) return const NoopUsageAnalytics();
  return FirebaseUsageAnalytics(gate: gate, sink: const LiveAnalyticsSink());
}

/// Overridden in `main()` with the instance created before `runApp`. Defaults
/// to the no-op adapter — the same fallback `createUsageAnalytics` itself
/// returns on every degraded path — so code that reads this provider without
/// an override (a widget-test harness with no Firebase) degrades safely
/// instead of taking the app down with it.
final usageAnalyticsProvider = Provider<UsageAnalytics>(
  (ref) => const NoopUsageAnalytics(),
);

/// Overridden in `main()` with the instance created before `runApp`. Defaults
/// to the no-op runtime so a test container never reaches for a Firebase app
/// or a Sentry SDK that isn't there.
final telemetryRuntimeProvider = Provider<TelemetryRuntime>(
  (ref) => const NoopTelemetryRuntime(),
);

/// Overridden in `main()` with the single shared gate. Defaults CLOSED: an
/// unoverridden gate must never permit telemetry to leave the device.
final telemetryGateProvider = Provider<TelemetryGate>(
  (ref) => TelemetryGate(isOpen: false),
);
