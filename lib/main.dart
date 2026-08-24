import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/data/local_store.dart';
import 'core/data/supabase/supabase_config.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local-first store — hydrates every provider on build. Always available.
  final prefs = await SharedPreferences.getInstance();

  // Optional cloud layer — only initializes if SUPABASE_URL/ANON_KEY were
  // passed via --dart-define; otherwise the app is fully local/offline.
  await SupabaseConfig.initIfConfigured();

  // Local reminders (no-op on web). Permission is requested only when the
  // user enables a reminder in Settings — never on first launch.
  await NotificationService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const CruxApp(),
    ),
  );
}
