import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/telemetry/error_reporter.dart';

/// Routes every provider failure in the app to the [ErrorReporter].
///
/// This replaces the 62 per-screen `debugPrint('xProvider failed: $e')` calls
/// that preceded it. Those were both invisible in release builds and
/// incomplete — a provider with no `.when(error:)` branch reported nothing at
/// all. One observer covers every provider, including future ones.
///
/// `ProviderObserver` is an `abstract base class` in Riverpod 3, so this must
/// be `final`/`base`/`sealed` and use `extends`, not `implements`.
final class TelemetryProviderObserver extends ProviderObserver {
  TelemetryProviderObserver(this._reporter);

  final ErrorReporter _reporter;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    // A broken reporter must never escalate into a broken container, so this
    // swallows its own failures.
    try {
      final name =
          context.provider.name ?? context.provider.runtimeType.toString();
      _reporter.recordError(error, stackTrace, reason: 'provider $name failed');
    } catch (_) {}
  }
}
