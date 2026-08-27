import 'telemetry_context.dart';

/// Reports failures to whatever error backend is configured.
///
/// Every implementation MUST be non-throwing: telemetry is never allowed to
/// become a source of failure, so internal exceptions are caught and dropped.
abstract interface class ErrorReporter {
  /// Records a failure. [reason] is a short, non-identifying description such
  /// as `provider studentStatsProvider failed`.
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  /// Adds a trail entry attached to subsequent reports.
  void addBreadcrumb(String message, {String? category});

  /// Replaces the context attached to subsequent reports.
  void updateContext(TelemetryContext context);
}
