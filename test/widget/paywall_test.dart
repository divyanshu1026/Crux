import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crux/core/data/local_store.dart';
import 'package:crux/core/providers/providers.dart';
import 'package:crux/core/theme/app_theme.dart';
import 'package:crux/features/paywall/data/billing_service.dart';
import 'package:crux/features/paywall/data/purchase_verifier.dart';
import 'package:crux/features/paywall/presentation/paywall_screen.dart';

/// The paywall used to call `setPro(true)` the moment a mock said "sure", so
/// tapping Subscribe granted Pro for free. These tests pin the rule that
/// replaced it: **only a server-granted entitlement unlocks Pro.**
class _FakeBilling implements BillingService {
  _FakeBilling(this.outcome);
  final PurchaseOutcome outcome;
  int purchaseCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<List<BillingPlan>> plans() async => const [
        BillingPlan(
          id: kProAnnualId,
          title: 'Annual',
          price: '₹2,499.00',
          period: '/year',
          highlighted: true,
        ),
        BillingPlan(
          id: kProMonthlyId,
          title: 'Monthly',
          price: '₹399.00',
          period: '/month',
        ),
      ];

  @override
  Future<PurchaseOutcome> purchase(String planId) async {
    purchaseCalls++;
    return outcome;
  }

  @override
  Future<PurchaseOutcome> restore() async => outcome;

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rq.profile': jsonEncode({
        'name': 'Test',
        'hasCompletedOnboarding': true,
        'isPro': false,
      }),
    });
  });

  Future<ProviderContainer> pumpPaywall(
    WidgetTester tester,
    BillingService billing,
  ) async {
    // Tall surface so the plan tiles are laid out rather than left off-screen
    // by the lazy list — a finder can't see what was never built.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      billingServiceProvider.overrideWithValue(billing),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: CxTheme.dark, home: const PaywallScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('store prices are shown, not hardcoded dollars', (tester) async {
    await pumpPaywall(tester, _FakeBilling(const PurchaseCancelled()));
    expect(find.text('₹2,499.00'), findsOneWidget);
    expect(find.text('₹399.00'), findsOneWidget);
  });

  testWidgets('a failed purchase does NOT grant Pro', (tester) async {
    final container = await pumpPaywall(
      tester,
      _FakeBilling(const PurchaseFailed('Your card was declined.')),
    );

    await tester.tap(find.text('Start annual plan'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).isPro, isFalse);
    expect(find.text('Your card was declined.'), findsOneWidget);
  });

  testWidgets('a cancelled purchase grants nothing and says nothing',
      (tester) async {
    final container =
        await pumpPaywall(tester, _FakeBilling(const PurchaseCancelled()));

    await tester.tap(find.text('Start annual plan'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).isPro, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a pending payment does not grant Pro yet', (tester) async {
    final container =
        await pumpPaywall(tester, _FakeBilling(const PurchasePending()));

    await tester.tap(find.text('Start annual plan'));
    await tester.pumpAndSettle();

    expect(container.read(userProfileProvider).isPro, isFalse);
    expect(find.textContaining('still going through'), findsOneWidget);
  });

  testWidgets('a server-granted entitlement unlocks Pro with its expiry',
      (tester) async {
    final expires = DateTime.now().add(const Duration(days: 365));
    final container = await pumpPaywall(
      tester,
      _FakeBilling(PurchaseGranted(
        Entitlement(isPro: true, expiresAt: expires, status: 'active'),
      )),
    );

    await tester.tap(find.text('Start annual plan'));
    await tester.pumpAndSettle();

    final profile = container.read(userProfileProvider);
    expect(profile.isPro, isTrue);
    expect(profile.proExpiresAt, expires);
    expect(profile.hasProAccess, isTrue);
  });
}
