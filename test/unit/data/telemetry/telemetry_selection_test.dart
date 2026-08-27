import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';

void main() {
  const dsn = 'https://examplePublicKey@o0.ingest.sentry.io/0';

  test('telemetry is permitted in a release build with a configured dsn', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: false, dsn: dsn),
      isTrue,
    );
  });

  test('telemetry is disabled in debug builds', () {
    expect(
      telemetryIsPermitted(isDebug: true, isEmulator: false, dsn: dsn),
      isFalse,
    );
  });

  test('telemetry is disabled in emulator mode', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: true, dsn: dsn),
      isFalse,
    );
  });

  test('telemetry is disabled when no dsn is configured', () {
    expect(
      telemetryIsPermitted(isDebug: false, isEmulator: false, dsn: ''),
      isFalse,
    );
  });
}
