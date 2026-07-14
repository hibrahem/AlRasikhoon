import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'data/services/local_storage_service.dart';
import 'core/config/firebase_emulator_config.dart';

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

  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AlRasikhoonApp(),
    ),
  );
}
