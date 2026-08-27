import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/services/telemetry/platform_telemetry_runtime.dart';

class _FakeSink implements TelemetryPlatformSink {
  final List<bool> analyticsCalls = [];
  int starts = 0;
  int stops = 0;
  bool startThrows = false;

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    analyticsCalls.add(enabled);
  }

  @override
  Future<void> startErrorReporting() async {
    if (startThrows) throw StateError('no network');
    starts++;
  }

  @override
  Future<void> stopErrorReporting() async {
    stops++;
  }
}

PlatformTelemetryRuntime _runtime(_FakeSink sink, {bool permitted = true}) {
  return PlatformTelemetryRuntime(sink: sink, permitted: permitted);
}

void main() {
  test(
    'an opted-in user gets analytics collection and Sentry started',
    () async {
      final sink = _FakeSink();

      await _runtime(sink).setEnabled(true);

      expect(sink.analyticsCalls, [true]);
      expect(sink.starts, 1);
      expect(sink.stops, 0);
    },
  );

  test(
    'opting out switches analytics collection off and closes Sentry',
    () async {
      final sink = _FakeSink();
      final runtime = _runtime(sink);
      await runtime.setEnabled(true);

      await runtime.setEnabled(false);

      expect(sink.analyticsCalls, [true, false]);
      expect(sink.stops, 1);
      expect(runtime.isErrorReportingStarted, isFalse);
    },
  );

  test('an opted-out user never has Sentry initialised at all', () async {
    final sink = _FakeSink();

    await _runtime(sink).setEnabled(false);

    expect(sink.starts, 0);
    expect(sink.analyticsCalls, [false]);
  });

  test('analytics is forced off when telemetry is not permitted', () async {
    final sink = _FakeSink();

    // Debug build / emulator / no DSN, with the user opted IN.
    await _runtime(sink, permitted: false).setEnabled(true);

    expect(sink.analyticsCalls, [false]);
    expect(sink.starts, 0);
  });

  test('opting back in starts Sentry again', () async {
    final sink = _FakeSink();
    final runtime = _runtime(sink);
    await runtime.setEnabled(true);
    await runtime.setEnabled(false);

    await runtime.setEnabled(true);

    expect(sink.starts, 2);
    expect(runtime.isErrorReportingStarted, isTrue);
  });

  test('repeating the same state does not restart the sdk', () async {
    final sink = _FakeSink();
    final runtime = _runtime(sink);

    await runtime.setEnabled(true);
    await runtime.setEnabled(true);

    expect(sink.starts, 1);
  });

  test(
    'a failed start leaves error reporting down rather than throwing',
    () async {
      final sink = _FakeSink()..startThrows = true;
      final runtime = _runtime(sink);

      await runtime.setEnabled(true);

      expect(runtime.isErrorReportingStarted, isFalse);
    },
  );
}
