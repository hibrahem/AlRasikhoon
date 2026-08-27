import '../../../core/telemetry/analytics_event.dart';
import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/telemetry_context.dart';
import '../../../core/telemetry/usage_analytics.dart';

/// Selected in debug builds, in emulator mode, when no Sentry DSN is
/// configured, and in every test. Nothing leaves the device.
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
