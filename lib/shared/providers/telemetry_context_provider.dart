import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/client_trace_scope.dart';
import '../../core/telemetry/error_reporter.dart';
import '../../core/telemetry/telemetry_context.dart';
import '../../core/telemetry/usage_analytics.dart';
import '../../data/services/telemetry/telemetry_providers.dart';
import 'connectivity_provider.dart';
import 'user_provider.dart';

/// Owns the single mutable [TelemetryContext] and keeps it current.
///
/// Connectivity is the field that matters most for this app: teachers work in
/// halaqas that may have no signal, so "it failed" and "it failed offline" are
/// different bugs. Recording transitions as breadcrumbs makes the difference
/// visible in every subsequent report.
class TelemetryRouteReporter {
  TelemetryRouteReporter(
    this._reporter,
    this._analytics,
    this._read,
    this._write,
  );

  final ErrorReporter _reporter;
  final UsageAnalytics _analytics;
  final TelemetryContext Function() _read;
  final void Function(TelemetryContext) _write;

  void reportRoute(String location) {
    final updated = _read().copyWith(route: location);
    _write(updated);
    _reporter.updateContext(updated);
    _reporter.addBreadcrumb(
      'navigated to ${updated.route}',
      category: 'navigation',
    );
    _analytics.recordScreenView(updated.route ?? '/');
  }
}

final _contextHolderProvider = Provider<_ContextHolder>(
  (ref) => _ContextHolder(),
);

class _ContextHolder {
  TelemetryContext value = TelemetryContext.empty;
}

/// Hands out the scope that keeps a callable's `clientTraceId` on the context
/// while that callable is in flight. It writes through the same holder the
/// route reporter uses, so the id joins the existing tags rather than
/// replacing them.
final clientTraceScopeProvider = Provider<ClientTraceScope>((ref) {
  final holder = ref.watch(_contextHolderProvider);
  final reporter = ref.watch(errorReporterProvider);
  return ClientTraceScope(
    read: () => holder.value,
    write: (updated) {
      holder.value = updated;
      reporter.updateContext(updated);
    },
  );
});

final telemetryRouteReporterProvider = Provider<TelemetryRouteReporter>((ref) {
  final holder = ref.watch(_contextHolderProvider);
  return TelemetryRouteReporter(
    ref.watch(errorReporterProvider),
    ref.watch(usageAnalyticsProvider),
    () => holder.value,
    (updated) => holder.value = updated,
  );
});

/// Watched once from the app root, mirroring [offlineSyncControllerProvider].
final telemetryContextControllerProvider = Provider<void>((ref) {
  final reporter = ref.watch(errorReporterProvider);
  final analytics = ref.watch(usageAnalyticsProvider);
  final holder = ref.watch(_contextHolderProvider);

  void push(TelemetryContext updated) {
    holder.value = updated;
    reporter.updateContext(updated);
  }

  ref.listen(currentUserProvider, (previous, next) {
    if (next == null) {
      // Sign-out: `copyWith`'s `??` merge only KEEPS a field when the new
      // value is null, so merging here would leave the previous user's uid,
      // role and institute attached to every report filed by whoever uses
      // this device next (halaqa devices are shared). Build a fresh context
      // instead, carrying over only connectivity, which is a property of the
      // device/network, not of who is signed in.
      push(TelemetryContext(connectivity: holder.value.connectivity));
      return;
    }
    push(
      holder.value.copyWith(
        userId: next.id,
        role: next.role.name,
        instituteId: next.instituteId,
      ),
    );
    analytics.setUserProperties(
      role: next.role.name,
      instituteId: next.instituteId ?? 'none',
    );
  }, fireImmediately: true);

  ref.listen(isConnectedProvider, (previous, next) {
    final label = next ? 'online' : 'offline';
    push(holder.value.copyWith(connectivity: label));
    reporter.addBreadcrumb(
      'connectivity became $label',
      category: 'connectivity',
    );
  }, fireImmediately: true);
});
