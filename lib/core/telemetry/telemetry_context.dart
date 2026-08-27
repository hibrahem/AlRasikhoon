import 'pii_scrubber.dart';

/// The complete, closed set of context that may accompany a telemetry event.
///
/// Deliberately NOT a `Map<String, dynamic>`: an open bag is exactly how a
/// student's name ends up in an error console. Adding a field here is a
/// reviewable act.
class TelemetryContext {
  const TelemetryContext({
    this.userId,
    this.role,
    this.instituteId,
    this.route,
    this.connectivity,
    this.clientTraceId,
  });

  static const TelemetryContext empty = TelemetryContext();

  /// Opaque Firebase uid. Sent as the Sentry user id so a report can be
  /// correlated with Firestore documents; never exposed as a searchable tag.
  final String? userId;

  /// One of: superAdmin, supervisor, teacher, student, guardian.
  final String? role;
  final String? instituteId;

  /// Always templated (`/students/:id`), never a raw location.
  final String? route;

  /// One of: online, offline.
  final String? connectivity;

  /// The id of the Cloud Function callable currently in flight, if any. It is
  /// a random per-attempt UUID carrying no user data, and it is the ONLY thing
  /// that joins a client-side Sentry event to the function's Cloud Logging
  /// line — see `docs/guides/observability-runbook.md` §1.
  final String? clientTraceId;

  TelemetryContext copyWith({
    String? userId,
    String? role,
    String? instituteId,
    String? route,
    String? connectivity,
  }) {
    return TelemetryContext(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      instituteId: instituteId ?? this.instituteId,
      route: route == null ? this.route : templateRoute(route),
      connectivity: connectivity ?? this.connectivity,
      clientTraceId: clientTraceId,
    );
  }

  /// Sets — or, with `null`, clears — the in-flight callable's trace id.
  ///
  /// Separate from [copyWith] on purpose: `copyWith`'s `??` merge can only
  /// ever ADD a value, and this is the one field that must also be removable,
  /// so a finished call's id cannot ride along on an unrelated later report.
  TelemetryContext withClientTraceId(String? traceId) {
    return TelemetryContext(
      userId: userId,
      role: role,
      instituteId: instituteId,
      route: route,
      connectivity: connectivity,
      clientTraceId: traceId,
    );
  }

  Map<String, String> toTags() {
    return {
      if (role != null) 'role': role!,
      if (instituteId != null) 'institute_id': instituteId!,
      if (route != null) 'route': route!,
      if (connectivity != null) 'connectivity': connectivity!,
      // Camel-case on purpose: this is the exact tag name the runbook tells
      // on-call to paste into Sentry's search box, and it must match the
      // `clientTraceId` field the Cloud Functions logger writes.
      if (clientTraceId != null) 'clientTraceId': clientTraceId!,
    };
  }
}
