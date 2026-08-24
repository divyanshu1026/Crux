import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/design_gallery/presentation/design_gallery_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/legal/domain/legal_docs.dart';
import '../features/legal/presentation/legal_doc_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/paywall/presentation/paywall_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/today/presentation/today_screen.dart';
import 'shell_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// The app router, built once with access to Riverpod for auth gating.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<bool>(false);
  ref.listen<AuthState>(authProvider, (_, __) {
    refreshNotifier.value = !refreshNotifier.value;
  });
  ref.listen<bool>(
    userProfileProvider.select((p) => p.hasCompletedOnboarding),
    (_, __) {
      refreshNotifier.value = !refreshNotifier.value;
    },
  );
  // The gate also depends on a program existing (see [buildRouter]).
  ref.listen<bool>(
    programProvider.select((p) => p == null),
    (_, __) {
      refreshNotifier.value = !refreshNotifier.value;
    },
  );
  return buildRouter(ref, refreshNotifier);
});

/// App routes.
abstract final class Routes {
  static const auth = '/auth';
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const history = '/history';
  static const dashboard = '/dashboard';
  static const coach = '/coach';
  static const profile = '/profile';
  static const settings = '/settings';
  static const schedule = '/schedule';
  static const paywall = '/paywall';
  static const gallery = '/gallery';
  static const privacy = '/legal/privacy';
  static const terms = '/legal/terms';
}

/// Builds the app router.
///
/// The flow is gated by auth + onboarding state (Phases 2/6): a signed-out user
/// lands on [Routes.auth]; a signed-in user who hasn't finished onboarding lands
/// on [Routes.onboarding]; everyone else gets the bottom-nav shell. The gate is
/// driven by Riverpod via [refreshListenable] so it re-evaluates on state change.
GoRouter buildRouter(Ref ref, Listenable refreshListenable) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.today,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final profile = ref.read(userProfileProvider);
      // Onboarding is the only place a program is created, so a missing program
      // means the setup never really finished on this device — even if the
      // restored profile claims it did. Without this check the user lands in
      // the shell with nothing but empty placeholders and no route back.
      final onboarded =
          profile.hasCompletedOnboarding && ref.read(programProvider) != null;
      final loc = state.matchedLocation;

      final atAuth = loc == Routes.auth;
      final atOnboarding = loc == Routes.onboarding;
      final isLegalDoc = loc == Routes.privacy || loc == Routes.terms;

      // 1. Not signed in → always send to auth unless viewing public legal docs.
      if (!auth.isAuthenticated) {
        if (isLegalDoc) return null;
        return atAuth ? null : Routes.auth;
      }
      // 2. Signed in but onboarding incomplete → send to onboarding.
      if (!onboarded) {
        return atOnboarding ? null : Routes.onboarding;
      }
      // 3. Fully set up but sitting on a gate screen → send into the app.
      if (atAuth || atOnboarding) return Routes.today;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.auth,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          _branch(Routes.today, const TodayScreen()),
          _branch(Routes.history, const HistoryScreen()),
          _branch(Routes.dashboard, const DashboardScreen()),
          _branch(Routes.coach, const CoachScreen()),
          _branch(Routes.profile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.schedule,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            const LegalDocScreen(doc: LegalDocs.privacy),
      ),
      GoRoute(
        path: Routes.terms,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const LegalDocScreen(doc: LegalDocs.terms),
      ),
      GoRoute(
        path: Routes.paywall,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: Routes.gallery,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DesignGalleryScreen(),
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget child) {
  return StatefulShellBranch(
    routes: [
      GoRoute(path: path, builder: (context, state) => child),
    ],
  );
}


