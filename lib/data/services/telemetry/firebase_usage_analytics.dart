import 'package:firebase_analytics/firebase_analytics.dart';

import '../../../core/telemetry/analytics_event.dart';
import '../../../core/telemetry/pii_scrubber.dart';
import '../../../core/telemetry/telemetry_gate.dart';
import '../../../core/telemetry/usage_analytics.dart';

/// The seam between this adapter and the Firebase SDK, so the privacy rules
/// are testable without a Firebase app.
abstract interface class AnalyticsSink {
  void logEvent(String name, Map<String, Object> parameters);

  /// A `null` [value] removes the property, which is how Firebase Analytics
  /// clears one.
  void setUserProperty(String name, String? value);
}

class LiveAnalyticsSink implements AnalyticsSink {
  const LiveAnalyticsSink();

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  @override
  void setUserProperty(String name, String? value) {
    FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
  }
}

/// Records aggregate product usage.
///
/// Deliberately never calls `setUserId`. Aggregate data answers "where do
/// teachers get stuck" without building a per-child behavioural profile — see
/// the design spec's privacy section.
class FirebaseUsageAnalytics implements UsageAnalytics {
  const FirebaseUsageAnalytics({
    required TelemetryGate gate,
    required AnalyticsSink sink,
  }) : _gate = gate,
       _sink = sink;

  final TelemetryGate _gate;
  final AnalyticsSink _sink;

  @override
  void record(AnalyticsEvent event) {
    if (!_gate.isOpen) return;
    try {
      _sink.logEvent(event.name, event.parameters);
    } catch (_) {}
  }

  @override
  void setUserProperties({required String role, required String instituteId}) {
    if (!_gate.isOpen) return;
    try {
      _sink.setUserProperty('role', role);
      _sink.setUserProperty('institute_id', instituteId);
    } catch (_) {}
  }

  @override
  void clearUserProperties() {
    // Deliberately NOT gated: clearing is always the privacy-preserving move,
    // and a user who opted out mid-session still has properties set from
    // before the opt-out that must go on sign-out.
    try {
      _sink.setUserProperty('role', null);
      _sink.setUserProperty('institute_id', null);
    } catch (_) {}
  }

  @override
  void recordScreenView(String templatedRoute) {
    if (!_gate.isOpen) return;
    try {
      _sink.logEvent('screen_view', {
        'screen_name': templateRoute(templatedRoute),
      });
    } catch (_) {}
  }
}
