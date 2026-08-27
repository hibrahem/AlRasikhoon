import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/error_reporter.dart';
import 'package:al_rasikhoon/core/telemetry/analytics_event.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';
import 'package:al_rasikhoon/core/telemetry/usage_analytics.dart';
import 'package:al_rasikhoon/data/models/user_model.dart';
import 'package:al_rasikhoon/data/services/telemetry/telemetry_providers.dart';
import 'package:al_rasikhoon/shared/providers/connectivity_provider.dart';
import 'package:al_rasikhoon/shared/providers/telemetry_context_provider.dart';
import 'package:al_rasikhoon/shared/providers/user_provider.dart';

class _RecordingReporter implements ErrorReporter {
  final List<TelemetryContext> contexts = [];
  final List<String> breadcrumbs = [];

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void addBreadcrumb(String message, {String? category}) {
    breadcrumbs.add(message);
  }

  @override
  void updateContext(TelemetryContext context) {
    contexts.add(context);
  }
}

class _RecordingAnalytics implements UsageAnalytics {
  final List<({String role, String instituteId})> setCalls = [];
  int clearCalls = 0;

  @override
  void record(AnalyticsEvent event) {}

  @override
  void setUserProperties({required String role, required String instituteId}) {
    setCalls.add((role: role, instituteId: instituteId));
  }

  @override
  void clearUserProperties() => clearCalls++;

  @override
  void recordScreenView(String templatedRoute) {}
}

UserModel _teacher({required String id, String instituteId = 'inst-1'}) {
  return UserModel(
    id: id,
    email: 'teacher@example.com',
    name: 'Teacher',
    role: UserRole.teacher,
    instituteId: instituteId,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  test(
    'losing connectivity updates the context and leaves a breadcrumb',
    () async {
      final reporter = _RecordingReporter();
      final connected = StateProvider<bool>((ref) => true);

      final container = ProviderContainer(
        overrides: [
          errorReporterProvider.overrideWithValue(reporter),
          isConnectedProvider.overrideWith((ref) => ref.watch(connected)),
        ],
      );
      addTearDown(container.dispose);

      // `container.read` is a fire-and-forget lookup: without a standing
      // subscriber the controller has no listener and Riverpod stops
      // forwarding it dependency updates. Watching it, exactly as
      // `AlRasikhoonApp.build` does via `ref.watch`, is what keeps its
      // internal `ref.listen` calls live for the rest of the app session —
      // and for this test.
      final controllerSub = container.listen(
        telemetryContextControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSub.close);

      container.read(connected.notifier).state = false;
      // Riverpod 3 batches notifications from a watched dependency onto a
      // microtask; without pumping, the listener above would not yet have
      // observed the change.
      await container.pump();

      expect(reporter.contexts.last.connectivity, 'offline');
      expect(reporter.breadcrumbs.last, contains('offline'));
    },
  );

  test('a route change is recorded as a templated route', () {
    final reporter = _RecordingReporter();
    final container = ProviderContainer(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
    );
    addTearDown(container.dispose);

    container.read(telemetryContextControllerProvider);
    container
        .read(telemetryRouteReporterProvider)
        .reportRoute('/students/aB3xY9kL2mN7pQ4rS8tU');

    expect(reporter.contexts.last.route, '/students/:id');
    expect(reporter.breadcrumbs.last, contains('/students/:id'));
    expect(reporter.breadcrumbs.last, isNot(contains('aB3xY9kL2')));
  });

  test(
    'signing out clears the previous teacher identity instead of retaining it',
    () async {
      final reporter = _RecordingReporter();
      final currentUser = StateProvider<UserModel?>(
        (ref) => _teacher(id: 'teacher-uid-1'),
      );
      final connected = StateProvider<bool>((ref) => true);

      final container = ProviderContainer(
        overrides: [
          errorReporterProvider.overrideWithValue(reporter),
          currentUserProvider.overrideWith((ref) => ref.watch(currentUser)),
          isConnectedProvider.overrideWith((ref) => ref.watch(connected)),
        ],
      );
      addTearDown(container.dispose);

      final controllerSub = container.listen(
        telemetryContextControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSub.close);

      // Sanity check: the signed-in teacher's identity was attached first.
      expect(reporter.contexts.last.userId, 'teacher-uid-1');
      expect(reporter.contexts.last.role, 'teacher');
      expect(reporter.contexts.last.instituteId, 'inst-1');

      // Connectivity changes independently of the user session.
      container.read(connected.notifier).state = false;
      await container.pump();

      // Sign-out: the auth state collapses to null.
      container.read(currentUser.notifier).state = null;
      await container.pump();

      final afterSignOut = reporter.contexts.last;
      expect(afterSignOut.userId, isNull);
      expect(afterSignOut.role, isNull);
      expect(afterSignOut.instituteId, isNull);
      // Connectivity is unrelated to who is signed in and must survive.
      expect(afterSignOut.connectivity, 'offline');
    },
  );

  test(
    'signing out clears the analytics role and institute properties',
    () async {
      final analytics = _RecordingAnalytics();
      final currentUser = StateProvider<UserModel?>(
        (ref) => _teacher(id: 'teacher-uid-1'),
      );

      final container = ProviderContainer(
        overrides: [
          errorReporterProvider.overrideWithValue(_RecordingReporter()),
          usageAnalyticsProvider.overrideWithValue(analytics),
          currentUserProvider.overrideWith((ref) => ref.watch(currentUser)),
        ],
      );
      addTearDown(container.dispose);

      final controllerSub = container.listen(
        telemetryContextControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSub.close);

      expect(analytics.setCalls.single.role, 'teacher');

      container.read(currentUser.notifier).state = null;
      await container.pump();

      // Analytics user properties are sticky across a sign-out, so on a shared
      // halaqa device the next user would inherit them.
      expect(analytics.clearCalls, 1);
    },
  );
}
