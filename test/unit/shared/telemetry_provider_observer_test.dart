import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/shared/providers/telemetry_provider_observer.dart';

class _RecordingReporter implements ErrorReporter {
  final List<({Object error, String? reason})> recorded = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    recorded.add((error: error, reason: reason));
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}

final throwingProvider = Provider<int>(
  (ref) => throw StateError('halaqa unreachable'),
  name: 'throwingProvider',
);

void main() {
  test('a failing provider is reported to the error reporter', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(reporter)],
    );
    addTearDown(container.dispose);

    // Riverpod 3.1.0's ProviderContainer.read wraps the provider's original
    // error in a ProviderException before rethrowing it to the caller, so
    // this asserts on the wrapper. The reporter assertions below are what
    // actually verify the observer receives the raw StateError.
    expect(() => container.read(throwingProvider), throwsException);

    expect(reporter.recorded, hasLength(1));
    expect(reporter.recorded.single.error, isA<StateError>());
    expect(reporter.recorded.single.reason, contains('throwingProvider'));
  });

  test('a succeeding provider reports nothing', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(reporter)],
    );
    addTearDown(container.dispose);

    final ok = Provider<int>((ref) => 7, name: 'okProvider');
    expect(container.read(ok), 7);
    expect(reporter.recorded, isEmpty);
  });

  test('a reporter that throws does not break the provider container', () {
    final container = ProviderContainer(
      observers: [TelemetryProviderObserver(_ThrowingReporter())],
    );
    addTearDown(container.dispose);

    expect(() => container.read(throwingProvider), throwsException);
  });
}

class _ThrowingReporter implements ErrorReporter {
  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    throw Exception('reporter is broken');
  }

  @override
  void addBreadcrumb(String message, {String? category}) {}

  @override
  void updateContext(TelemetryContext context) {}
}
