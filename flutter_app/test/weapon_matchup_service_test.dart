import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/src/services/weapon_matchup_service.dart';

void main() {
  group('WeaponMatchupService', () {
    test('melee has edge over sniper', () {
      final effect = WeaponMatchupService.evaluate(
        attackerWeaponId: 'pala',
        targetWeaponId: 'keskin_nisanci',
      );

      expect(effect.powerPct, greaterThan(0));
      expect(effect.totalPct, greaterThan(0));
    });

    test('shotgun counters melee at close clash profile', () {
      final effect = WeaponMatchupService.evaluate(
        attackerWeaponId: 'pompali',
        targetWeaponId: 'musta',
      );

      expect(effect.totalPct, greaterThan(0));
    });

    test('defaultWeaponIdForPower scales with power tiers', () {
      expect(WeaponMatchupService.defaultWeaponIdForPower(12), 'musta');
      expect(WeaponMatchupService.defaultWeaponIdForPower(300), 'uzi');
      expect(
        WeaponMatchupService.defaultWeaponIdForPower(12000),
        'roketatar',
      );
    });
  });
}
