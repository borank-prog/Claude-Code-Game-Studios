import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/src/state/game_state.dart';
import 'package:flutter_app/src/data/game_models.dart';
import 'package:flutter_app/src/data/static_data.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameState basics', () {
    test('default values', () {
      final gs = GameState();
      expect(gs.level, 1);
      expect(gs.cash, 1500);
      expect(gs.gold, 0);
      expect(gs.currentTP, 100);
      expect(gs.maxTP, 100);
      expect(gs.currentEnerji, 100);
      expect(gs.maxEnerji, 100);
      expect(gs.loggedIn, false);
      expect(gs.languageCode, 'tr');
    });

    test('tt returns correct language string', () {
      final gs = GameState();
      expect(gs.tt('Türkçe', 'English'), 'Türkçe');
      gs.languageCode = 'en';
      expect(gs.tt('Türkçe', 'English'), 'English');
    });

    test('rank starts at 0 for level 1', () {
      final gs = GameState();
      expect(gs.rank, 0);
      expect(gs.rankName, 'Çaylak');
    });

    test('xpToNext starts with beginner-friendly threshold', () {
      final gs = GameState();
      expect(gs.xpToNext, lessThanOrEqualTo(150));
    });

    test('rank increases with level', () {
      final gs = GameState();
      gs.level = 10;
      expect(gs.rank, greaterThan(0));
    });

    test('needsOnboarding is false when not logged in', () {
      final gs = GameState();
      expect(gs.needsOnboarding, false);
    });

    test('needsOnboarding is true when logged in but not onboarded', () {
      final gs = GameState();
      gs.loggedIn = true;
      gs.onboardingCompleted = false;
      gs.nicknameChosen = false;
      expect(gs.needsOnboarding, true);
    });

    test('needsOnboarding is false when fully onboarded', () {
      final gs = GameState();
      gs.loggedIn = true;
      gs.onboardingCompleted = true;
      gs.nicknameChosen = true;
      expect(gs.needsOnboarding, false);
    });

    test('avatar returns correct class', () {
      final gs = GameState();
      gs.selectedAvatarId = 'baba';
      expect(gs.avatar.id, 'baba');
      expect(gs.avatar.powerMult, 1.05);
    });

    test('avatar falls back to first when invalid id', () {
      final gs = GameState();
      gs.selectedAvatarId = 'nonexistent';
      expect(gs.avatar.id, StaticData.avatarClasses.first.id);
    });
  });

  group('Penalty system', () {
    test('jailSecondsLeft returns 0 when not jailed', () {
      final gs = GameState();
      expect(gs.jailSecondsLeft, 0);
    });

    test('jailSecondsLeft returns positive when jailed', () {
      final gs = GameState();
      gs.jailUntilEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;
      expect(gs.jailSecondsLeft, greaterThan(0));
      expect(gs.jailSecondsLeft, lessThanOrEqualTo(1800));
    });

    test('hospitalSecondsLeft returns 0 when not hospitalized', () {
      final gs = GameState();
      expect(gs.hospitalSecondsLeft, 0);
    });

    test('hospitalSecondsLeft returns positive when hospitalized', () {
      final gs = GameState();
      gs.hospitalUntilEpoch =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;
      expect(gs.hospitalSecondsLeft, greaterThan(0));
    });

    test('isHospitalized returns correct value', () {
      final gs = GameState();
      expect(gs.isHospitalized, false);
      gs.hospitalUntilEpoch =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;
      expect(gs.isHospitalized, true);
    });
  });

  group('Power calculation', () {
    test('totalPower includes base stats', () {
      final gs = GameState();
      expect(gs.totalPower, greaterThan(0));
    });

    test('totalPower increases with equipment', () {
      final gs = GameState();
      final basePower = gs.totalPower;
      // Simulate owning and equipping an item
      gs.ownedItems['tabanca_9mm'] = 1;
      gs.equipped['weapon'] = 'tabanca_9mm';
      expect(gs.totalPower, greaterThan(basePower));
    });
  });

  group('Gang system', () {
    test('hasGang returns false by default', () {
      final gs = GameState();
      expect(gs.hasGang, false);
      expect(gs.gangId, '');
    });

    test('hasGang returns true when gang set', () {
      final gs = GameState();
      gs.currentGang = {'id': 'test_gang_1', 'name': 'Test Gang'};
      expect(gs.hasGang, true);
      expect(gs.gangId, 'test_gang_1');
    });
  });

  group('Daily system', () {
    test('dailyTaskCards returns 4 tasks', () {
      final gs = GameState();
      expect(gs.dailyTaskCards.length, 4);
    });

    test('dailyTaskCards have correct structure', () {
      final gs = GameState();
      for (final card in gs.dailyTaskCards) {
        expect(card.containsKey('id'), true);
        expect(card.containsKey('title'), true);
        expect(card.containsKey('target'), true);
        expect(card.containsKey('progress'), true);
        expect(card.containsKey('claimed'), true);
        expect(card.containsKey('rewardCash'), true);
      }
    });
  });

  group('Mission completion', () {
    test('completeMission fails when in jail', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.jailUntilEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;

      final mission = StaticData.missions.first;
      final result = await gs.completeMission(mission);

      expect(result.success, false);
      expect(result.sentToJail, true);
    });

    test('completeMission fails when hospitalized', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.hospitalUntilEpoch =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;

      final mission = StaticData.missions.first;
      final result = await gs.completeMission(mission);

      expect(result.success, false);
      expect(result.sentToHospital, true);
    });

    test('completeMission fails when not enough energy', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.currentEnerji = 0;

      final mission = StaticData.missions.first;
      final result = await gs.completeMission(mission);

      expect(result.success, false);
      expect(result.message.isNotEmpty, true);
    });

    test('completeMission deducts energy', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.currentEnerji = 100;

      final mission = StaticData.missions.first;
      final energyBefore = gs.currentEnerji;
      await gs.completeMission(mission);

      expect(gs.currentEnerji, lessThan(energyBefore));
    });
  });

  group('Economy', () {
    test('one-time starter gifts are applied once and persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final first = GameState();
      await first.initialize();
      final firstGold = first.gold;
      final firstCash = first.cash;

      expect(firstGold, greaterThanOrEqualTo(1000000));
      expect(firstCash, greaterThanOrEqualTo(1000000));

      final second = GameState();
      await second.initialize();
      expect(second.gold, firstGold);
      expect(second.cash, firstCash);
    });

    test('buyItem fails with insufficient cash', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.cash = 0;
      gs.gold = 0;

      final item = StaticData.shopItems.first;
      final ok = await gs.buyItem(item.id);
      expect(ok, false);
    });

    test('buyItem succeeds with enough resources', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.cash = 999999;
      gs.gold = 999;
      gs.level = 50;

      final item = StaticData.shopItems.first;
      final ok = await gs.buyItem(item.id);
      expect(ok, true);
      expect(gs.ownedItems[item.id], greaterThanOrEqualTo(1));
    });

    test('daily login reward increases cash', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      final cashBefore = gs.cash;

      await gs.claimDailyLoginReward();

      expect(gs.cash, greaterThan(cashBefore));
      expect(gs.dailyLoginClaimed, true);
    });

    test('daily login reward cannot be claimed twice', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();

      final result1 = await gs.claimDailyLoginReward();
      final cashAfterFirst = gs.cash;
      final result2 = await gs.claimDailyLoginReward();

      expect(result1.isNotEmpty, true);
      expect(gs.cash, cashAfterFirst); // no change on second claim
      expect(result2.contains('zaten') || result2.contains('already'), true);
    });

    test('payJailWithGold works when jailed and has gold', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.jailUntilEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;
      gs.gold = 100;

      await gs.payJailWithGold();
      expect(gs.jailSecondsLeft, 0);
    });

    test('payHospitalWithGold works when hospitalized and has gold', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.hospitalUntilEpoch =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1800;
      gs.gold = 100;

      await gs.payHospitalWithGold();
      expect(gs.hospitalSecondsLeft, 0);
    });
  });

  group('Stat system', () {
    test('spendStatPoint power increases power stat and total power', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.statPoints = 1;
      final beforePower = gs.totalPower;

      final ok = await gs.spendStatPoint('power');

      expect(ok, true);
      expect(gs.statPoints, 0);
      expect(gs.statPower, 1);
      expect(gs.totalPower, greaterThan(beforePower));
    });

    test('spendStatPoint vitality increases hp cap and heals a bit', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.statPoints = 1;
      gs.currentTP = 60;
      gs.maxTP = 100;

      final ok = await gs.spendStatPoint('vitality');

      expect(ok, true);
      expect(gs.statVitality, 1);
      expect(gs.maxTP, 106);
      expect(gs.currentTP, 66);
    });

    test(
      'spendStatPoint energy increases energy cap and refills a bit',
      () async {
        SharedPreferences.setMockInitialValues({});
        final gs = GameState();
        await gs.initialize();
        gs.statPoints = 1;
        gs.currentEnerji = 50;
        gs.maxEnerji = 100;

        final ok = await gs.spendStatPoint('energy');

        expect(ok, true);
        expect(gs.statEnergy, 1);
        expect(gs.maxEnerji, 105);
        expect(gs.currentEnerji, 55);
      },
    );
  });

  group('Equipment slot helper', () {
    test('suggestedSlotForItem routes melee item to knife slot', () {
      final gs = GameState();
      const meleeItem = ItemDef(
        id: 'musta_test',
        name: 'Musta',
        type: 'weapon',
        powerBonus: 10,
        costCash: 100,
        costGold: 0,
        reqLevel: 1,
        iconAsset: 'assets/art/items/profile_cards/bos_slot_1.png',
      );

      final slot = gs.suggestedSlotForItem(meleeItem);
      expect(slot, 'knife');
    });

    test('equipOwnedItem removes duplicate item from old slot', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      gs.ownedItems['musta'] = 1;
      gs.equipped['weapon'] = 'musta';

      final ok = await gs.equipOwnedItem('musta', preferredSlot: 'knife');

      expect(ok, true);
      expect(gs.equipped['knife'], 'musta');
      expect(gs.equipped['weapon'], isEmpty);
    });

    test('vehicle item is routed to vehicle slot', () {
      final gs = GameState();
      const vehicleItem = ItemDef(
        id: 'klasik_araba_sv1',
        name: 'Klasik Araba - Sv.1',
        type: 'vehicle',
        powerBonus: 140,
        costCash: 75000,
        costGold: 0,
        reqLevel: 6,
        iconAsset: 'assets/art/items/custom_profile/eq_car.png',
      );
      final slot = gs.suggestedSlotForItem(vehicleItem);
      expect(slot, 'vehicle');
    });

    test('equipped vehicle lowers attack energy cost', () async {
      SharedPreferences.setMockInitialValues({});
      final gs = GameState();
      await gs.initialize();
      final baseCost = gs.attackEnergyCost;
      gs.ownedItems['klasik_araba_sv1'] = 1;
      final ok = await gs.equipOwnedItem('klasik_araba_sv1');
      expect(ok, true);
      expect(gs.equipped['vehicle'], 'klasik_araba_sv1');
      expect(gs.attackEnergyCost, lessThan(baseCost));
      expect(gs.attackEnergyCost, 25);
    });
  });

  group('Static data integrity', () {
    test('avatarClasses are not empty', () {
      expect(StaticData.avatarClasses.isNotEmpty, true);
    });

    test('shopItems are not empty', () {
      expect(StaticData.shopItems.isNotEmpty, true);
    });

    test('missions are not empty', () {
      expect(StaticData.missions.isNotEmpty, true);
    });

    test('buildings are not empty', () {
      expect(StaticData.buildings.isNotEmpty, true);
    });

    test('all missions have valid difficulty', () {
      for (final m in StaticData.missions) {
        expect(
          ['easy', 'medium', 'hard'].contains(m.difficulty),
          true,
          reason: 'Mission ${m.id} has invalid difficulty: ${m.difficulty}',
        );
      }
    });

    test('all shop items have positive power bonus', () {
      for (final item in StaticData.shopItems) {
        expect(
          item.powerBonus > 0,
          true,
          reason: 'Item ${item.id} has non-positive power: ${item.powerBonus}',
        );
      }
    });

    test('rankNames has 20 entries', () {
      expect(StaticData.rankNames.length, 20);
    });
  });
}
