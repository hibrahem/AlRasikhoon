import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'features/settings/providers/theme_mode_provider.dart';
import 'shared/providers/offline_sync_provider.dart';
import 'shared/widgets/offline_banner.dart';
import 'shared/widgets/splash/splash_overlay.dart';
import 'shared/widgets/text_scale_clamp.dart';

class AlRasikhoonApp extends ConsumerWidget {
  const AlRasikhoonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the offline cache primed and clears pending-sync state on
    // reconnect — activated here so it lives for the whole app session.
    ref.watch(offlineSyncControllerProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'الراسخون',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return TextScaleClamp(
          child: Directionality(
            textDirection: TextDirection.rtl,
            // The animated brand splash plays once over the first frame while
            // routing/auth resolve beneath it, then removes itself.
            child: SplashOverlay(child: OfflineBannerHost(child: child!)),
          ),
        );
      },
    );
  }
}
