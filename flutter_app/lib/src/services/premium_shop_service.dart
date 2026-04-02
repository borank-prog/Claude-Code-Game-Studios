import 'dart:math';

import '../data/player_model.dart';

class PremiumShopResult {
  const PremiumShopResult({
    required this.success,
    required this.code,
    this.spentGold = 0,
    this.rewardItemId,
    this.jackpot = false,
    this.newShieldUntilEpoch = 0,
    this.powerBoost = 0,
  });

  final bool success;
  final String code;
  final int spentGold;
  final String? rewardItemId;
  final bool jackpot;
  final int newShieldUntilEpoch;
  final int powerBoost;
}

class PremiumShopService {
  PremiumShopService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const int vipHealGoldCost = 8;
  static const int energyRushGoldCost = 3;
  static const int vipShieldGoldCost = 45;
  static const int smugglerCrateGoldCost = 520;
  static const int premiumWeaponGoldCost = 55;

  static const double jackpotChance = 0.006;

  PremiumShopResult buyVipHeal(Player player) {
    if (player.gold < vipHealGoldCost) {
      return const PremiumShopResult(success: false, code: 'insufficient_gold');
    }
    player.gold -= vipHealGoldCost;
    player.currentTP = player.maxTP;
    player.currentEnerji = player.maxEnerji;
    player.hospitalizedUntil = null;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final baseEpoch = max(nowEpoch, player.shieldUntilEpoch);
    player.shieldUntilEpoch = baseEpoch + (2 * 60 * 60);
    return const PremiumShopResult(
      success: true,
      code: 'vip_heal_applied',
      spentGold: vipHealGoldCost,
    );
  }

  PremiumShopResult buyEnergyRush(Player player) {
    if (player.gold < energyRushGoldCost) {
      return const PremiumShopResult(success: false, code: 'insufficient_gold');
    }
    player.gold -= energyRushGoldCost;
    player.currentEnerji = player.maxEnerji;
    player.currentTP = min(player.maxTP, player.currentTP + 35);
    return const PremiumShopResult(
      success: true,
      code: 'energy_rush_applied',
      spentGold: energyRushGoldCost,
    );
  }

  PremiumShopResult buyVipShield(Player player, {required int nowEpoch}) {
    if (player.gold < vipShieldGoldCost) {
      return const PremiumShopResult(success: false, code: 'insufficient_gold');
    }

    player.gold -= vipShieldGoldCost;
    final baseEpoch = max(nowEpoch, player.shieldUntilEpoch);
    final shieldEnd = baseEpoch + (6 * 60 * 60);
    player.shieldUntilEpoch = shieldEnd;

    return PremiumShopResult(
      success: true,
      code: 'shield_applied',
      spentGold: vipShieldGoldCost,
      newShieldUntilEpoch: shieldEnd,
    );
  }

  PremiumShopResult openSmugglerCrate(
    Player player, {
    required List<String> commonPool,
    String jackpotItemId = 'roketatar',
  }) {
    if (player.gold < smugglerCrateGoldCost) {
      return const PremiumShopResult(success: false, code: 'insufficient_gold');
    }
    if (commonPool.isEmpty) {
      return const PremiumShopResult(success: false, code: 'empty_pool');
    }

    player.gold -= smugglerCrateGoldCost;

    final rolledJackpot = _random.nextDouble() < jackpotChance;
    if (rolledJackpot) {
      return PremiumShopResult(
        success: true,
        code: 'crate_opened',
        spentGold: smugglerCrateGoldCost,
        rewardItemId: jackpotItemId,
        jackpot: true,
      );
    }

    final picked = commonPool[_random.nextInt(commonPool.length)];
    return PremiumShopResult(
      success: true,
      code: 'crate_opened',
      spentGold: smugglerCrateGoldCost,
      rewardItemId: picked,
      jackpot: false,
    );
  }

  PremiumShopResult buyPremiumWeapon(Player player) {
    if (player.gold < premiumWeaponGoldCost) {
      return const PremiumShopResult(success: false, code: 'insufficient_gold');
    }
    player.gold -= premiumWeaponGoldCost;
    return const PremiumShopResult(
      success: true,
      code: 'premium_weapon_bought',
      spentGold: premiumWeaponGoldCost,
      rewardItemId: 'altin_deagle',
      powerBoost: 500,
    );
  }
}
