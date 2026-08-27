import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/main.dart';

class _RecordingReporter implements ErrorReporter {
  final List<({Object error, String? reason, bool fatal})> reports = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    reports.add((error: error, reason: reason, fatal: fatal));
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

/// Swaps [FlutterError.presentError] for a recorder, so "did the developer see
/// this in the console?" becomes an assertion instead of a manual check.
List<FlutterErrorDetails> _capturePresentedErrors() {
  final presented = <FlutterErrorDetails>[];
  final original = FlutterError.presentError;
  FlutterError.presentError = presented.add;
  addTearDown(() => FlutterError.presentError = original);
  return presented;
}

void main() {
  final error = StateError('async boom');
  final stack = StackTrace.current;

  test('a debug build still prints an uncaught async error to the console', () {
    final presented = _capturePresentedErrors();
    final reporter = _RecordingReporter();

    handleUncaughtZoneError(
      error,
      stack,
      reporter: reporter,
      isDebug: true,
      onReporterMissing: (_, _) => fail('reporter was available'),
    );

    // In debug the reporter is the no-op adapter, so the console dump is the
    // ONLY thing a developer sees. The guarded zone takes precedence over
    // PlatformDispatcher.onError, whose `return !kDebugMode` carve-out can no
    // longer run for in-zone errors — this is that carve-out, restored.
    expect(presented, hasLength(1));
    expect(presented.single.exception, same(error));
    expect(presented.single.stack, same(stack));
  });

  test('a release build reports without printing anything', () {
    final presented = _capturePresentedErrors();
    final reporter = _RecordingReporter();

    handleUncaughtZoneError(
      error,
      stack,
      reporter: reporter,
      isDebug: false,
      onReporterMissing: (_, _) => fail('reporter was available'),
    );

    expect(reporter.reports.single.fatal, isTrue);
    expect(reporter.reports.single.reason, 'uncaught zone error');
    // There is no console in a release build to print to.
    expect(presented, isEmpty);
  });

  test('the error is reported whether or not the build is a debug one', () {
    _capturePresentedErrors();
    final debugReporter = _RecordingReporter();
    final releaseReporter = _RecordingReporter();

    handleUncaughtZoneError(
      error,
      stack,
      reporter: debugReporter,
      isDebug: true,
      onReporterMissing: (_, _) => fail('reporter was available'),
    );
    handleUncaughtZoneError(
      error,
      stack,
      reporter: releaseReporter,
      isDebug: false,
      onReporterMissing: (_, _) => fail('reporter was available'),
    );

    expect(debugReporter.reports.single.fatal, isTrue);
    expect(releaseReporter.reports.single.fatal, isTrue);
  });

  test(
    'a failure before the reporter exists falls back to the startup path',
    () {
      _capturePresentedErrors();
      final fallbackCalls = <Object>[];

      handleUncaughtZoneError(
        error,
        stack,
        reporter: null,
        isDebug: false,
        onReporterMissing: (e, _) => fallbackCalls.add(e),
      );

      expect(fallbackCalls, [same(error)]);
    },
  );
}
