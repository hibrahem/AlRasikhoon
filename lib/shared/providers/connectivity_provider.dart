import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connectivity status
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider to check if connected to internet
final isConnectedProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty &&
        !results.contains(ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => false,
  );
});

/// Provider to check current connectivity type
final connectivityTypeProvider = Provider<ConnectivityResult?>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.isNotEmpty ? results.first : null,
    loading: () => null,
    error: (_, __) => null,
  );
});
