import 'dart:async';

import 'client_trace_id.dart';
import 'telemetry_context.dart';

/// Runs a Cloud Function callable with a fresh trace id attached to the
/// ambient [TelemetryContext].
///
/// The id already travelled to the server in the callable payload and is
/// written into the function's structured log. Attaching it here is the other
/// half of that join: without it a failed account-creation attempt leaves two
/// disconnected trails and nothing to tie them together (see
/// `docs/guides/observability-runbook.md` §1).
class ClientTraceScope {
  ClientTraceScope({
    required TelemetryContext Function() read,
    required void Function(TelemetryContext) write,
  }) : _read = read,
       _write = write,
       _active = true;

  /// The default when no telemetry context is wired — every test harness, and
  /// any container without the overrides `main()` installs. The trace id is
  /// still generated (the callable payload and the server-side log line need
  /// it either way), but no context is touched and no timer is scheduled.
  ClientTraceScope.inert()
    : _read = _noContext,
      _write = _ignore,
      _active = false;

  static TelemetryContext _noContext() => TelemetryContext.empty;
  static void _ignore(TelemetryContext _) {}

  final TelemetryContext Function() _read;
  final void Function(TelemetryContext) _write;
  final bool _active;

  /// Invokes [body] with a freshly minted trace id, with that id live on the
  /// telemetry context for the duration of the call.
  Future<T> run<T>(Future<T> Function(String traceId) body) async {
    final traceId = newClientTraceId();
    if (!_active) return body(traceId);

    _set(traceId);
    try {
      final result = await body(traceId);
      // Success: nothing further will be reported for this call, so the id
      // goes immediately. Anything reported after this point belongs to some
      // other piece of work and must not inherit the tag.
      _set(null);
      return result;
    } catch (_) {
      // Failure is the case the whole feature exists for, and clearing here
      // would defeat it: the caller that awaits this future has NOT run its
      // `catch` yet. An awaited error resumes the caller as a microtask, and
      // that microtask is exactly where `errorReporter.recordError` runs — so
      // a synchronous clear would strip the tag off the one report on-call is
      // told to search for.
      //
      // `Timer.run` fires only once the microtask queue has fully drained,
      // i.e. after every synchronous catch-and-report in the await chain has
      // had its turn, and still within the same gesture — long before any
      // later, unrelated error can be reported. So the id lives exactly as
      // long as the failure it belongs to. (A caller that awaits something
      // else *before* reporting loses the tag; that is the deliberate trade
      // against leaking a stale id, and no such caller exists today.)
      Timer.run(() => _set(null));
      rethrow;
    }
  }

  void _set(String? traceId) => _write(_read().withClientTraceId(traceId));
}
