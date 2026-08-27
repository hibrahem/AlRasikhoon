import '../../../core/telemetry/analytics_event.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_context.dart';
import '../../../core/telemetry/usage_analytics.dart';

/// Selected in debug builds, in emulator mode, when no Sentry DSN is
/// configured, and in every test.
///
/// Nothing leaves the device in those builds — but that is only true because
/// [PlatformTelemetryRuntime] also forces Firebase Analytics' native
/// auto-collection off and never initialises Sentry when telemetry is not
/// permitted. Picking this adapter alone would not have been enough: native
/// collection does not route through any adapter.
class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

class NoopUsageAnalytics implements UsageAnalytics {
  const NoopUsageAnalytics();

  @override
  void record(AnalyticsEvent event) {}

  @override
  void setUserProperties({required String role, required String instituteId}) {}

  @override
  void recordScreenView(String templatedRoute) {}
}
