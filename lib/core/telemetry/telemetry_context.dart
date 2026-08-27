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
    );
  }

  Map<String, String> toTags() {
    return {
      if (role != null) 'role': role!,
      if (instituteId != null) 'institute_id': instituteId!,
      if (route != null) 'route': route!,
      if (connectivity != null) 'connectivity': connectivity!,
    };
  }
}
