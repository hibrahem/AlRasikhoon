import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/telemetry/error_reporter.dart';
import '../../../core/telemetry/pii_scrubber.dart';
import '../../../core/telemetry/telemetry_context.dart';
import '../../../core/telemetry/telemetry_gate.dart';

/// The seam between the adapter's logic and the Sentry SDK, so the PII rules
/// can be tested without a DSN or a network.
abstract interface class SentrySink {
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
    bool fatal,
  );
  void breadcrumb(String message, String? category);
}

class LiveSentrySink implements SentrySink {
  const LiveSentrySink();

  @override
  void captureException(
    Object error,
    StackTrace? stackTrace,
    String? reason,
    Map<String, String> tags,
    String? userId,
    bool fatal,
  ) {
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (userId != null) {
          scope.setUser(SentryUser(id: userId));
        }
        for (final entry in tags.entries) {
          scope.setTag(entry.key, entry.value);
        }
        if (reason != null) {
          scope.setContexts('reason', reason);
        }
      },
    );
  }

  @override
  void breadcrumb(String message, String? category) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, category: category));
  }
}

/// Reports errors to Sentry, scrubbing every string on the way out and
/// honouring the [TelemetryGate].
class SentryErrorReporter implements ErrorReporter {
  SentryErrorReporter({required TelemetryGate gate, required SentrySink sink})
    : _gate = gate,
      _sink = sink;

  final TelemetryGate _gate;
  final SentrySink _sink;

  TelemetryContext _context = TelemetryContext.empty;

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_gate.isOpen) return;
    try {
      // The error object itself is stringified and scrubbed rather than passed
      // through: a FirebaseException's message routinely embeds document paths,
      // and UserModel.toString() embeds a username and a name.
      final scrubbed = scrubMessage(error.toString());
      final scrubbedReason = reason == null ? null : scrubMessage(reason);
      _sink.captureException(
        _ScrubbedError(scrubbed),
        stackTrace,
        scrubbedReason,
        _context.toTags(),
        _context.userId,
        fatal,
      );
    } catch (_) {}
  }

  @override
  void addBreadcrumb(String message, {String? category}) {
    if (!_gate.isOpen) return;
    try {
      _sink.breadcrumb(scrubMessage(message), category);
    } catch (_) {}
  }

  @override
  void updateContext(TelemetryContext context) {
    _context = context;
  }
}

/// Carries an already-scrubbed message to Sentry. Its `toString()` is what
/// Sentry renders, so nothing unscrubbed can reach the console through it.
class _ScrubbedError implements Exception {
  _ScrubbedError(this.message);
  final String message;

  @override
  String toString() => message;
}
