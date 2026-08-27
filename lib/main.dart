import 'dart:async';

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
import 'core/telemetry/error_reporter.dart';
import 'core/telemetry/telemetry_gate.dart';
import 'data/services/shared_preferences_provider.dart';
import 'data/services/session_cache.dart';
import 'data/services/telemetry/telemetry_providers.dart';
import 'core/config/firebase_emulator_config.dart';
import 'core/constants/app_constants.dart';
import 'shared/providers/telemetry_provider_observer.dart';

void main() {
  // Firebase init, emulator config, Firestore settings, Hive and
  // SharedPreferences all run before the reporter can exist, and "the app
  // won't launch" is the worst production failure there is — it used to
  // report nothing at all. The guarded zone catches a throw from any of them
  // without changing a single step's behaviour or order.
  //
  // `reporter` is assigned as soon as the real one is built; until then the
  // handler falls back to [_reportStartupFailure], which pays the cost of
  // standing a minimal reporter up ON THE FAILURE PATH ONLY. The healthy
  // pre-first-frame path is untouched.
  ErrorReporter? reporter;

  runZonedGuarded(
    () async {
      reporter = await _bootstrap();
    },
    (error, stack) {
      final live = reporter;
      if (live != null) {
        live.recordError(
          error,
          stack,
          reason: 'uncaught zone error',
          fatal: true,
        );
        return;
      }
      unawaited(_reportStartupFailure(error, stack));
    },
  );
}

/// Reports a startup failure that happened before the real reporter existed.
///
/// The normal reporter depends on SharedPreferences (for the opt-out) and is
/// built after Firebase, so a failure earlier than that would otherwise be
/// invisible. Everything needed to report it — the stored preference and
/// Sentry — is independent of Firebase, so a minimal reporter can be stood up
/// here. Never throws: failing to report a failure is dropped.
Future<void> _reportStartupFailure(Object error, StackTrace stack) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final gate = TelemetryGate(
      isOpen: prefs.getBool(kTelemetryEnabledKey) ?? true,
    );
    await createTelemetryRuntime(
      gate: gate,
      dsn: kSentryDsn,
    ).setEnabled(gate.isOpen);
    createErrorReporter(gate: gate, dsn: kSentryDsn).recordError(
      error,
      stack,
      reason: 'startup failed before telemetry was ready',
      fatal: true,
    );
  } catch (_) {}
}

Future<ErrorReporter> _bootstrap() async {
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
    isOpen: sharedPreferences.getBool(kTelemetryEnabledKey) ?? true,
  );
  // The gate only guards the Dart layer. Firebase Analytics starts native
  // auto-collection at launch and Sentry's native crash handler and session
  // tracking send on their own, so the SDKs themselves are switched here — and
  // Sentry is not initialised at all for a user who is opted out.
  final telemetryRuntime = createTelemetryRuntime(
    gate: telemetryGate,
    dsn: kSentryDsn,
  );
  await telemetryRuntime.setEnabled(telemetryGate.isOpen);
  final errorReporter = createErrorReporter(
    gate: telemetryGate,
    dsn: kSentryDsn,
  );
  final usageAnalytics = createUsageAnalytics(
    gate: telemetryGate,
    dsn: kSentryDsn,
  );

  // Widget build/layout errors. presentError keeps the normal red-screen and
  // console behaviour intact for developers.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Honour `silent` the way sentry_flutter's own integration does. This app
    // is RTL Arabic with a history of text overflows, and a single recurring
    // RenderFlex overflow would otherwise become a release-build Sentry event
    // on every frame, burning the quota and burying real crashes.
    if (details.silent) return;
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
    // `true` tells the engine the error was handled and suppresses its
    // stderr fallback. In debug builds the reporter is the no-op adapter, so
    // returning `true` unconditionally would make async errors vanish
    // silently for developers; returning `false` there lets the engine's
    // fallback print run as it always has. Release builds keep suppressing
    // it — there is no console there to print to.
    return !kDebugMode;
  };

  runApp(
    ProviderScope(
      observers: [TelemetryProviderObserver(errorReporter)],
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionBoxProvider.overrideWithValue(sessionBox),
        errorReporterProvider.overrideWithValue(errorReporter),
        usageAnalyticsProvider.overrideWithValue(usageAnalytics),
        telemetryGateProvider.overrideWithValue(telemetryGate),
        telemetryRuntimeProvider.overrideWithValue(telemetryRuntime),
      ],
      child: const AlRasikhoonApp(),
    ),
  );

  return errorReporter;
}
