import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/theme/theme.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/data/program_templates.dart';
import 'package:crux/core/models/models.dart';
import 'package:crux/l10n/app_localizations.dart';

/// Registers the bundled Crux fonts so widget/golden tests render with the
/// real typefaces instead of the fallback test font.
Future<void> loadCruxFonts() async {
  final families = <String, List<String>>{
    'ClashDisplay': [
      'fonts/ClashDisplay-Regular.ttf',
      'fonts/ClashDisplay-Medium.ttf',
      'fonts/ClashDisplay-Semibold.ttf',
      'fonts/ClashDisplay-Bold.ttf',
    ],
    'GeneralSans': [
      'fonts/GeneralSans-Regular.ttf',
      'fonts/GeneralSans-Medium.ttf',
      'fonts/GeneralSans-Semibold.ttf',
      'fonts/GeneralSans-Bold.ttf',
    ],
    'JetBrainsMono': [
      'fonts/JetBrainsMono-Regular.ttf',
      'fonts/JetBrainsMono-Medium.ttf',
      'fonts/JetBrainsMono-Bold.ttf',
    ],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(file.readAsBytesSync().buffer.asByteData()),
        );
      }
    }
    await loader.load();
  }

  await _loadMaterialIcons();
}

/// Registers the Material Icons glyph font from the Flutter SDK so icons render
/// in golden tests instead of tofu boxes. Degrades gracefully if not found.
Future<void> _loadMaterialIcons() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final candidates = [
    File('$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf'),
    File('$flutterRoot/bin/cache/artifacts/material_fonts/'
        'materialicons-regular.otf'),
  ];
  for (final font in candidates) {
    if (font.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(font.readAsBytesSync().buffer.asByteData()));
      await loader.load();
      return;
    }
  }
}

/// Helper to set up mock shared preferences.
Future<SharedPreferences> initMockPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return await SharedPreferences.getInstance();
}

/// A real, persisted-shape program for seeding `LocalStore.kProgram`.
///
/// The router treats "onboarded but no program" as unfinished setup, so any
/// test that expects to land in the shell must seed this alongside
/// `hasCompletedOnboarding`.
String seededProgramJson() => jsonEncode(
      ProgramTemplates.pickBest(const UserProfile(
        name: 'Test',
        sex: 'Prefer not to say',
        age: 30,
        height: 175,
        weight: 75,
        goal: 'Build Muscle',
        experience: '6–24 months',
        daysPerWeek: ['Mon', 'Wed', 'Fri'],
        equipment: 'Full gym',
        injuries: [],
        notificationPermission: false,
        avatar: 'default',
      )).toJson(),
    );

/// Wraps [child] in the app's providers, theme and localization delegates so a
/// screen can be pumped in isolation.
Widget wrapApp(
  Widget child, {
  ThemeMode themeMode = ThemeMode.dark,
  SharedPreferences? prefs,
}) {
  return ProviderScope(
    overrides: [
      if (prefs != null)
        sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CxTheme.light,
      darkTheme: CxTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );
}
