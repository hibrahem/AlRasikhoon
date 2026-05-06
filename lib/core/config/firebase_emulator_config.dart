import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Configuration for Firebase Emulator connection.
///
/// This class handles connecting to Firebase Emulators for local development
/// and E2E testing. Emulator mode is enabled via:
/// `flutter build web --dart-define=USE_FIREBASE_EMULATOR=true`
class FirebaseEmulatorConfig {
  static const bool _useEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// Whether emulator mode is enabled
  static bool get isEmulatorMode => _useEmulator;

  /// Configure Firebase to use emulators if enabled.
  ///
  /// Call this method after Firebase.initializeApp() in main.dart.
  ///
  /// Emulator ports:
  /// - Auth: 9099
  /// - Firestore: 8080
  /// - UI: 4000
  static Future<void> configureEmulators() async {
    if (!_useEmulator) {
      return;
    }

    final String host = _getEmulatorHost();

    if (kDebugMode) {
      print('Firebase Emulator Mode: Connecting to $host');
    }

    // Connect to Auth Emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    if (kDebugMode) {
      print('Connected to Auth Emulator at $host:9099');
    }

    // Connect to Firestore Emulator
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    if (kDebugMode) {
      print('Connected to Firestore Emulator at $host:8080');
    }
  }

  /// Get the appropriate emulator host based on platform.
  ///
  /// - Web: localhost
  /// - Android Emulator: 10.0.2.2 (special IP to reach host machine)
  /// - iOS Simulator/Physical devices: localhost
  static String _getEmulatorHost() {
    if (kIsWeb) {
      return 'localhost';
    }

    // For mobile platforms, can be overridden via dart-define
    const String customHost = String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: '',
    );

    if (customHost.isNotEmpty) {
      return customHost;
    }

    // Default to localhost (works for iOS simulator)
    // For Android emulator, pass --dart-define=EMULATOR_HOST=10.0.2.2
    return 'localhost';
  }
}
