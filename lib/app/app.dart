import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_lifecycle.dart';
import '../core/providers/backup_providers.dart';
import '../core/theme/theme.dart';
import '../features/paywall/data/purchase_verifier.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme_mode_provider.dart';

/// Root of the Crux app.
class CruxApp extends ConsumerStatefulWidget {
  const CruxApp({super.key});

  @override
  ConsumerState<CruxApp> createState() => _CruxAppState();
}

class _CruxAppState extends ConsumerState<CruxApp> {
  @override
  Widget build(BuildContext context) {
    // Watched at the root so foreground/background tracking is live from
    // launch. If this were only read lazily, the first reader would be
    // whatever code happened to ask — typically the rest timer, mid-workout,
    // which is exactly when a wrong answer costs the user their alert.
    ref.watch(appIsForegroundProvider);
    // Runs a backup when one is due — on launch and on each foreground.
    ref.watch(backupSchedulerProvider);
    // Pulls the Pro entitlement from the server on launch and on account
    // change, so renewals and cancellations that happened while the app was
    // closed are reflected before anything reads `hasProAccess`.
    ref.watch(entitlementSyncProvider);
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: CxTheme.light,
      darkTheme: CxTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
    );
  }
}
