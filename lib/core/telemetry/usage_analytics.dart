import 'analytics_event.dart';

/// Records aggregate product usage.
///
/// Implementations MUST NOT set a per-user identifier: only [role] and
/// [instituteId] are permitted user properties. See the design spec — setting a
/// uid here would turn aggregate analytics into a behavioural profile of
/// minors.
abstract interface class UsageAnalytics {
  void record(AnalyticsEvent event);
  void setUserProperties({required String role, required String instituteId});

  /// [templatedRoute] must already be templated (`/students/:id`).
  void recordScreenView(String templatedRoute);
}
