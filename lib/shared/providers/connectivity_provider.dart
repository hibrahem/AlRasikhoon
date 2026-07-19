import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connectivity status
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  // The connectivity plugin's subscription runs platform-channel work inside
  // a fire-and-forget async onListen callback: with no platform bindings (a
  // plain unit-test harness) that callback throws where NOTHING downstream
  // can catch it — not `handleError`, not a try/catch here — and the test
  // zone reports an unhandled error. So probe the bindings BEFORE
  // subscribing: absent bindings means no platform, means the stream stays
  // quiet and consumers keep their loading default (treated as online).
  try {
    ServicesBinding.instance;
  } catch (_) {
    return;
  }
  // `handleError` still guards the bindings-present-but-plugin-missing case
  // (widget tests), where the failure DOES arrive as a catchable error.
  yield* Connectivity().onConnectivityChanged.handleError((Object _) {});
});

/// Provider to check if connected to internet
final isConnectedProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) =>
        results.isNotEmpty && !results.contains(ConnectivityResult.none),
    loading: () => true,
    error: (_, _) => false,
  );
});

/// Provider to check current connectivity type
final connectivityTypeProvider = Provider<ConnectivityResult?>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty ? results.first : null,
    loading: () => null,
    error: (_, _) => null,
  );
});
