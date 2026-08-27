import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/config/firebase_emulator_config.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/usage_analytics.dart';
import 'noop_telemetry.dart';
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

/// Initialises Sentry and returns the live reporter, or returns the no-op
/// reporter when telemetry is not permitted. Never throws: an initialisation
/// failure degrades to no-op rather than blocking startup.
Future<ErrorReporter> createErrorReporter({
  required TelemetryGate gate,
  required String dsn,
}) async {
  final permitted = telemetryIsPermitted(
    isDebug: kDebugMode,
    isEmulator: FirebaseEmulatorConfig.isEmulatorMode,
    dsn: dsn,
  );
  if (!permitted) return const NoopErrorReporter();

  try {
    await SentryFlutter.init((options) {
      options.dsn = dsn;
      // Student names appear on screen in nearly every view.
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      options.sendDefaultPii = false;
      // A closed gate must suppress SDK-captured native events too, not just
      // the ones this app reports explicitly.
      options.beforeSend = (event, hint) => gate.isOpen ? event : null;
    });
    return SentryErrorReporter(gate: gate, sink: const LiveSentrySink());
  } catch (_) {
    return const NoopErrorReporter();
  }
}

/// Overridden in `main()` with the instance created before `runApp`.
final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => throw UnimplementedError('errorReporterProvider must be overridden'),
);

/// Overridden in `main()`. Replaced with the live adapter in Task 11.
final usageAnalyticsProvider = Provider<UsageAnalytics>(
  (ref) => const NoopUsageAnalytics(),
);

/// Overridden in `main()` with the single shared gate.
final telemetryGateProvider = Provider<TelemetryGate>(
  (ref) => throw UnimplementedError('telemetryGateProvider must be overridden'),
);
