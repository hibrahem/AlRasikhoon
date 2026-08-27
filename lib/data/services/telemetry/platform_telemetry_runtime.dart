import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/telemetry_runtime.dart';

/// The seam between the runtime's rules and the two vendor SDKs, so the rules
/// are testable without a Firebase app, a DSN, or a network.
abstract interface class TelemetryPlatformSink {
  /// Turns Firebase Analytics' NATIVE auto-collection on or off. This is the
  /// only switch that reaches `first_open`, `session_start`, screen views and
  /// the app instance id — none of which pass through our adapter.
  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  /// Initialises the Sentry SDK. Not called at all while telemetry is off, so
  /// no native crash handler and no release-health session is ever installed
  /// for an opted-out user.
  Future<void> startErrorReporting();

  /// Shuts the Sentry SDK down, native layer included.
  Future<void> stopErrorReporting();
}

class LiveTelemetryPlatformSink implements TelemetryPlatformSink {
  const LiveTelemetryPlatformSink({required this.dsn, required this.gate});

  final String dsn;
  final TelemetryGate gate;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) {
    return FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> startErrorReporting() {
    // Halaqas frequently have no connectivity. SentryFlutter.init reaches out
    // to the network, so an unbounded await here could hang startup forever;
    // a timeout guarantees the app still launches, degraded to no-op.
    return SentryFlutter.init((options) {
      options.dsn = dsn;
      // Student names appear on screen in nearly every view.
      options.attachScreenshot = false;
      options.attachViewHierarchy = false;
      options.sendDefaultPii = false;
      // Second line of defence only. The SDK is not running at all while the
      // user is opted out, and this filter reaches Dart events exclusively —
      // it is not what makes the opt-out honest.
      options.beforeSend = (event, hint) => gate.isOpen ? event : null;
    }).timeout(const Duration(seconds: 5));
  }

  @override
  Future<void> stopErrorReporting() => Sentry.close();
}

/// Keeps the vendor SDKs in step with the effective telemetry state.
///
/// "Effective" folds in [permitted]: in a debug build, under the emulator, or
/// with no DSN configured, collection is forced off no matter what the user's
/// preference says. That is what makes `noop_telemetry.dart`'s "nothing leaves
/// the device" comment true for those builds.
class PlatformTelemetryRuntime implements TelemetryRuntime {
  PlatformTelemetryRuntime({
    required TelemetryPlatformSink sink,
    required bool permitted,
  }) : _sink = sink,
       _permitted = permitted;

  final TelemetryPlatformSink _sink;
  final bool _permitted;

  bool _errorReportingStarted = false;

  /// Whether the Sentry SDK is currently running. Exposed for tests.
  bool get isErrorReportingStarted => _errorReportingStarted;

  @override
  Future<void> setEnabled(bool enabled) async {
    final effective = _permitted && enabled;

    // Analytics first and unconditionally: it is the layer that starts
    // collecting by itself at launch, so it must be switched even when
    // telemetry is not permitted and no analytics adapter was ever built.
    try {
      await _sink.setAnalyticsCollectionEnabled(effective);
    } catch (_) {
      // Telemetry is never allowed to become a source of failure.
    }

    if (effective == _errorReportingStarted) return;

    try {
      if (effective) {
        await _sink.startErrorReporting();
      } else {
        await _sink.stopErrorReporting();
      }
      _errorReportingStarted = effective;
    } catch (_) {
      // A failed start leaves the SDK down, which is the safe direction: the
      // Dart reporter's own gate check still holds and nothing is sent.
    }
  }
}
