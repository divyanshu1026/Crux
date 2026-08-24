import 'package:flutter_test/flutter_test.dart';
import 'package:crux/core/models/models.dart';

/// `is_pro` as a bare boolean cannot expire, so a single purchase would grant
/// Pro forever. [UserProfile.hasProAccess] is what actually gates features.
void main() {
  UserProfile profile({required bool isPro, DateTime? expiresAt}) => UserProfile(
        name: 'Test',
        sex: 'Male',
        age: 30,
        height: 180,
        weight: 75,
        goal: 'Build Muscle',
        experience: '1-2 years',
        daysPerWeek: const ['Mon'],
        equipment: 'Full gym',
        injuries: const [],
        notificationPermission: false,
        avatar: 'default',
        isPro: isPro,
        proExpiresAt: expiresAt,
      );

  final now = DateTime.now();

  test('no entitlement means no access', () {
    expect(profile(isPro: false).hasProAccess, isFalse);
    expect(
      profile(isPro: false, expiresAt: now.add(const Duration(days: 30)))
          .hasProAccess,
      isFalse,
      reason: 'an expiry without is_pro must not unlock anything',
    );
  });

  test('an active subscription has access', () {
    expect(
      profile(isPro: true, expiresAt: now.add(const Duration(days: 20)))
          .hasProAccess,
      isTrue,
    );
  });

  test('a grant with no expiry stays active (comp account)', () {
    expect(profile(isPro: true).hasProAccess, isTrue);
  });

  test('just-expired keeps access through the grace window', () {
    expect(
      profile(isPro: true, expiresAt: now.subtract(const Duration(hours: 12)))
          .hasProAccess,
      isTrue,
      reason: 'a renewal that has not synced yet must not lock a payer out',
    );
  });

  test('well past expiry loses access', () {
    expect(
      profile(isPro: true, expiresAt: now.subtract(const Duration(days: 10)))
          .hasProAccess,
      isFalse,
    );
  });

  test('expiry survives a round trip through storage', () {
    final expires = DateTime.parse('2027-01-15T10:30:00.000Z');
    final restored =
        UserProfile.fromJson(profile(isPro: true, expiresAt: expires).toJson());
    expect(restored.isPro, isTrue);
    expect(restored.proExpiresAt, expires);
  });
}
