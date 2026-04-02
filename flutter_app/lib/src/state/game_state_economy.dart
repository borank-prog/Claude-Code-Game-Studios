// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateEconomy on _GameStateBase {
  Future<String> buyVipHeal() async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    _applyOfflineRegeneration();
    final snapshot = _premiumSnapshotPlayer();
    final result = _premiumShopService.buyVipHeal(snapshot);
    if (!result.success) {
      return tt(
        'Yeterli altının yok. VIP Tedavi için $vipHealGoldCost Altın gerekli.',
        'Not enough gold. VIP Heal requires $vipHealGoldCost gold.',
      );
    }

    _applyPremiumSnapshotPlayer(snapshot);
    hospitalUntilEpoch = 0;
    _queueEvent('premium_vip_heal', {'costGold': result.spentGold});
    _addNews(
      tt('VIP Tedavi', 'VIP Heal'),
      tt(
        '${result.spentGold} Altın ile can/enerji fulledin ve 2 saat kalkan açtın.',
        'With ${result.spentGold} gold, HP/energy were fully restored and a 2h shield was activated.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '⚕️ VIP Tedavi aktif: Can + Enerji tam, 2 saat kalkan.',
      '⚕️ VIP Heal active: HP + Energy full, 2h shield.',
    );
  }

  Future<String> buyEnergyRush() async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    _applyOfflineRegeneration();
    final snapshot = _premiumSnapshotPlayer();
    final result = _premiumShopService.buyEnergyRush(snapshot);
    if (!result.success) {
      return tt(
        'Yeterli altının yok. Adrenalin İğnesi için $energyRushGoldCost Altın gerekli.',
        'Not enough gold. Energy Rush requires $energyRushGoldCost gold.',
      );
    }

    _applyPremiumSnapshotPlayer(snapshot);
    _queueEvent('premium_energy_rush', {'costGold': result.spentGold});
    _addNews(
      tt('Adrenalin İğnesi', 'Adrenaline Shot'),
      tt(
        '${result.spentGold} Altın harcayıp enerjiyi fulledin ve canını toparladın.',
        'You spent ${result.spentGold} gold to fully refill energy and recover HP.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '⚡ Enerji tam doldu, ekstra can yenilemesi alındı.',
      '⚡ Energy is full, plus bonus HP recovery applied.',
    );
  }

  Future<String> buyVipShield() async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final todayKey = _turkeyDayKeyFromEpoch(now);
    if (vipShieldLastUseDayKey == todayKey) {
      return tt(
        'VIP koruma kalkanını bugün zaten kullandın. Yeni kullanım için yarını bekle.',
        'You already used VIP shield today. Wait until tomorrow for the next use.',
      );
    }
    final snapshot = _premiumSnapshotPlayer();
    final result = _premiumShopService.buyVipShield(snapshot, nowEpoch: now);
    if (!result.success) {
      return tt(
        'Yeterli altının yok. 6 saatlik kalkan için $vipShieldGoldCost Altın gerekli.',
        'Not enough gold. 6h shield requires $vipShieldGoldCost gold.',
      );
    }

    _applyPremiumSnapshotPlayer(snapshot);
    vipShieldLastUseDayKey = todayKey;
    _queueEvent('premium_shield', {
      'costGold': result.spentGold,
      'until': result.newShieldUntilEpoch,
    });
    _addNews(
      tt('VIP Koruma Kalkanı', 'VIP Shield'),
      tt(
        '6 saatlik koruma açıldı. Bu sürede sana saldırı engellenir.',
        '6-hour protection enabled. Attacks are blocked during this time.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '🛡️ VIP Kalkan aktif: 6 saat saldırı koruması.',
      '🛡️ VIP Shield active: 6h attack protection.',
    );
  }

  Future<String> openSmugglerCrate() async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    const commonPool = <String>[
      'musta',
      'caki',
      'sopa',
      'pala',
      'tabanca_9mm',
      'deri_ceket',
      'klasik_araba_sv1',
    ];

    final snapshot = _premiumSnapshotPlayer();
    final result = _premiumShopService.openSmugglerCrate(
      snapshot,
      commonPool: commonPool,
      jackpotItemId: 'altipatlar',
    );

    if (!result.success) {
      lastCrateRewardItemId = '';
      lastCrateJackpot = false;
      lastCrateDuplicateCompensation = 0;
      return tt(
        'Yeterli altının yok. Kaçakçı Sandığı için $smugglerCrateGoldCost Altın gerekli.',
        'Not enough gold. Smuggler Crate requires $smugglerCrateGoldCost gold.',
      );
    }

    _applyPremiumSnapshotPlayer(snapshot);

    final rewardId = result.rewardItemId ?? '';
    final rewardItem = _getItem(rewardId);
    var duplicateCompensation = 0;
    var gotNewItem = false;

    if (rewardItem != null) {
      if ((ownedItems[rewardId] ?? 0) > 0) {
        duplicateCompensation = max(
          250,
          rewardItem.powerBonus * (result.jackpot ? 80 : 25),
        );
        cash += duplicateCompensation;
      } else {
        ownedItems[rewardId] = 1;
        itemLevels[rewardId] = max(2, itemLevels[rewardId] ?? 1);
        itemDurabilityMap[rewardId] = _GameStateBase._maxItemDurability;
        _autoEquip(rewardItem);
        gotNewItem = true;
      }
    }
    lastCrateRewardItemId = rewardId;
    lastCrateJackpot = result.jackpot;
    lastCrateDuplicateCompensation = duplicateCompensation;

    _queueEvent('premium_crate_open', {
      'costGold': result.spentGold,
      'rewardItemId': rewardId,
      'jackpot': result.jackpot,
      'duplicateCompensation': duplicateCompensation,
    });

    if (result.jackpot) {
      _addNews(
        tt('JACKPOT!', 'JACKPOT!'),
        tt(
          'Kaçakçı Sandığı\'ndan efsanevi ödül çıktı: ${rewardItem != null ? itemName(rewardItem) : rewardId}',
          'Legendary reward dropped from Smuggler Crate: ${rewardItem != null ? itemName(rewardItem) : rewardId}',
        ),
      );
    } else {
      _addNews(
        tt('Kaçakçı Sandığı', 'Smuggler Crate'),
        tt(
          'Sandıktan ${rewardItem != null ? itemName(rewardItem) : rewardId} çıktı.',
          'You pulled ${rewardItem != null ? itemName(rewardItem) : rewardId} from the crate.',
        ),
      );
    }

    await _save();
    _syncOnlineSoon();
    notifyListeners();

    if (rewardItem == null) {
      return tt(
        'Sandık açıldı ama geçersiz ödül döndü.',
        'Crate opened but reward data was invalid.',
      );
    }

    if (duplicateCompensation > 0) {
      return tt(
        '🎁 ${itemName(rewardItem)} tekrar çıktı. Yerine +\$$duplicateCompensation verildi.',
        '🎁 Duplicate ${itemName(rewardItem)} converted to +\$$duplicateCompensation.',
      );
    }

    if (result.jackpot) {
      return tt(
        '💥 JACKPOT! ${itemName(rewardItem)} çetene katıldı!',
        '💥 JACKPOT! ${itemName(rewardItem)} joined your loadout!',
      );
    }

    return gotNewItem
        ? tt(
            '🎁 ${itemName(rewardItem)} kazandın.',
            '🎁 You won ${itemName(rewardItem)}.',
          )
        : tt('Sandık açıldı.', 'Crate opened.');
  }

  Future<String> buyPremiumWeaponDirect() async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    if ((ownedItems['altin_deagle'] ?? 0) > 0) {
      return tt(
        'Altın Çöl Kartalı zaten envanterinde.',
        'Golden Desert Eagle is already in your inventory.',
      );
    }

    final snapshot = _premiumSnapshotPlayer();
    final result = _premiumShopService.buyPremiumWeapon(snapshot);
    if (!result.success) {
      return tt(
        'Yeterli altının yok. Altın Çöl Kartalı için $premiumWeaponGoldCost Altın gerekli.',
        'Not enough gold. Golden Desert Eagle requires $premiumWeaponGoldCost gold.',
      );
    }

    _applyPremiumSnapshotPlayer(snapshot);
    final rewardId = result.rewardItemId ?? 'altin_deagle';
    final rewardItem = _getItem(rewardId);
    if (rewardItem != null) {
      ownedItems[rewardId] = 1;
      itemLevels[rewardId] = max(3, itemLevels[rewardId] ?? 1);
      itemDurabilityMap[rewardId] = _GameStateBase._maxItemDurability;
      _autoEquip(rewardItem);
    }

    _queueEvent('premium_weapon_buy', {
      'costGold': result.spentGold,
      'itemId': rewardId,
      'powerBoost': result.powerBoost,
    });
    _addNews(
      tt('VIP Ekipman', 'VIP Gear'),
      tt(
        'Altın Çöl Kartalı satın alındı (+900 Güç, Sv.3).',
        'Golden Desert Eagle purchased (+900 Power, Lv.3).',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '🔫 Altın Çöl Kartalı envantere eklendi (+900 Güç, Sv.3).',
      '🔫 Golden Desert Eagle added (+900 Power, Lv.3).',
    );
  }

  Future<String> buyVipWeaponById(String itemId) async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    final item = _getItem(itemId);
    if (item == null) {
      return tt('Geçersiz eşya.', 'Invalid item.');
    }
    if (item.costGold <= 0) {
      return tt(
        'Bu eşya VIP altın eşyası değil.',
        'This item is not a VIP gold item.',
      );
    }
    if ((ownedItems[item.id] ?? 0) > 0) {
      return tt(
        '${itemName(item)} zaten envanterinde.',
        '${itemName(item)} is already in your inventory.',
      );
    }
    if (gold < item.costGold) {
      return tt(
        'Yeterli altının yok. ${item.costGold} Altın gerekli.',
        'Not enough gold. ${item.costGold} gold required.',
      );
    }

    gold -= item.costGold;
    ownedItems[item.id] = 1;
    itemLevels[item.id] = max(2, itemLevels[item.id] ?? 1);
    itemDurabilityMap[item.id] = _GameStateBase._maxItemDurability;
    _autoEquip(item);

    _queueEvent('vip_weapon_buy', {
      'itemId': item.id,
      'costGold': item.costGold,
      'powerBoost': item.powerBonus,
    });
    _addNews(
      tt('VIP Ekipman', 'VIP Gear'),
      tt(
        '${itemName(item)} satın alındı (+${item.powerBonus} Güç, Sv.2).',
        '${itemName(item)} purchased (+${item.powerBonus} Power, Lv.2).',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '🔫 ${itemName(item)} envantere eklendi (+${item.powerBonus} Güç, Sv.2).',
      '🔫 ${itemName(item)} added to inventory (+${item.powerBonus} Power, Lv.2).',
    );
  }

  Future<bool> buyItem(String itemId) async {
    if (isActionLocked) return false;
    final item = _getItem(itemId);
    if (item == null) return false;
    if (level < item.reqLevel) return false;

    final alreadyOwned = (ownedItems[item.id] ?? 0) > 0;
    if (alreadyOwned) return false;

    if (item.costGold > 0) {
      if (gold < item.costGold) return false;
      gold -= item.costGold;
    } else {
      if (cash < item.costCash) return false;
      cash -= item.costCash;
    }

    ownedItems[item.id] = 1;
    itemLevels[item.id] = max(1, itemLevels[item.id] ?? 1);
    itemDurabilityMap[item.id] = _GameStateBase._maxItemDurability;
    _autoEquip(item);

    _queueEvent('shop_buy', {'itemId': item.id});
    _addNews(
      tt('Yeni Ekipman', 'New Gear'),
      tt('${itemName(item)} satın alındı.', '${itemName(item)} was purchased.'),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  Future<bool> upgradeItem(String itemId) async {
    if (isActionLocked) return false;
    if ((ownedItems[itemId] ?? 0) <= 0) return false;
    final item = _getItem(itemId);
    if (item == null) return false;
    final current = itemLevels[itemId] ?? 1;
    final maxLevel = item.costGold > 0 ? 7 : 5;
    if (current >= maxLevel) return false;

    final cashCost = max(
      250,
      (item.costCash > 0 ? item.costCash : item.powerBonus * 60) +
          current * 200,
    );
    final goldCost = max(5, (cashCost / 900).round());

    if (cash < cashCost || gold < goldCost) return false;
    cash -= cashCost;
    gold -= goldCost;

    itemLevels[itemId] = current + 1;
    _queueEvent('item_upgrade', {'itemId': itemId, 'level': current + 1});
    _addNews(
      tt('Yükseltme', 'Upgrade'),
      tt(
        '${itemName(item)} Sv.${current + 1} oldu.',
        '${itemName(item)} reached Lv.${current + 1}.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  Future<bool> buyBuilding(String buildingId) async {
    if (isActionLocked) return false;
    final building = StaticData.buildings.firstWhere(
      (b) => b.id == buildingId,
      orElse: () => const BuildingDef(
        id: '',
        name: '',
        costCash: 0,
        costGold: 0,
        hourlyIncome: 0,
      ),
    );
    if (building.id.isEmpty) return false;
    if ((ownedBuildings[buildingId] ?? 0) > 0) return false;

    if (building.costGold > 0) {
      if (gold < building.costGold) return false;
      gold -= building.costGold;
    } else {
      if (cash < building.costCash) return false;
      cash -= building.costCash;
    }

    ownedBuildings[building.id] = 1;
    buildingLastCollectEpoch[building.id] =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _trackDaily('building_action', 1);
    _queueEvent('building_buy', {'buildingId': building.id});
    _addNews(
      tt('Yeni Mekan', 'New Property'),
      tt(
        '${buildingName(building)} satın alındı.',
        '${buildingName(building)} was purchased.',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  int collectAllBuildingIncome() {
    if (isActionLocked) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var total = 0;

    for (final b in StaticData.buildings) {
      if ((ownedBuildings[b.id] ?? 0) <= 0) continue;
      final last = buildingLastCollectEpoch[b.id] ?? now;
      final seconds = max(0, now - last);
      final hours = seconds ~/ 3600;
      if (hours <= 0) continue;
      total += b.hourlyIncome * hours;
      buildingLastCollectEpoch[b.id] = now;
    }

    if (total > 0) {
      cash += total;
      _trackDaily('cash_earned', total);
      _queueEvent('building_collect', {'cash': total});
      _addNews(
        tt('Haraç Toplandı', 'Tribute Collected'),
        tt('+\$$total kasaya girdi.', '+\$$total added to cashbox.'),
      );
      _save();
      _syncOnlineSoon();
      notifyListeners();
    }
    return total;
  }

  Future<bool> equipOwnedItem(String itemId, {String? preferredSlot}) async {
    if (isActionLocked) return false;
    if ((ownedItems[itemId] ?? 0) <= 0) return false;
    _ensureOwnedItemDurability(itemId);
    if (itemDurabilityPercent(itemId) <= 0) return false;
    final item = _getItem(itemId);
    if (item == null) return false;

    final targetSlot = suggestedSlotForItem(item, preferredSlot: preferredSlot);
    if (!equipped.containsKey(targetSlot)) return false;

    equipped[targetSlot] = itemId;

    // Aynı eşyayı farklı slotlarda tekrar takılı tutma.
    for (final entry in equipped.entries.toList()) {
      if (entry.key == targetSlot) continue;
      if (entry.value == itemId) {
        equipped[entry.key] = '';
      }
    }

    _queueEvent('item_equip', {'itemId': itemId, 'slot': targetSlot});
    _addNews(
      tt('Ekipman Kuşanıldı', 'Gear Equipped'),
      tt(
        '${itemName(item)} -> ${slotName(targetSlot)}',
        '${itemName(item)} -> ${slotName(targetSlot)}',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  Future<String> repairItemWithGold(String itemId) async {
    if (isActionLocked) {
      return actionLockMessage;
    }
    final item = _getItem(itemId);
    if (item == null || (ownedItems[itemId] ?? 0) <= 0) {
      return tt('Eşya bulunamadı.', 'Item not found.');
    }
    _ensureOwnedItemDurability(itemId);
    final currentDurability = itemDurabilityPercent(itemId);
    if (currentDurability >= _GameStateBase._maxItemDurability) {
      return tt(
        'Bu eşya zaten tam sağlam.',
        'This item is already fully repaired.',
      );
    }
    final repairCost = repairItemGoldCost(itemId);
    if (repairCost <= 0) {
      return tt('Bu eşya tamir edilemez.', 'This item cannot be repaired.');
    }
    if (gold < repairCost) {
      return tt(
        'Yeterli altın yok. Tamir için $repairCost Altın gerekli.',
        'Not enough gold. Repair requires $repairCost gold.',
      );
    }

    gold -= repairCost;
    itemDurabilityMap[itemId] = _GameStateBase._maxItemDurability;
    _queueEvent('item_repaired', {
      'itemId': itemId,
      'costGold': repairCost,
      'fromDurability': currentDurability,
      'toDurability': _GameStateBase._maxItemDurability,
    });
    _addNews(
      tt('Eşya Tamir Edildi', 'Item Repaired'),
      tt(
        '${itemName(item)} tamir edildi (%$currentDurability -> %${_GameStateBase._maxItemDurability}).',
        '${itemName(item)} repaired (%$currentDurability -> %${_GameStateBase._maxItemDurability}).',
      ),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return tt(
      '🔧 ${itemName(item)} tamir edildi (-$repairCost Altın).',
      '🔧 ${itemName(item)} repaired (-$repairCost gold).',
    );
  }

  Future<void> unequipSlot(String slot) async {
    if (isActionLocked) return;
    if (!equipped.containsKey(slot)) return;
    if ((equipped[slot] ?? '').isEmpty) return;
    equipped[slot] = '';
    _queueEvent('item_unequip', {'slot': slot});
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }
}
