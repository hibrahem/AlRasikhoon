import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/client_trace_id.dart';

void main() {
  test('a trace id is unique per call', () {
    expect(newClientTraceId(), isNot(newClientTraceId()));
  });

  test('a trace id is short enough to read in a log line', () {
    expect(newClientTraceId().length, lessThanOrEqualTo(36));
    expect(newClientTraceId(), isNotEmpty);
  });

  test('a trace id carries no personal data', () {
    expect(newClientTraceId(), matches(RegExp(r'^[0-9a-fA-F-]+$')));
  });
}
