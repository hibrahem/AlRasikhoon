import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/telemetry/telemetry_gate.dart';
import 'data/services/shared_preferences_provider.dart';
import 'data/services/session_cache.dart';
import 'data/services/telemetry/telemetry_providers.dart';
import 'core/config/firebase_emulator_config.dart';
import 'core/constants/app_constants.dart';
import 'shared/providers/telemetry_provider_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cairo is BUNDLED (pubspec `google_fonts/`), never downloaded. Without this
  // google_fonts fetches the font on first launch, which makes the app's type a
  // cold-start dependency on connectivity — a halaqa may have none — and lets a
  // missing weight degrade silently to a fallback font whose metrics differ
  // enough to overflow screens that otherwise fit. Pinned here, a missing weight
  // is a loud asset error instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Configure Firebase Emulators if enabled
  await FirebaseEmulatorConfig.configureEmulators();

  // Offline mode rests on Firestore's disk cache (see
  // docs/superpowers/specs/2026-07-19-offline-mode-design.md). Persistence is
  // the platform default on mobile but is pinned here so it can never silently
  // regress, and the cache is unbounded so LRU eviction cannot drop the
  // curriculum catalog a teacher needs in a halaqa with no connectivity.
  // copyWith — not a fresh Settings — so the emulator host applied above
  // survives.
  FirebaseFirestore.instance.settings = FirebaseFirestore.instance.settings
      .copyWith(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

  // Initialize Hive and open the session box BEFORE runApp so
  // AuthRepository.build() can read the cached user synchronously and route
  // the returning user before the first frame.
  await Hive.initFlutter();

  // Open the session box defensively: a corrupt box must never strand the app
  // on the splash. On failure, delete it and reopen a fresh (empty) box — the
  // cache is simply absent and the normal login flow runs.
  Future<Box> openSessionBox() async {
    try {
      return await Hive.openBox(AppConstants.boxSession);
    } catch (_) {
      await Hive.deleteBoxFromDisk(AppConstants.boxSession);
      return await Hive.openBox(AppConstants.boxSession);
    }
  }

  // The remaining local inits are independent — run them concurrently to
  // shrink the pre-first-frame window.
  final results = await Future.wait([
    openSessionBox(),
    SharedPreferences.getInstance(),
  ]);
  final sessionBox = results[0] as Box;
  final sharedPreferences = results[1] as SharedPreferences;

  // Telemetry is created before runApp so the ProviderObserver can be handed
  // to ProviderScope, and so an uncaught error during the first frame is
  // already covered. SharedPreferences is already loaded above, so the user's
  // opt-out is known without a second async hop.
  final telemetryGate = TelemetryGate(
    isOpen: sharedPreferences.getBool('telemetry_enabled') ?? true,
  );
  final errorReporter = await createErrorReporter(
    gate: telemetryGate,
    dsn: kSentryDsn,
  );

  // Widget build/layout errors. presentError keeps the normal red-screen and
  // console behaviour intact for developers.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    errorReporter.recordError(
      details.exception,
      details.stack,
      // details.context can render widget text; the library name cannot.
      reason: 'flutter error in ${details.library}',
    );
  };

  // Uncaught async errors that escape to the platform.
  PlatformDispatcher.instance.onError = (error, stack) {
    errorReporter.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    ProviderScope(
      observers: [TelemetryProviderObserver(errorReporter)],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionBoxProvider.overrideWithValue(sessionBox),
        errorReporterProvider.overrideWithValue(errorReporter),
        telemetryGateProvider.overrideWithValue(telemetryGate),
      ],
      child: const AlRasikhoonApp(),
    ),
  );
}
