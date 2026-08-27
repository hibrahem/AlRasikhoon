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

  /// Removes the [role] and [instituteId] user properties.
  ///
  /// Called on sign-out. Halaqa devices are shared, so leaving them set would
  /// attribute the next person's session to the previous user's role and
  /// institute.
  void clearUserProperties();

  /// [templatedRoute] must already be templated (`/students/:id`).
  void recordScreenView(String templatedRoute);
}
