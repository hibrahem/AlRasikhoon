import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/data/services/telemetry/noop_telemetry.dart';

void main() {
  test('the no-op reporter accepts every call without throwing', () {
    const reporter = NoopErrorReporter();
    expect(
      () => reporter.recordError(Exception('boom'), StackTrace.current),
      returnsNormally,
    );
    expect(() => reporter.addBreadcrumb('opened screen'), returnsNormally);
    expect(
      () => reporter.updateContext(TelemetryContext.empty),
      returnsNormally,
    );
  });

  test('the no-op analytics accepts every call without throwing', () {
    const analytics = NoopUsageAnalytics();
    expect(() => analytics.record(const TalqeenCompleted()), returnsNormally);
    expect(
      () => analytics.setUserProperties(role: 'teacher', instituteId: 'i1'),
      returnsNormally,
    );
    expect(() => analytics.recordScreenView('/students/:id'), returnsNormally);
  });
}
