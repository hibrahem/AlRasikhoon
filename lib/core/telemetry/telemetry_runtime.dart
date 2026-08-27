/// Controls the *platform* telemetry layers — the native SDK machinery that
/// collects on its own, without this app ever calling it.
///
/// [TelemetryGate] is not enough on its own, and that gap was a real one: both
/// vendor SDKs collect below the Dart layer the gate guards.
///
/// - Firebase Analytics starts native auto-collection at app launch
///   (`first_open`, `session_start`, `screen_view`, `user_engagement`, the app
///   instance id, device/OS/region). No adapter of ours is involved, so no
///   gate check can suppress it.
/// - Sentry's native crash handler and its release-health session tracking
///   send envelopes straight from the native layer. `beforeSend` filters Dart
///   events only, so it cannot suppress them either.
///
/// The settings toggle promises the user that turning this off stops the
/// sending, and `web/privacy.html` says the same. Honouring that promise means
/// switching the SDKs themselves off, which is what this port is for.
abstract interface class TelemetryRuntime {
  /// Brings platform collection in line with [enabled].
  ///
  /// Implementations MUST be non-throwing and MUST treat "telemetry is not
  /// permitted at all" (debug build, emulator mode, no DSN) as `false`
  /// regardless of what is passed.
  Future<void> setEnabled(bool enabled);
}

/// Used wherever there is no platform to control: every test, and any code
/// path that never reached the vendor SDKs in the first place.
class NoopTelemetryRuntime implements TelemetryRuntime {
  const NoopTelemetryRuntime();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
