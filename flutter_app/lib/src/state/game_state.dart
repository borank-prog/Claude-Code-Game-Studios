// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/achievement_data.dart';
import '../data/game_models.dart';
import '../data/player_model.dart';
import '../data/static_data.dart';
import '../services/online_service.dart';
import '../services/notification_service.dart';
import '../services/premium_shop_service.dart';
import '../services/regeneration_service.dart';
import '../services/weapon_matchup_service.dart';

part 'game_state_auth.dart';
part 'game_state_combat.dart';
part 'game_state_economy.dart';
part 'game_state_missions.dart';
part 'game_state_social.dart';
part 'game_state_achievements.dart';

// ---------------------------------------------------------------------------
// GameState = _GameStateBase + feature mixins
// ---------------------------------------------------------------------------

class GameState extends _GameStateBase
    with
        _GameStateAuth,
        _GameStateCombat,
        _GameStateEconomy,
        _GameStateMissions,
        _GameStateSocial,
        _GameStateAchievements {}

// ---------------------------------------------------------------------------
// Base: fields, getters, shared helpers, persistence
// ---------------------------------------------------------------------------

class _GameStateBase extends ChangeNotifier {
  static const _storageKey = 'cartelhood_flutter_save_v2';
  static const _saveVersion = 11;
  static const _maxItemDurability = 100;
  static const _oneTimeGoldGiftAmount = 1000000;
  static const _oneTimeCashGiftAmount = 1000000;
  static const _penaltyDurationSec = 2700;
  static const _missionFailXpRatio = 0.2;
  static const _pendingQueueMax = 200;
  static const _pendingQueueTtlMs = 7 * 24 * 60 * 60 * 1000;
  static const Duration _authPostStepTimeout = Duration(seconds: 2);
  static const List<String> _equipmentSlots = [
    'weapon',
    'armor',
    'knife',
    'vehicle',
  ];
  static const Map<String, int> _missionWearBySlot = {
    'weapon': 2,
    'armor': 1,
    'knife': 1,
    'vehicle': 1,
  };
  static const Map<String, int> _attackWearBySlot = {
    'weapon': 4,
    'armor': 2,
    'knife': 2,
    'vehicle': 1,
  };
  static const List<String> _seedBotNames = [
    'Kurt_Memo',
    'Tetikci_Orhan',
    'Baron_Ali',
    'Racon_Selim',
    'Gece_Kargasi',
    'Sokak_Vurgun',
    'Golge',
    'Kasirga_Han',
    'Kral_Panzer',
    'Don_Marco',
    'Mafya_Cem',
    'Demir_Yusuf',
    'Silahsor_Apo',
    'Karanlik_Tolga',
    'Bicakci_Erdem',
    'Bela_Burak',
    'Baba_Rasim',
    'Serseri_Cenk',
    'Reis_Tuna',
    'Vurguncu_Levent',
  ];
  static const String _seedGangA = 'Kuzey Kurtları';
  static const String _seedGangB = 'Gece Baronları';

  final OnlineService _onlineService = OnlineService();
  Timer? _cloudSaveDebounce;
  bool _cloudSaveInFlight = false;

  bool initialized = false;
  bool loggedIn = false;
  bool online = true;
  bool firebaseReady = false;
  String languageCode = 'tr';
  bool musicEnabled = true;
  bool sfxEnabled = true;
  bool notifyEnergyFull = true;
  bool notifyHospitalReady = true;
  bool notifyUnderAttack = true;
  bool notifyGangMessages = true;
  int nameChangeCount = 0;

  String firebaseStatus = '';
  String lastAuthError = '';
  String authMode = 'local';
  String userId = '';

  String playerName = 'Oyuncu';
  String selectedAvatarId = 'baba';
  bool avatarLocked = false;
  bool onboardingCompleted = false;
  bool nicknameChosen = false;

  int level = 1;
  int xp = 0;
  int cash = 1500;
  int gold = 0;
  int maxTP = 100;
  int currentTP = 100;
  int maxEnerji = 100;
  int currentEnerji = 100;
  int stamina = 100;
  int maxStamina = 100;
  int statPoints = 0;
  int statPower = 0;
  int statVitality = 0;
  int statEnergy = 0;
  int lastRegenCheckEpoch = 0;
  int shieldUntilEpoch = 0;

  int hospitalUntilEpoch = 0;
  int jailUntilEpoch = 0;
  bool playerOnline = false;
  int wins = 0;
  int gangWins = 0;
  int lastLoginEpoch = 0;
  int lastLogoutEpoch = 0;
  final List<String> offlineLogs = [];
  final List<String> _sessionOfflineReports = [];

  final Map<String, int> ownedItems = {};
  final Map<String, int> itemLevels = {};
  final Map<String, int> itemDurabilityMap = {};
  final List<String> pendingItemBrokenNotices = [];
  final Map<String, String> equipped = {
    for (final slot in _equipmentSlots) slot: '',
  };

  final Map<String, int> ownedBuildings = {};
  final Map<String, int> buildingLastCollectEpoch = {};

  final List<Map<String, dynamic>> pendingQueue = [];
  final List<String> news = [];
  final Map<String, int> balanceMetrics = {};
  String lastCrateRewardItemId = '';
  bool lastCrateJackpot = false;
  int lastCrateDuplicateCompensation = 0;

  final List<Map<String, dynamic>> friends = [];
  final List<Map<String, dynamic>> incomingRequests = [];
  final List<Map<String, dynamic>> incomingGangInvites = [];
  final List<Map<String, dynamic>> gangJoinRequests = [];
  final List<Map<String, dynamic>> leaderboardRows = [];
  final List<Map<String, dynamic>> discoverableGangs = [];
  final List<Map<String, dynamic>> gangMembers = [];
  Map<String, dynamic>? currentGang;
  int gangRank = 1;
  int gangRespectPoints = 0;
  int gangVault = 25000;
  int localUpdatedAtEpoch = 0;
  String saveOwnerUid = '';
  String dailyDateKey = '';
  final Map<String, int> dailyProgress = {};
  final Map<String, bool> dailyClaimed = {};
  int dailyStreak = 0;
  String lastDailyLoginDate = '';
  bool dailyLoginClaimed = false;
  bool oneTimeGoldGiftGranted = false;
  bool oneTimeCashGiftGranted = false;

  // Achievement system
  final Set<String> unlockedAchievements = {};
  final Set<String> claimedAchievements = {};
  final Map<String, int> achievementCounters = {};

  /// Increment an achievement counter (accessible from all mixins)
  void trackAchievement(String key, [int delta = 1]) {
    achievementCounters[key] = (achievementCounters[key] ?? 0) + delta;
  }

  /// Check achievements after state changes. Overridden by _GameStateAchievements.
  void checkAchievements() {}

  final Random _rng = Random();
  final RegenerationService _regenService = RegenerationService();
  final PremiumShopService _premiumShopService = PremiumShopService();

  // ── Static data ──

  static const Map<String, int> _dailyTargets = {
    'missions_completed': 3,
    'building_action': 1,
    'raid_joined': 1,
    'cash_earned': 100,
  };

  static const Map<String, int> _dailyRewardCash = {
    'missions_completed': 900,
    'building_action': 1200,
    'raid_joined': 1300,
    'cash_earned': 700,
  };

  static const List<String> _balanceMetricKeys = [
    'mission_attempts_total',
    'mission_success_total',
    'mission_fail_total',
    'mission_attempts_easy',
    'mission_attempts_medium',
    'mission_attempts_hard',
    'mission_success_easy',
    'mission_success_medium',
    'mission_success_hard',
    'mission_fail_easy',
    'mission_fail_medium',
    'mission_fail_hard',
    'mission_cash_earned_total',
    'mission_cash_lost_total',
    'mission_xp_earned_total',
    'mission_energy_spent_total',
    'jail_entries_total',
    'hospital_entries_total',
    'jail_skip_gold_spent_total',
    'hospital_skip_gold_spent_total',
  ];

  // ── Getters ──

  AvatarClass get avatar {
    final idx = StaticData.avatarClasses.indexWhere(
      (a) => a.id == selectedAvatarId,
    );
    if (idx >= 0) return StaticData.avatarClasses[idx];
    return StaticData.avatarClasses.first;
  }

  int get xpToNext => _requiredXp(level);

  bool get isEnglish => languageCode == 'en';
  bool get googleSignInReady =>
      firebaseReady && _onlineService.canUseGoogleSignIn;

  String tt(String tr, String en) => isEnglish ? en : tr;

  Map<String, int> get balanceMetricsSnapshot =>
      Map<String, int>.from(balanceMetrics);

  List<Map<String, dynamic>> get dailyTaskCards => [
    {
      'id': 'missions_completed',
      'title': tt('3 görev tamamla', 'Complete 3 missions'),
      'target': _dailyTargets['missions_completed']!,
      'progress': dailyProgress['missions_completed'] ?? 0,
      'claimed': dailyClaimed['missions_completed'] ?? false,
      'rewardCash': _dailyRewardCash['missions_completed']!,
    },
    {
      'id': 'building_action',
      'title': tt('1 bina al / geliştir', 'Buy/upgrade 1 building'),
      'target': _dailyTargets['building_action']!,
      'progress': dailyProgress['building_action'] ?? 0,
      'claimed': dailyClaimed['building_action'] ?? false,
      'rewardCash': _dailyRewardCash['building_action']!,
    },
    {
      'id': 'raid_joined',
      'title': tt('1 çete baskınına katıl', 'Join 1 raid'),
      'target': _dailyTargets['raid_joined']!,
      'progress': dailyProgress['raid_joined'] ?? 0,
      'claimed': dailyClaimed['raid_joined'] ?? false,
      'rewardCash': _dailyRewardCash['raid_joined']!,
    },
    {
      'id': 'cash_earned',
      'title': tt('100 nakit kazan', 'Earn 100 cash'),
      'target': _dailyTargets['cash_earned']!,
      'progress': dailyProgress['cash_earned'] ?? 0,
      'claimed': dailyClaimed['cash_earned'] ?? false,
      'rewardCash': _dailyRewardCash['cash_earned']!,
    },
  ];

  String get displayPlayerName {
    if (playerName == 'Oyuncu' || playerName == 'Player') {
      return tt('Oyuncu', 'Player');
    }
    return playerName;
  }

  String get gangId => currentGang?['id']?.toString() ?? '';
  bool get hasGang => gangId.isNotEmpty;
  bool get isGangLeader {
    if (!hasGang || userId.trim().isEmpty) return false;
    final ownerId = (currentGang?['ownerId']?.toString() ?? '').trim();
    final role = (currentGang?['role']?.toString() ?? '').trim().toLowerCase();
    if (ownerId.isNotEmpty) return ownerId == userId.trim();
    return role == 'lider' || role == 'leader';
  }

  bool get gangInviteOnly => currentGang?['inviteOnly'] == true;
  bool get gangAcceptJoinRequests =>
      currentGang?['acceptJoinRequests'] != false;
  bool get hasOfflineReports => _sessionOfflineReports.isNotEmpty;
  bool get needsOnboarding =>
      loggedIn && (!onboardingCompleted || !nicknameChosen);
  bool get canChangeAvatar => !avatarLocked;

  int get totalGangPower {
    if (gangMembers.isEmpty) return totalPower;
    return gangMembers.fold<int>(
      0,
      (sum, m) => sum + ((m['power'] as num?)?.toInt() ?? 0),
    );
  }

  int get onlineGangMembers {
    if (gangMembers.isEmpty) return 0;
    return gangMembers.where((m) => m['online'] == true).length;
  }

  List<String> takeSessionOfflineReports() {
    final out = List<String>.from(_sessionOfflineReports);
    _sessionOfflineReports.clear();
    return out;
  }

  int get rank {
    const gates = [
      1,
      2,
      3,
      4,
      5,
      6,
      8,
      10,
      12,
      14,
      16,
      18,
      20,
      22,
      24,
      26,
      28,
      30,
      33,
      36,
    ];
    var idx = 0;
    for (var i = 0; i < gates.length; i++) {
      if (level >= gates[i]) idx = i;
    }
    return idx;
  }

  String get rankName {
    const rankNamesEn = <String>[
      'Rookie',
      'Petty Criminal',
      'Pickpocket',
      'Snatcher',
      'Thief',
      'Scammer',
      'Hitman',
      'Dealer',
      'Underground Boss',
      'Captain',
      'Lieutenant',
      'Capo',
      'Advisor',
      'Godfather',
      'Crime Lord',
      'Don',
      'Patron',
      'Big Boss',
      'Cartel Lord',
      'Emperor',
    ];
    return isEnglish ? rankNamesEn[rank] : StaticData.rankNames[rank];
  }

  // ── Translation helpers ──

  String avatarName(AvatarClass c) {
    switch (c.id) {
      case 'baba':
        return tt('Baba', 'The Boss');
      case 'baron':
        return 'Baron';
      case 'firsatci':
        return tt('Fırsatçı', 'Opportunist');
      case 'silahsor':
        return tt('Silahşor', 'Gunman');
      case 'suikastci':
        return tt('Suikastçı', 'Assassin');
      case 'zorba':
        return tt('Zorba', 'Brute');
      default:
        return c.name;
    }
  }

  String itemName(ItemDef item) {
    switch (item.id) {
      case 'musta':
        return tt('Demir Muşta', 'Brass Knuckles');
      case 'caki':
        return tt('Kelebek Çakı', 'Butterfly Knife');
      case 'sopa':
        return tt('Çivili Sopa', 'Spiked Bat');
      case 'pala':
        return tt('Paslı Pala', 'Rusty Machete');
      case 'tabanca_9mm':
        return tt('9mm Tabanca', '9mm Pistol');
      case 'altin_deagle':
        return tt('Altın Çöl Kartalı', 'Golden Desert Eagle');
      case 'altipatlar':
        return tt('Magnum Altıpatlar', 'Magnum Revolver');
      case 'uzi':
        return 'Uzi';
      case 'el_bombasi':
        return tt('El Bombası Seti', 'Grenade Set');
      case 'pompali':
        return tt('Pompalı Tüfek', 'Pump Shotgun');
      case 'ak47':
        return 'AK-47 Kalashnikov';
      case 'c4_patlayici':
        return tt('C4 Patlayıcı', 'C4 Explosive');
      case 'keskin_nisanci':
        return tt('Sniper Tüfeği', 'Sniper Rifle');
      case 'roketatar':
        return tt('RPG-7 Roketatar', 'RPG-7 Launcher');
      case 'deri_ceket':
        return tt('Kalın Deri Ceket', 'Thick Leather Jacket');
      case 'celik_yelek':
        return tt('Polis Çelik Yeleği', 'Police Body Armor');
      case 'juggernaut':
        return tt('Ağır Juggernaut Zırhı', 'Heavy Juggernaut Armor');
      case 'klasik_araba_sv1':
        return tt('Klasik Araba', 'Classic Car');
      default:
        return item.name;
    }
  }

  String missionName(MissionDef m) {
    switch (m.id) {
      case 'market_easy':
      case 'market_medium':
      case 'market_hard':
        return tt('Market Soygunu', 'Market Robbery');
      case 'yankesici_easy':
        return tt('Yankesicilik', 'Pickpocketing');
      case 'teslimat_easy':
        return tt('Madde Teslimatı', 'Substance Delivery');
      case 'zulayi_easy':
        return tt('Zulayı Topla', 'Collect Stash');
      case 'harac_easy':
        return tt('Dükkan Haraçı', 'Shop Tribute');
      case 'arac_medium':
        return tt('Araç Hırsızlığı', 'Car Theft');
      case 'depo_medium':
        return tt('Depo Baskını', 'Warehouse Raid');
      case 'kuyumcu_hard':
        return tt('Kuyumcu Baskını', 'Jewelry Raid');
      case 'banka_hard':
        return tt('Banka Vurgunu', 'Bank Heist');
      default:
        return m.name;
    }
  }

  String buildingName(BuildingDef b) {
    switch (b.id) {
      case 'shabby_bar':
        return tt('Köhne Bar', 'Shabby Bar');
      case 'vinyl_shop':
        return tt('Vinil Dükkanı', 'Vinyl Shop');
      case 'nightclub':
        return tt('Neon Gece Kulübü', 'Neon Nightclub');
      case 'boxing_gym':
        return tt('Yeraltı Boks Salonu', 'Underground Boxing Gym');
      case 'casino':
        return tt('Yeraltı Kumarhanesi', 'Underground Casino');
      case 'tech_lounge':
        return tt('Tekno Lounge', 'Tech Lounge');
      case 'gallery':
        return tt('Sanat Galerisi', 'Art Gallery');
      case 'racing_track':
        return tt('Yeraltı Pist', 'Underground Track');
      case 'lunapark':
        return tt('Lunapark', 'Amusement Park');
      case 'night_market':
        return tt('Gece Pazarı', 'Night Market');
      default:
        return b.name;
    }
  }

  String difficultyName(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return tt('Kolay', 'Easy');
      case 'medium':
        return tt('Orta', 'Medium');
      case 'hard':
        return tt('Zor', 'Hard');
      default:
        return difficulty;
    }
  }

  String gangRoleName(String role) {
    switch (role) {
      case 'Lider':
        return tt('Lider', 'Leader');
      case 'Üye':
        return tt('Üye', 'Member');
      default:
        return role;
    }
  }

  // ── Power / status getters ──

  int get equipmentPower {
    var sum = 0;
    for (final itemId in equipped.values) {
      if (itemId.isEmpty) continue;
      if ((ownedItems[itemId] ?? 0) <= 0) continue;
      if (itemDurabilityPercent(itemId) <= 0) continue;
      final item = _getItem(itemId);
      if (item == null) continue;
      final lvl = itemLevels[itemId] ?? 1;
      final mult = 1 + ((lvl - 1) * 0.22);
      sum += (item.powerBonus * mult).round();
    }
    return sum;
  }

  int get totalPower {
    final levelPower = 40 + ((level - 1) * 2) + (statPower * 3);
    final multiplied = ((levelPower + equipmentPower) * avatar.powerMult)
        .round();
    return max(1, multiplied);
  }

  String get equippedWeaponId => equipped['weapon']?.trim() ?? '';
  String get equippedKnifeId => equipped['knife']?.trim() ?? '';
  String get equippedArmorId => equipped['armor']?.trim() ?? '';
  String get equippedVehicleId => equipped['vehicle']?.trim() ?? '';

  String get equippedCombatWeaponId {
    final weaponId = equippedWeaponId;
    if (weaponId.isNotEmpty &&
        (ownedItems[weaponId] ?? 0) > 0 &&
        itemDurabilityPercent(weaponId) > 0) {
      return weaponId;
    }
    final knifeId = equippedKnifeId;
    if (knifeId.isNotEmpty &&
        (ownedItems[knifeId] ?? 0) > 0 &&
        itemDurabilityPercent(knifeId) > 0) {
      return knifeId;
    }
    return '';
  }

  ItemDef? get equippedCombatWeaponItem {
    final id = equippedCombatWeaponId;
    if (id.isEmpty) return null;
    return WeaponMatchupService.itemById(id);
  }

  int get hospitalSecondsLeft {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return max(0, hospitalUntilEpoch - now);
  }

  bool get isHospitalized => currentTP <= 0 || hospitalSecondsLeft > 0;
  bool get isInJail => jailSecondsLeft > 0;
  bool get isActionLocked => isInJail || isHospitalized;
  int get actionLockSecondsLeft => isInJail ? jailSecondsLeft : hospitalSecondsLeft;
  String get actionLockStatus => isInJail ? 'prison' : 'hospital';
  int get actionLockUntilEpoch =>
      isInJail ? jailUntilEpoch : hospitalUntilEpoch;
  String get actionLockTitle => isInJail
      ? tt('HAPİSHANEDESİN', 'YOU ARE IN PRISON')
      : tt('HASTANEDESİN', 'YOU ARE IN HOSPITAL');
  String get actionLockMessage => isInJail
      ? tt(
          'Cezan bitene kadar işlem yapamazsın.',
          'You cannot perform actions until your sentence ends.',
        )
      : tt(
          'İyileşene kadar işlem yapamazsın.',
          'You cannot perform actions until you recover.',
        );
  bool get hasVehicleEquipped =>
      equippedVehicleId.trim().isNotEmpty &&
      itemDurabilityPercent(equippedVehicleId) > 0;
  int get vehicleAttackEnergyDiscount {
    if (!hasVehicleEquipped) return 0;
    switch (equippedVehicleId) {
      case 'klasik_araba_sv1':
        return 3;
      default:
        return 0;
    }
  }

  double get vehicleMissionCashMult {
    if (!hasVehicleEquipped) return 1.0;
    switch (equippedVehicleId) {
      case 'klasik_araba_sv1':
        return 1.12;
      default:
        return 1.0;
    }
  }

  bool get hasEnoughEnergyForAttack => currentEnerji >= attackEnergyCost;
  int get attackEnergyCost => max(
    12,
    ((22 - vehicleAttackEnergyDiscount) * avatar.energyCostMult).round(),
  );
  int get penaltyDurationMinutes => _penaltyDurationSec ~/ 60;
  int get vipHealGoldCost => PremiumShopService.vipHealGoldCost;
  int get energyRushGoldCost => PremiumShopService.energyRushGoldCost;
  int get vipShieldGoldCost => PremiumShopService.vipShieldGoldCost;
  int get smugglerCrateGoldCost => PremiumShopService.smugglerCrateGoldCost;
  int get premiumWeaponGoldCost => PremiumShopService.premiumWeaponGoldCost;

  int itemDurabilityPercent(String itemId) {
    if (itemId.trim().isEmpty) return 0;
    if ((ownedItems[itemId] ?? 0) <= 0) return 0;
    final raw = itemDurabilityMap[itemId];
    if (raw == null) return _maxItemDurability;
    return raw.clamp(0, _maxItemDurability);
  }

  int repairItemGoldCost(String itemId) {
    final item = _getItem(itemId);
    if (item == null || (ownedItems[itemId] ?? 0) <= 0) return 0;
    final current = itemDurabilityPercent(itemId);
    final missing = _maxItemDurability - current;
    if (missing <= 0) return 0;
    final tier = max(
      1,
      ((item.powerBonus / 350).ceil()) + (item.costGold > 0 ? 2 : 0),
    );
    return max(2, ((missing / 12).ceil()) * tier);
  }

  bool canRepairItem(String itemId) =>
      repairItemGoldCost(itemId) > 0 && gold >= repairItemGoldCost(itemId);

  int get shieldSecondsLeft {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return max(0, shieldUntilEpoch - now);
  }

  bool get isVipShieldActive => shieldSecondsLeft > 0;

  int get jailSecondsLeft {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return max(0, jailUntilEpoch - now);
  }

  int get jailSkipGoldCost => 80;
  int get hospitalSkipGoldCost => 80;

  List<MissionDef> missionsForDifficulty(String difficulty) {
    return StaticData.missions
        .where((m) => m.difficulty == difficulty)
        .toList(growable: false);
  }

  // ── Equipment / inventory helpers ──

  List<String> profileEquipmentCards() {
    const totalSlots = 8;
    const emptyA = 'assets/art/items/profile_cards/bos_slot_1.png';
    const emptyB = 'assets/art/items/profile_cards/bos_slot_2.png';

    final pickedItemIds = <String>[];
    final added = <String>{};

    for (final slot in _equipmentSlots) {
      final id = equipped[slot] ?? '';
      if (id.isEmpty) continue;
      if ((ownedItems[id] ?? 0) <= 0) continue;
      if (added.contains(id)) continue;
      pickedItemIds.add(id);
      added.add(id);
    }

    for (final item in StaticData.shopItems) {
      if ((ownedItems[item.id] ?? 0) <= 0) continue;
      if (added.contains(item.id)) continue;
      pickedItemIds.add(item.id);
      added.add(item.id);
    }

    final cards = <String>[];
    for (final id in pickedItemIds.take(totalSlots)) {
      final item = _getItem(id);
      cards.add(item?.iconAsset ?? emptyA);
    }

    while (cards.length < totalSlots) {
      cards.add(cards.length.isEven ? emptyA : emptyB);
    }

    return cards;
  }

  List<ItemDef> ownedInventoryItems() {
    return StaticData.shopItems
        .where(
          (item) =>
              (ownedItems[item.id] ?? 0) > 0 &&
              itemDurabilityPercent(item.id) > 0,
        )
        .toList(growable: false);
  }

  String slotForItem(ItemDef item) {
    if (item.type == 'vehicle') return 'vehicle';
    if (item.type == 'armor') return 'armor';
    final id = item.id.toLowerCase();
    if (id.contains('araba') || id.contains('vehicle')) return 'vehicle';
    if (id.contains('musta') ||
        id.contains('caki') ||
        id.contains('sopa') ||
        id.contains('pala'))
      return 'knife';
    return 'weapon';
  }

  String slotName(String slot) {
    switch (slot) {
      case 'weapon':
        return tt('Silah', 'Weapon');
      case 'armor':
        return tt('Zırh', 'Armor');
      case 'vehicle':
        return tt('Araç', 'Vehicle');
      case 'knife':
        return tt('Yakın Dövüş', 'Melee');
      default:
        return slot;
    }
  }

  List<ItemDef> equipCandidatesForSlot(String slot) {
    return ownedInventoryItems()
        .where((item) => slotForItem(item) == slot)
        .toList(growable: false);
  }

  List<ItemDef> availableShopItems() => StaticData.shopItems;

  String suggestedSlotForItem(ItemDef item, {String? preferredSlot}) {
    if (preferredSlot != null && equipped.containsKey(preferredSlot)) {
      return preferredSlot;
    }
    final baseSlot = slotForItem(item);
    return equipped.containsKey(baseSlot) ? baseSlot : 'weapon';
  }

  Future<bool> spendStatPoint(String statKey) async {
    if (statPoints <= 0) return false;

    switch (statKey) {
      case 'power':
        statPower += 1;
        break;
      case 'vitality':
        statVitality += 1;
        maxTP += 6;
        currentTP = min(maxTP, currentTP + 6);
        break;
      case 'energy':
        statEnergy += 1;
        maxEnerji += 5;
        currentEnerji = min(maxEnerji, currentEnerji + 5);
        _syncLegacyEnergyFields();
        break;
      default:
        return false;
    }

    statPoints -= 1;
    _queueEvent('stat_upgrade', {'stat': statKey});
    _addNews(
      tt('Stat Geliştirildi', 'Stat Upgraded'),
      tt('Bir stat puanı dağıtıldı.', 'A stat point has been allocated.'),
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  // ── Core lifecycle ──

  Future<void> initialize() async {
    if (initialized) return;
    await _load();
    final giftedNow = _grantOneTimeStarterGiftIfNeeded();
    // Social sync is now always automatic for all players.
    online = true;
    _ensureDailyState();
    _ensureBalanceMetricsInitialized();
    if (loggedIn) {
      _handlePlayerLogin();
    }

    firebaseReady = await _onlineService.initialize();
    firebaseStatus = firebaseReady
        ? tt('Firebase bağlı', 'Firebase connected')
        : _onlineService.initError;
    if (loggedIn) {
      _initNotificationsIfReady();
      unawaited(_postLoginWarmup());
    }

    final onlineUser = firebaseReady ? _onlineService.currentUser : null;
    if (onlineUser != null && !loggedIn) {
      userId = onlineUser.uid;
      authMode = 'firebase';
      loggedIn = false;
      playerOnline = false;
      if (playerName == 'Oyuncu' ||
          playerName == 'Player' ||
          playerName.isEmpty) {
        playerName =
            onlineUser.displayName ??
            onlineUser.email?.split('@').first ??
            tt('Oyuncu', 'Player');
      }
      firebaseStatus = tt(
        'Hesap bulundu. Giriş yaparak devam et.',
        'Account found. Tap login to continue.',
      );
    }

    if (giftedNow) {
      await _save();
    }

    initialized = true;
    notifyListeners();
  }

  bool _grantOneTimeStarterGiftIfNeeded() {
    final grantedNow = <String>[];

    if (!oneTimeGoldGiftGranted) {
      gold += _oneTimeGoldGiftAmount;
      oneTimeGoldGiftGranted = true;
      grantedNow.add(tt('1.000.000 altın', '1,000,000 gold'));
    }

    if (!oneTimeCashGiftGranted) {
      cash += _oneTimeCashGiftAmount;
      oneTimeCashGiftGranted = true;
      grantedNow.add(tt('\$1.000.000 nakit', '\$1,000,000 cash'));
    }

    if (grantedNow.isEmpty) return false;

    _addNews(
      tt('Başlangıç Hediyesi', 'Starter Gift'),
      tt(
        '${grantedNow.join(' + ')} hesabına eklendi.',
        '${grantedNow.join(' + ')} has been added to your account.',
      ),
    );
    return true;
  }

  // ── Internal helpers used by multiple mixins ──

  void _syncLegacyEnergyFields() {
    stamina = currentEnerji;
    maxStamina = maxEnerji;
  }

  void _applyOfflineRegeneration() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (lastRegenCheckEpoch == 0) {
      lastRegenCheckEpoch = now;
      _syncLegacyEnergyFields();
      return;
    }

    final snapshot = Player(
      id: userId.isEmpty ? 'local_player' : userId,
      name: playerName,
      power: totalPower,
      cash: cash,
      gold: gold,
      maxTP: maxTP,
      currentTP: currentTP,
      maxEnerji: maxEnerji,
      currentEnerji: currentEnerji,
      shieldUntilEpoch: shieldUntilEpoch,
      isOnline: playerOnline,
      lastRegenCheck: DateTime.fromMillisecondsSinceEpoch(
        lastRegenCheckEpoch * 1000,
      ),
      hospitalizedUntil: hospitalUntilEpoch > now
          ? DateTime.fromMillisecondsSinceEpoch(hospitalUntilEpoch * 1000)
          : null,
    );

    _regenService.applyOfflineRegeneration(snapshot);
    maxTP = snapshot.maxTP;
    currentTP = snapshot.currentTP.clamp(0, maxTP);
    maxEnerji = snapshot.maxEnerji;
    currentEnerji = snapshot.currentEnerji.clamp(0, maxEnerji);
    lastRegenCheckEpoch =
        (snapshot.lastRegenCheck ?? DateTime.now()).millisecondsSinceEpoch ~/
        1000;

    if (snapshot.hospitalizedUntil != null &&
        snapshot.hospitalizedUntil!.isAfter(DateTime.now())) {
      hospitalUntilEpoch =
          snapshot.hospitalizedUntil!.millisecondsSinceEpoch ~/ 1000;
    } else if (currentTP >= maxTP) {
      hospitalUntilEpoch = 0;
    }

    _syncLegacyEnergyFields();
  }

  void _handlePlayerLogin() {
    playerOnline = true;
    lastLoginEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _ensureDailyState();
    _applyDailyLoginStreakIfNeeded();
    _applyOfflineRegeneration();
    _initNotificationsIfReady();
    if (offlineLogs.isNotEmpty) {
      _sessionOfflineReports
        ..clear()
        ..addAll(offlineLogs);
      offlineLogs.clear();
    }
  }

  Future<void> addOfflineDefenseLog(String log) async {
    final value = log.trim();
    if (value.isEmpty) return;
    offlineLogs.insert(0, value);
    if (offlineLogs.length > 30) {
      offlineLogs.removeRange(30, offlineLogs.length);
    }
    await _save();
    notifyListeners();
  }

  Future<void> onPlayerLoginSyncReports() async {
    _handlePlayerLogin();
    await _save();
    notifyListeners();
  }

  Future<void> onAppBackground() async {
    if (!loggedIn) return;
    lastLogoutEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _save();
    if (firebaseReady &&
        online &&
        authMode == 'firebase' &&
        userId.isNotEmpty) {
      await _pushCloudSave();
    }
    unawaited(
      NotificationService.scheduleGameNotifications(
        hospitalUntilEpoch: hospitalUntilEpoch,
        jailUntilEpoch: jailUntilEpoch,
        currentEnergy: currentEnerji,
        maxEnergy: maxEnerji,
        energyRegenPerMin: 5,
      ).catchError(
        (e) => debugPrint('[GameState] scheduleGameNotifications failed: $e'),
      ),
    );
  }

  Future<void> onAppForeground() async {
    if (!loggedIn) return;
    _applyOfflineRegeneration();
    lastLoginEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    unawaited(NotificationService.cancelGameNotifications().catchError((_) {}));
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  void _initNotificationsIfReady() {
    if (authMode != 'firebase') return;
    if (!firebaseReady || userId.isEmpty) return;
    unawaited(
      NotificationService.init(userId).catchError(
        (e) => debugPrint('[GameState] NotificationService.init failed: $e'),
      ),
    );
  }

  Player _premiumSnapshotPlayer() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return Player(
      id: userId.isEmpty ? 'local_player' : userId,
      name: playerName,
      playerRank: rank,
      power: totalPower,
      cash: cash,
      gold: gold,
      maxTP: maxTP,
      currentTP: currentTP,
      maxEnerji: maxEnerji,
      currentEnerji: currentEnerji,
      shieldUntilEpoch: shieldUntilEpoch,
      isOnline: playerOnline,
      offlineLogs: List<String>.from(offlineLogs),
      hospitalizedUntil: hospitalUntilEpoch > now
          ? DateTime.fromMillisecondsSinceEpoch(hospitalUntilEpoch * 1000)
          : null,
      gangId: currentGang?['id']?.toString(),
    );
  }

  void _applyPremiumSnapshotPlayer(Player snapshot) {
    gold = max(0, snapshot.gold);
    currentTP = snapshot.currentTP.clamp(0, maxTP);
    currentEnerji = snapshot.currentEnerji.clamp(0, maxEnerji);
    shieldUntilEpoch = max(0, snapshot.shieldUntilEpoch);

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (snapshot.hospitalizedUntil != null &&
        snapshot.hospitalizedUntil!.isAfter(DateTime.now())) {
      hospitalUntilEpoch =
          snapshot.hospitalizedUntil!.millisecondsSinceEpoch ~/ 1000;
    } else if (hospitalUntilEpoch > 0 && hospitalUntilEpoch <= now) {
      hospitalUntilEpoch = 0;
    }

    _syncLegacyEnergyFields();
  }

  // ── Daily / metrics ──

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _daysBetweenIso(String fromIso, String toIso) {
    try {
      final a = DateTime.parse(fromIso);
      final b = DateTime.parse(toIso);
      return DateTime(
        b.year,
        b.month,
        b.day,
      ).difference(DateTime(a.year, a.month, a.day)).inDays;
    } catch (_) {
      return 0;
    }
  }

  void _ensureDailyState() {
    final today = _todayKey();
    if (dailyDateKey == today) return;
    dailyDateKey = today;
    for (final key in _dailyTargets.keys) {
      dailyProgress[key] = 0;
      dailyClaimed[key] = false;
    }
    dailyLoginClaimed = false;
  }

  void _applyDailyLoginStreakIfNeeded() {
    final today = _todayKey();
    if (lastDailyLoginDate == today) return;
    if (lastDailyLoginDate.isEmpty) {
      dailyStreak = 1;
    } else {
      final diff = _daysBetweenIso(lastDailyLoginDate, today);
      if (diff == 1) {
        dailyStreak = min(30, dailyStreak + 1);
      } else {
        dailyStreak = 1;
      }
    }
    lastDailyLoginDate = today;
    dailyLoginClaimed = false;
  }

  void _trackDaily(String key, [int delta = 1]) {
    _ensureDailyState();
    if (!_dailyTargets.containsKey(key)) return;
    final nowVal = dailyProgress[key] ?? 0;
    dailyProgress[key] = max(0, nowVal + delta);
  }

  void _ensureBalanceMetricsInitialized() {
    for (final key in _balanceMetricKeys) {
      balanceMetrics[key] = balanceMetrics[key] ?? 0;
    }
  }

  void _metricAdd(String key, [int delta = 1]) {
    _ensureBalanceMetricsInitialized();
    final current = balanceMetrics[key] ?? 0;
    balanceMetrics[key] = current + delta;
  }

  // ── Item / XP helpers ──

  ItemDef? _getItem(String itemId) {
    for (final item in StaticData.shopItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  void _ensureOwnedItemDurability(String itemId) {
    if ((ownedItems[itemId] ?? 0) <= 0) {
      itemDurabilityMap.remove(itemId);
      return;
    }
    final current = itemDurabilityMap[itemId];
    if (current == null) {
      itemDurabilityMap[itemId] = _maxItemDurability;
      return;
    }
    itemDurabilityMap[itemId] = current.clamp(0, _maxItemDurability);
  }

  List<String> _applyItemWear({
    required String reason,
    required Map<String, int> wearBySlot,
  }) {
    final broken = <String>[];
    for (final entry in wearBySlot.entries) {
      final slot = entry.key;
      final wear = max(0, entry.value);
      if (wear <= 0) continue;
      final itemId = (equipped[slot] ?? '').trim();
      if (itemId.isEmpty) continue;
      if ((ownedItems[itemId] ?? 0) <= 0) {
        equipped[slot] = '';
        continue;
      }
      _ensureOwnedItemDurability(itemId);
      final next = (itemDurabilityMap[itemId] ?? _maxItemDurability) - wear;
      if (next <= 0) {
        _breakItem(itemId, reason: reason);
        final item = _getItem(itemId);
        broken.add(item == null ? itemId : itemName(item));
      } else {
        itemDurabilityMap[itemId] = next;
      }
    }
    return broken;
  }

  void _breakItem(String itemId, {required String reason}) {
    if ((ownedItems[itemId] ?? 0) <= 0) return;
    ownedItems.remove(itemId);
    itemLevels.remove(itemId);
    itemDurabilityMap.remove(itemId);
    for (final slot in equipped.keys.toList()) {
      if ((equipped[slot] ?? '').trim() == itemId) {
        equipped[slot] = '';
      }
    }
    _queueEvent('item_broken', {'itemId': itemId, 'reason': reason});
    final item = _getItem(itemId);
    final displayName = item == null ? itemId : itemName(item);
    pendingItemBrokenNotices.add(displayName);
    _addNews(
      tt('Eşya Bozuldu', 'Item Broken'),
      tt(
        '$displayName tamamen eskidi ve çöpe atıldı.',
        '$displayName wore out and was discarded.',
      ),
    );
  }

  void _sanitizeInventoryState() {
    for (final id in ownedItems.keys.toList()) {
      if ((ownedItems[id] ?? 0) <= 0 || _getItem(id) == null) {
        ownedItems.remove(id);
      }
    }
    for (final id in itemLevels.keys.toList()) {
      if (!ownedItems.containsKey(id)) {
        itemLevels.remove(id);
      }
    }
    for (final id in itemDurabilityMap.keys.toList()) {
      if (!ownedItems.containsKey(id)) {
        itemDurabilityMap.remove(id);
        continue;
      }
      final val = itemDurabilityMap[id] ?? _maxItemDurability;
      itemDurabilityMap[id] = val.clamp(0, _maxItemDurability);
      if ((itemDurabilityMap[id] ?? 0) <= 0) {
        _breakItem(id, reason: 'sanitize');
      }
    }
    for (final id in ownedItems.keys) {
      _ensureOwnedItemDurability(id);
    }
    for (final slot in _equipmentSlots) {
      final id = (equipped[slot] ?? '').trim();
      if (id.isEmpty) continue;
      if ((ownedItems[id] ?? 0) <= 0 || itemDurabilityPercent(id) <= 0) {
        equipped[slot] = '';
      }
    }
  }

  void _autoEquip(ItemDef item) {
    _ensureOwnedItemDurability(item.id);
    if (item.type == 'weapon') {
      equipped['weapon'] = item.id;
      if (item.id.contains('caki') ||
          item.id.contains('pala') ||
          item.id.contains('musta') ||
          item.id.contains('sopa')) {
        equipped['knife'] = item.id;
      }
    } else if (item.type == 'armor') {
      equipped['armor'] = item.id;
    } else if (item.type == 'vehicle') {
      equipped['vehicle'] = item.id;
    }
  }

  void _grantXp(int amount) {
    xp += amount;
    while (xp >= xpToNext) {
      xp -= xpToNext;
      level += 1;
      statPoints += 3;
      _addNews(
        tt('Seviye Atladın', 'Level Up'),
        tt(
          'Sv.$level oldun, +3 stat puanı kazandın.',
          'You reached Lv.$level and gained +3 stat points.',
        ),
      );
    }
  }

  int _requiredXp(int lvl) {
    // Early levels should feel responsive; late levels still scale up.
    const base = 120;
    const growth = 1.22;
    const maxPerLevel = 3200;
    return min(maxPerLevel, (base * pow(growth, lvl - 1)).round());
  }

  void _recomputeGangRank() {
    var newRank = 1;
    var needed = 200;
    var remaining = gangRespectPoints;
    while (remaining >= needed) {
      remaining -= needed;
      newRank += 1;
      needed = 200 + ((newRank - 1) * 180);
    }
    gangRank = newRank;
  }

  // ── Event / news ──

  void _queueEvent(String type, Map<String, dynamic> payload) {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${type}_${payload.hashCode}';
    pendingQueue.add({
      'id': id,
      'type': type,
      'payload': payload,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    _prunePendingQueue();
  }

  void _addNews(String title, String detail) {
    final text = '${_clock()}  $title - $detail';
    news.insert(0, text);
    if (news.length > 60) {
      news.removeRange(60, news.length);
    }
  }

  String _clock() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}]';
  }

  // ── Error sanitization ──

  String _sanitizeError(Object e) {
    var text = e.toString().trim();
    if (text.startsWith('Exception:')) {
      text = text.replaceFirst('Exception:', '').trim();
    }
    final lower = text.toLowerCase();
    if (lower.contains('connection failed: 8') || lower.contains('status 8'))
      return tt(
        'Bağlantı hatası. İnternetini kontrol edip tekrar dene.',
        'Connection error. Check your internet and try again.',
      );
    if (lower.contains('email-already-in-use'))
      return tt(
        'Bu e-posta zaten kayıtlı. Giriş yap; şifreyi bilmiyorsan şifre sıfırlama kullan.',
        'This email is already registered. Use Login; if needed, reset password.',
      );
    if (lower.contains('weak-password'))
      return tt(
        'Şifre çok zayıf. En az 6 karakter kullan.',
        'Password is too weak. Use at least 6 characters.',
      );
    if (lower.contains('invalid-email'))
      return tt('Geçersiz e-posta adresi.', 'Invalid email address.');
    if (lower.contains('wrong-password') ||
        lower.contains('invalid-credential') ||
        lower.contains('invalid-login-credentials'))
      return tt(
        'Şifre yanlış! Hatırlamaya çalış.',
        'Wrong password! Try to remember it.',
      );
    if (lower.contains('user-not-found'))
      return tt(
        'Bu e-posta ile yeraltında kimse tanınmıyor. Önce kaydol!',
        'No one with this email is known underground. Register first!',
      );
    if (lower.contains('operation-not-allowed'))
      return tt(
        'Firebase Auth içinde E-posta/Şifre girişi kapalı.',
        'Email/Password provider is disabled in Firebase Auth.',
      );
    if (lower.contains('configuration_not_found') ||
        lower.contains('configuration-not-found') ||
        lower.contains('invalid-api-key') ||
        lower.contains('api-key-not-valid') ||
        lower.contains('api key not valid') ||
        lower.contains('web firebase ayari eksik') ||
        lower.contains('web firebase ayarı eksik') ||
        lower.contains('requests from this origin are blocked') ||
        lower.contains('app id') ||
        lower.contains('malformed'))
      return tt(
        'Web Firebase ayarı eksik/hatalı (Web App ID + Web API key + domain). Geliştirici ayarı gerekiyor.',
        'Web Firebase config is missing/invalid (Web App ID + Web API key + domain). Developer setup is required.',
      );
    if (lower.contains('too-many-requests'))
      return tt(
        'Çok fazla deneme yapıldı. Birkaç dakika bekleyip tekrar dene.',
        'Too many attempts. Wait a few minutes and try again.',
      );
    if (lower.contains('network-request-failed') ||
        lower.contains('failed host lookup'))
      return tt(
        'Ağ bağlantısı yok gibi görünüyor. İnterneti kontrol et.',
        'Network appears unavailable. Check your internet connection.',
      );
    if (lower.contains('channel-error') || lower.contains('internal-error'))
      return tt(
        'Giriş servisine bağlanılamadı. Uygulamayı kapatıp tekrar aç.',
        'Could not reach auth service. Restart the app and try again.',
      );
    if (lower.contains('requires-recent-login'))
      return tt(
        'Güvenlik nedeniyle tekrar giriş yapıp yeniden dene.',
        'For security, re-login and try again.',
      );
    if (lower.contains('clientconfigurationerror') ||
        lower.contains('serverclientid') ||
        lower.contains('developer_error') ||
        lower.contains('status code: 10') ||
        lower.contains('api: 10'))
      return tt(
        'Google giriş ayarı eksik. E-posta girişiyle devam et.',
        'Google sign-in is not configured. Continue with email login.',
      );
    if (lower.contains('missing initial state') ||
        lower.contains('sessionstorage') ||
        lower.contains('storage-partitioned'))
      return tt(
        'Tarayıcı oturumu engellenmiş görünüyor. Aynı sekmede tekrar dene veya gizli sekmeden çık.',
        'Browser session storage appears blocked. Retry in same tab or disable private browsing.',
      );
    if (text.isEmpty) return tt('Bilinmeyen hata.', 'Unknown error.');
    return text;
  }

  // ── Online sync (shared across mixins) ──

  Future<void> refreshSocialData() async {
    if (!firebaseReady || !online || authMode != 'firebase' || userId.isEmpty) {
      _ensureSeedLeaderboardRows();
      notifyListeners();
      return;
    }
    try {
      final me = await _onlineService.fetchUserProfile(userId);
      final meGangId = (me?['gangId']?.toString() ?? '').trim();
      final meGangName = (me?['gangName']?.toString() ?? '').trim();
      final meGangRole = (me?['gangRole']?.toString() ?? '').trim();
      final currentGangId = (currentGang?['id']?.toString() ?? '').trim();
      if (currentGangId.isEmpty && meGangId.isNotEmpty) {
        currentGang = {
          'id': meGangId,
          'name': meGangName.isEmpty ? tt('Çete', 'Gang') : meGangName,
          'role': meGangRole.isEmpty ? 'Üye' : meGangRole,
        };
      }

      friends
        ..clear()
        ..addAll(await _onlineService.fetchFriends(userId));
      incomingRequests
        ..clear()
        ..addAll(await _onlineService.fetchIncomingRequests(userId));
      incomingGangInvites
        ..clear()
        ..addAll(await _onlineService.fetchIncomingGangInvites(userId));
      leaderboardRows
        ..clear()
        ..addAll(await _onlineService.fetchLeaderboard(limit: 100));
      _dedupeLeaderboardRows();
      _ensureSeedLeaderboardRows();
      _sortLeaderboardRows();
      discoverableGangs
        ..clear()
        ..addAll(await _onlineService.fetchGangs(limit: 20));
      if (discoverableGangs.isEmpty) {
        // Bot çeteleri Firestore'a yaz, sonra tekrar çek
        unawaited(_onlineService.seedBotData());
        await Future.delayed(const Duration(seconds: 2));
        discoverableGangs
          ..clear()
          ..addAll(await _onlineService.fetchGangs(limit: 20));
      }

      final gId = currentGang?['id']?.toString() ?? '';
      if (gId.isNotEmpty) {
        final gang = await _onlineService.fetchGang(gId);
        if (gang != null) {
          currentGang = {'id': gId, ...gang};
          gangRank = (gang['gangRank'] as num?)?.toInt() ?? gangRank;
          gangRespectPoints =
              (gang['respectPoints'] as num?)?.toInt() ?? gangRespectPoints;
          gangVault = (gang['vault'] as num?)?.toInt() ?? gangVault;
          gangMembers
            ..clear()
            ..addAll(await _onlineService.fetchGangMembers(gId));
          if (isGangLeader) {
            gangJoinRequests
              ..clear()
              ..addAll(
                await _onlineService.fetchGangJoinRequestsForLeader(userId),
              );
          } else {
            gangJoinRequests.clear();
          }
        } else {
          gangMembers.clear();
          gangJoinRequests.clear();
        }
      } else {
        gangMembers.clear();
        gangJoinRequests.clear();
      }
    } catch (e) {
      lastAuthError = _sanitizeError(e);
      _ensureSeedLeaderboardRows();
      _dedupeLeaderboardRows();
    }
    notifyListeners();
  }

  void _dedupeLeaderboardRows() {
    if (leaderboardRows.isEmpty) return;
    final byUid = <String, Map<String, dynamic>>{};
    final byNameForUidless = <String, Map<String, dynamic>>{};

    for (final raw in leaderboardRows) {
      final row = Map<String, dynamic>.from(raw);
      final uid = (row['uid']?.toString() ?? '').trim();
      final normalizedName = (row['displayName'] ?? row['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (uid.isNotEmpty) {
        byUid[uid] = row;
      } else {
        final key = normalizedName.isEmpty
            ? 'anon_${byNameForUidless.length}'
            : normalizedName;
        byNameForUidless[key] = row;
      }
    }

    leaderboardRows
      ..clear()
      ..addAll(byUid.values)
      ..addAll(byNameForUidless.values);
  }

  void _ensureSeedLeaderboardRows() {
    if (leaderboardRows.length >= 20) return;
    final existingIds = leaderboardRows
        .map((row) => (row['uid']?.toString() ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingNames = leaderboardRows
        .map(
          (row) => (row['displayName'] ?? row['name'] ?? '')
              .toString()
              .trim()
              .toLowerCase(),
        )
        .where((name) => name.isNotEmpty)
        .toSet();
    // Sunucudan botlar geldiyse yerel seed ekleyip isimleri çoğaltma.
    if (existingIds.any((id) => id.startsWith('bot_'))) return;

    for (var i = 0; i < _seedBotNames.length; i++) {
      final uid = 'bot_${(i + 1).toString().padLeft(2, '0')}';
      if (existingIds.contains(uid)) continue;
      final seedName = _seedBotNames[i].trim();
      if (seedName.isNotEmpty &&
          existingNames.contains(seedName.toLowerCase())) {
        continue;
      }
      final power = 180 + (i * 55);
      leaderboardRows.add({
        'uid': uid,
        'displayName': seedName,
        'power': power,
        'level': max(2, (power / 70).round()),
        'cash': 2600 + (i * 850),
        'wins': 5 + i,
        'gangWins': 1 + (i ~/ 3),
        'currentTp': 100,
        'gangName': i < 10 ? _seedGangA : _seedGangB,
        'combatWeaponId': WeaponMatchupService.defaultWeaponIdForPower(power),
        'equippedKnifeId': WeaponMatchupService.defaultKnifeIdForPower(power),
        'equippedArmorId': WeaponMatchupService.defaultArmorIdForPower(power),
        'equippedVehicleId': WeaponMatchupService.defaultVehicleIdForPower(
          power,
        ),
        'online': true,
      });
      if (seedName.isNotEmpty) {
        existingNames.add(seedName.toLowerCase());
      }
      if (leaderboardRows.length >= 20) break;
    }
    _sortLeaderboardRows();
  }

  void _sortLeaderboardRows() {
    leaderboardRows.sort((a, b) {
      final scoreCompare = _leaderboardScore(b).compareTo(_leaderboardScore(a));
      if (scoreCompare != 0) return scoreCompare;
      final powerA = (a['power'] as num?)?.toInt() ?? 0;
      final powerB = (b['power'] as num?)?.toInt() ?? 0;
      final powerCompare = powerB.compareTo(powerA);
      if (powerCompare != 0) return powerCompare;
      final winsA = (a['wins'] as num?)?.toInt() ?? 0;
      final winsB = (b['wins'] as num?)?.toInt() ?? 0;
      return winsB.compareTo(winsA);
    });
  }

  int _leaderboardScore(Map<String, dynamic> row) {
    final power = (row['power'] as num?)?.toInt() ?? 0;
    final cash = (row['cash'] as num?)?.toInt() ?? 0;
    final wins = (row['wins'] as num?)?.toInt() ?? 0;
    final gangWins = (row['gangWins'] as num?)?.toInt() ?? 0;
    return (power * 12) + (wins * 900) + (gangWins * 1200) + (cash ~/ 2000);
  }

  Future<void> ensureOnlineProfile() async {
    if (!firebaseReady || !online || authMode != 'firebase' || userId.isEmpty)
      return;
    try {
      final resolvedGangId = hasGang
          ? (currentGang?['id']?.toString() ?? '')
          : null;
      final resolvedGangName = hasGang
          ? (currentGang?['name']?.toString() ?? '')
          : null;
      final profileStatus = isActionLocked ? actionLockStatus : 'active';
      final profileStatusUntilEpoch = isActionLocked ? actionLockUntilEpoch : 0;
      await _onlineService.upsertUserProfile(
        uid: userId,
        displayName: playerName,
        power: totalPower,
        level: level,
        rank: rank,
        cash: cash,
        wins: wins,
        gangWins: gangWins,
        lastLoginEpoch: lastLoginEpoch,
        currentTp: currentTP,
        maxTp: maxTP,
        currentEnergy: currentEnerji,
        maxEnergy: maxEnerji,
        attackEnergyCost: attackEnergyCost,
        shieldUntilEpoch: shieldUntilEpoch,
        status: profileStatus,
        statusUntilEpoch: profileStatusUntilEpoch,
        online: playerOnline,
        gangId: resolvedGangId,
        gangName: resolvedGangName,
        avatarId: selectedAvatarId,
        equippedWeaponId: equippedWeaponId,
        equippedKnifeId: equippedKnifeId,
        equippedArmorId: equippedArmorId,
        equippedVehicleId: equippedVehicleId,
        combatWeaponId: equippedCombatWeaponId,
      );
    } catch (e) {
      debugPrint('[ProfileSync] upsert failed => $e');
    }
  }

  Future<void> replayPendingQueue() async {
    if (!online || pendingQueue.isEmpty) return;
    final uniqueById = <String, Map<String, dynamic>>{};
    for (final evt in pendingQueue) {
      final id = evt['id'] as String? ?? '';
      if (id.isEmpty) continue;
      uniqueById[id] = evt;
    }

    final deduped = uniqueById.values.toList(growable: false);

    if (firebaseReady && authMode == 'firebase' && userId.isNotEmpty) {
      try {
        await _onlineService.writePendingEvents(userId, deduped);
        pendingQueue.clear();
      } catch (_) {
        pendingQueue
          ..clear()
          ..addAll(deduped);
        _prunePendingQueue();
      }
    } else {
      pendingQueue
        ..clear()
        ..addAll(deduped);
      _prunePendingQueue();
    }

    await _save();
    notifyListeners();
  }

  void _syncOnlineSoon() {
    if (!online) return;
    Future<void>.microtask(() async {
      await replayPendingQueue();
      await ensureOnlineProfile();
      _scheduleCloudSave();
    });
  }

  void _scheduleCloudSave({
    Duration delay = const Duration(milliseconds: 700),
  }) {
    if (!firebaseReady || !online || authMode != 'firebase' || userId.isEmpty)
      return;
    _cloudSaveDebounce?.cancel();
    _cloudSaveDebounce = Timer(delay, () async {
      await _pushCloudSave();
    });
  }

  Future<void> _pushCloudSave() async {
    if (_cloudSaveInFlight) return;
    if (!firebaseReady || !online || authMode != 'firebase' || userId.isEmpty)
      return;
    _cloudSaveInFlight = true;
    try {
      final payload = _buildSavePayload();
      await _onlineService.upsertCloudSave(
        uid: userId,
        payload: payload,
        clientUpdatedAtEpoch: localUpdatedAtEpoch,
      );
    } catch (e) {
      debugPrint('[CloudSave] push failed => $e');
    } finally {
      _cloudSaveInFlight = false;
    }
  }

  Future<void> _postLoginWarmup() async {
    try {
      await replayPendingQueue();
    } catch (e) {
      debugPrint('[PostLoginWarmup] replayPendingQueue failed => $e');
    }
    try {
      await ensureOnlineProfile();
    } catch (e) {
      debugPrint('[PostLoginWarmup] ensureOnlineProfile failed => $e');
    }
    try {
      await refreshSocialData();
    } catch (e) {
      debugPrint('[PostLoginWarmup] refreshSocialData failed => $e');
    }
  }

  Future<void> _pullOrCreateCloudSaveAfterAuth() async {
    if (!firebaseReady || authMode != 'firebase' || userId.isEmpty) return;
    final currentUid = userId;
    final prefs = await SharedPreferences.getInstance();

    try {
      final remote = await _onlineService.fetchCloudSave(currentUid);
      final remotePayload = _asStringDynamicMap(remote?['payload']);
      final remoteEpoch =
          (remote?['clientUpdatedAtEpoch'] as num?)?.toInt() ?? 0;
      final localEpoch = localUpdatedAtEpoch;

      if (remotePayload.isNotEmpty) {
        final shouldApplyRemote =
            saveOwnerUid != currentUid || remoteEpoch > localEpoch;
        if (shouldApplyRemote) {
          await prefs.setString(_storageKey, _safeJsonEncode(remotePayload));
          await _load();
          loggedIn = true;
          authMode = 'firebase';
          userId = currentUid;
          saveOwnerUid = currentUid;
          playerOnline = true;
          _handlePlayerLogin();
        } else {
          await _pushCloudSave();
        }
        return;
      }

      if (saveOwnerUid.isNotEmpty && saveOwnerUid != currentUid) {
        _resetProgressForFreshProfile();
      }
      saveOwnerUid = currentUid;
      await _save();
      await _pushCloudSave();
    } catch (e) {
      debugPrint('[CloudSave] pull/create failed => $e');
    }
  }

  // ── Persistence ──

  void _resetProgressForFreshProfile() {
    level = 1;
    xp = 0;
    cash = 1500;
    gold = 0;
    maxTP = 100;
    currentTP = 100;
    maxEnerji = 100;
    currentEnerji = 100;
    stamina = 100;
    maxStamina = 100;
    statPoints = 0;
    statPower = 0;
    statVitality = 0;
    statEnergy = 0;
    lastRegenCheckEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    shieldUntilEpoch = 0;
    hospitalUntilEpoch = 0;
    jailUntilEpoch = 0;
    playerOnline = true;
    wins = 0;
    gangWins = 0;
    lastLoginEpoch = 0;
    lastLogoutEpoch = 0;
    onboardingCompleted = false;
    nicknameChosen = false;
    selectedAvatarId = 'baba';
    avatarLocked = false;
    offlineLogs.clear();
    _sessionOfflineReports.clear();
    ownedItems.clear();
    itemLevels.clear();
    itemDurabilityMap.clear();
    for (final key in equipped.keys.toList()) {
      equipped[key] = '';
    }
    ownedBuildings.clear();
    buildingLastCollectEpoch.clear();
    pendingQueue.clear();
    news.clear();
    friends.clear();
    incomingRequests.clear();
    incomingGangInvites.clear();
    gangJoinRequests.clear();
    discoverableGangs.clear();
    leaderboardRows.clear();
    currentGang = null;
    gangMembers.clear();
    gangRank = 1;
    gangRespectPoints = 0;
    gangVault = 25000;
    oneTimeGoldGiftGranted = false;
    oneTimeCashGiftGranted = false;
    balanceMetrics.clear();
    _ensureBalanceMetricsInitialized();
    _syncLegacyEnergyFields();
  }

  Map<String, dynamic> _buildSavePayload() {
    _sanitizeInventoryState();
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (localUpdatedAtEpoch <= 0) {
      localUpdatedAtEpoch = nowEpoch;
    } else {
      localUpdatedAtEpoch = max(localUpdatedAtEpoch + 1, nowEpoch);
    }

    if (authMode == 'firebase' && userId.isNotEmpty) {
      saveOwnerUid = userId;
    }

    return <String, dynamic>{
      'loggedIn': loggedIn,
      'online': online,
      'firebaseReady': firebaseReady,
      'languageCode': languageCode,
      'firebaseStatus': firebaseStatus,
      'authMode': authMode,
      'userId': userId,
      'playerName': playerName,
      'selectedAvatarId': selectedAvatarId,
      'avatarLocked': avatarLocked,
      'onboardingCompleted': onboardingCompleted,
      'nicknameChosen': nicknameChosen,
      'level': level,
      'xp': xp,
      'cash': cash,
      'gold': gold,
      'maxTP': maxTP,
      'currentTP': currentTP,
      'maxEnerji': maxEnerji,
      'currentEnerji': currentEnerji,
      'shieldUntilEpoch': shieldUntilEpoch,
      'stamina': stamina,
      'maxStamina': maxStamina,
      'statPoints': statPoints,
      'statPower': statPower,
      'statVitality': statVitality,
      'statEnergy': statEnergy,
      'hospitalUntilEpoch': hospitalUntilEpoch,
      'jailUntilEpoch': jailUntilEpoch,
      'lastRegenCheckEpoch': lastRegenCheckEpoch,
      'playerOnline': playerOnline,
      'wins': wins,
      'gangWins': gangWins,
      'lastLoginEpoch': lastLoginEpoch,
      'lastLogoutEpoch': lastLogoutEpoch,
      'offlineLogs': offlineLogs,
      'ownedItems': ownedItems,
      'itemLevels': itemLevels,
      'itemDurabilityMap': itemDurabilityMap,
      'equipped': equipped,
      'ownedBuildings': ownedBuildings,
      'buildingLastCollectEpoch': buildingLastCollectEpoch,
      'pendingQueue': pendingQueue,
      'news': news,
      'currentGang': currentGang,
      'gangRank': gangRank,
      'gangRespectPoints': gangRespectPoints,
      'gangVault': gangVault,
      'musicEnabled': musicEnabled,
      'sfxEnabled': sfxEnabled,
      'notifyEnergyFull': notifyEnergyFull,
      'notifyHospitalReady': notifyHospitalReady,
      'notifyUnderAttack': notifyUnderAttack,
      'notifyGangMessages': notifyGangMessages,
      'nameChangeCount': nameChangeCount,
      'dailyDateKey': dailyDateKey,
      'dailyProgress': dailyProgress,
      'dailyClaimed': dailyClaimed,
      'dailyStreak': dailyStreak,
      'lastDailyLoginDate': lastDailyLoginDate,
      'dailyLoginClaimed': dailyLoginClaimed,
      'oneTimeGoldGiftGranted': oneTimeGoldGiftGranted,
      'oneTimeCashGiftGranted': oneTimeCashGiftGranted,
      'balanceMetrics': balanceMetrics,
      'unlockedAchievements': unlockedAchievements.toList(),
      'claimedAchievements': claimedAchievements.toList(),
      'achievementCounters': achievementCounters,
      'localUpdatedAtEpoch': localUpdatedAtEpoch,
      'saveOwnerUid': saveOwnerUid,
      'saveVersion': _saveVersion,
    };
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _buildSavePayload();
    await prefs.setString(_storageKey, _safeJsonEncode(payload));
    _scheduleCloudSave();
  }

  String _safeJsonEncode(Object? value) {
    return jsonEncode(_jsonSafeValue(value));
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, rawVal) {
        out[key.toString()] = _jsonSafeValue(rawVal);
      });
      return out;
    }
    if (value is Iterable) {
      return value.map(_jsonSafeValue).toList(growable: false);
    }

    final dyn = value as dynamic;
    try {
      final seconds = dyn.seconds;
      final nanos = dyn.nanoseconds;
      if (seconds is num) {
        return <String, dynamic>{
          '_seconds': seconds.toInt(),
          '_nanoseconds': nanos is num ? nanos.toInt() : 0,
        };
      }
    } catch (_) {}

    return value.toString();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      selectedAvatarId = 'baba';
      avatarLocked = false;
      gold = 1000;
      maxTP = 100;
      currentTP = 100;
      maxEnerji = 100;
      currentEnerji = 100;
      statPower = 0;
      statVitality = 0;
      statEnergy = 0;
      lastRegenCheckEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      localUpdatedAtEpoch = lastRegenCheckEpoch;
      saveOwnerUid = '';
      dailyDateKey = _todayKey();
      dailyProgress
        ..clear()
        ..addAll({for (final k in _dailyTargets.keys) k: 0});
      dailyClaimed
        ..clear()
        ..addAll({for (final k in _dailyTargets.keys) k: false});
      dailyStreak = 0;
      lastDailyLoginDate = '';
      dailyLoginClaimed = false;
      oneTimeGoldGiftGranted = false;
      oneTimeCashGiftGranted = false;
      balanceMetrics.clear();
      _ensureBalanceMetricsInitialized();
      _syncLegacyEnergyFields();
      return;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final saveVersion = map['saveVersion'] as int? ?? 0;
    loggedIn = map['loggedIn'] as bool? ?? false;
    // Legacy saves may contain manual online toggle; force automatic mode.
    online = true;
    firebaseReady = map['firebaseReady'] as bool? ?? false;
    languageCode = (map['languageCode'] as String? ?? 'tr') == 'en'
        ? 'en'
        : 'tr';
    firebaseStatus = map['firebaseStatus'] as String? ?? '';
    authMode = map['authMode'] as String? ?? 'local';
    userId = map['userId'] as String? ?? '';
    localUpdatedAtEpoch = map['localUpdatedAtEpoch'] as int? ?? 0;
    saveOwnerUid = map['saveOwnerUid'] as String? ?? '';

    playerName = map['playerName'] as String? ?? tt('Oyuncu', 'Player');
    selectedAvatarId = _normalizeAvatarId(
      map['selectedAvatarId'] as String? ?? 'baba',
    );
    onboardingCompleted =
        map['onboardingCompleted'] as bool? ?? _isCustomPlayerName(playerName);
    avatarLocked = map['avatarLocked'] as bool? ?? onboardingCompleted;
    nicknameChosen = map['nicknameChosen'] as bool? ?? false;
    level = map['level'] as int? ?? 1;
    xp = map['xp'] as int? ?? 0;
    cash = map['cash'] as int? ?? 1500;
    gold = map['gold'] as int? ?? 0;
    maxTP = map['maxTP'] as int? ?? 100;
    currentTP = map['currentTP'] as int? ?? maxTP;
    maxEnerji = map['maxEnerji'] as int? ?? (map['maxStamina'] as int? ?? 100);
    currentEnerji =
        map['currentEnerji'] as int? ?? (map['stamina'] as int? ?? 100);
    shieldUntilEpoch = map['shieldUntilEpoch'] as int? ?? 0;
    stamina = currentEnerji;
    maxStamina = maxEnerji;
    statPoints = map['statPoints'] as int? ?? 0;
    statPower = map['statPower'] as int? ?? 0;
    statVitality = map['statVitality'] as int? ?? 0;
    statEnergy = map['statEnergy'] as int? ?? 0;
    hospitalUntilEpoch = map['hospitalUntilEpoch'] as int? ?? 0;
    jailUntilEpoch = map['jailUntilEpoch'] as int? ?? 0;
    lastRegenCheckEpoch =
        map['lastRegenCheckEpoch'] as int? ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    playerOnline = map['playerOnline'] as bool? ?? false;
    wins = (map['wins'] as num?)?.toInt() ?? 0;
    gangWins = (map['gangWins'] as num?)?.toInt() ?? 0;
    lastLoginEpoch = (map['lastLoginEpoch'] as num?)?.toInt() ?? 0;
    lastLogoutEpoch = (map['lastLogoutEpoch'] as num?)?.toInt() ?? 0;
    offlineLogs
      ..clear()
      ..addAll(
        ((map['offlineLogs'] as List<dynamic>? ?? const []).cast<String>()),
      );

    ownedItems
      ..clear()
      ..addAll(
        (map['ownedItems'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );

    itemLevels
      ..clear()
      ..addAll(
        (map['itemLevels'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );

    itemDurabilityMap
      ..clear()
      ..addAll(
        (map['itemDurabilityMap'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );

    final rawEquipped = (map['equipped'] as Map<String, dynamic>? ?? {});
    equipped.clear();
    for (final slot in _equipmentSlots) {
      equipped[slot] = rawEquipped[slot] as String? ?? '';
    }

    ownedBuildings
      ..clear()
      ..addAll(
        (map['ownedBuildings'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );

    buildingLastCollectEpoch
      ..clear()
      ..addAll(
        (map['buildingLastCollectEpoch'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );

    pendingQueue
      ..clear()
      ..addAll(
        (map['pendingQueue'] as List<dynamic>? ?? const [])
            .map(_normalizePendingEvent)
            .whereType<Map<String, dynamic>>(),
      );
    _prunePendingQueue();

    news
      ..clear()
      ..addAll(((map['news'] as List<dynamic>? ?? const []).cast<String>()));

    currentGang = (map['currentGang'] as Map<String, dynamic>?);
    gangRank = map['gangRank'] as int? ?? 1;
    gangRespectPoints = map['gangRespectPoints'] as int? ?? 0;
    gangVault = map['gangVault'] as int? ?? 25000;
    musicEnabled = map['musicEnabled'] as bool? ?? true;
    sfxEnabled = map['sfxEnabled'] as bool? ?? true;
    notifyEnergyFull = map['notifyEnergyFull'] as bool? ?? true;
    notifyHospitalReady = map['notifyHospitalReady'] as bool? ?? true;
    notifyUnderAttack = map['notifyUnderAttack'] as bool? ?? true;
    notifyGangMessages = map['notifyGangMessages'] as bool? ?? true;
    nameChangeCount = map['nameChangeCount'] as int? ?? 0;
    dailyDateKey = map['dailyDateKey'] as String? ?? '';
    dailyProgress
      ..clear()
      ..addAll(
        (map['dailyProgress'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );
    dailyClaimed
      ..clear()
      ..addAll(
        (map['dailyClaimed'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v == true),
        ),
      );
    dailyStreak = (map['dailyStreak'] as num?)?.toInt() ?? 0;
    lastDailyLoginDate = map['lastDailyLoginDate'] as String? ?? '';
    dailyLoginClaimed = map['dailyLoginClaimed'] as bool? ?? false;
    oneTimeGoldGiftGranted = map['oneTimeGoldGiftGranted'] as bool? ?? false;
    oneTimeCashGiftGranted = map['oneTimeCashGiftGranted'] as bool? ?? false;
    balanceMetrics
      ..clear()
      ..addAll(
        (map['balanceMetrics'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );
    _ensureBalanceMetricsInitialized();
    unlockedAchievements
      ..clear()
      ..addAll(
        ((map['unlockedAchievements'] as List<dynamic>? ?? const [])
            .cast<String>()),
      );
    claimedAchievements
      ..clear()
      ..addAll(
        ((map['claimedAchievements'] as List<dynamic>? ?? const [])
            .cast<String>()),
      );
    achievementCounters
      ..clear()
      ..addAll(
        (map['achievementCounters'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );
    currentTP = currentTP.clamp(0, maxTP);
    currentEnerji = currentEnerji.clamp(0, maxEnerji);
    _syncLegacyEnergyFields();
    _sanitizeInventoryState();

    // Eski sürümlerde başlangıçta otomatik verilen demo ekipman göçü.
    if (saveVersion < 3) {
      final seededOldLoad =
          ownedItems.length <= 2 &&
          (ownedItems['tabanca_9mm'] ?? 0) > 0 &&
          (ownedItems['deri_ceket'] ?? 0) > 0;
      if (seededOldLoad) {
        ownedItems.clear();
        itemLevels.clear();
        itemDurabilityMap.clear();
        for (final key in equipped.keys) {
          equipped[key] = '';
        }
      }
    }

    if (saveVersion < 4) {
      final keys = ownedItems.keys.toSet();
      const starterPair = {'musta', 'deri_ceket'};
      const oldShowcase = {
        'mp5_sv2',
        'taktik_yelek_sv1',
        'tirtikli_bicak_sv3',
        'klasik_araba_sv1',
        'altin_saat_sv2',
        'gece_gozlugu_sv1',
      };

      final looksLikeStarterSeed =
          keys.isNotEmpty &&
          keys.length <= 2 &&
          keys.containsAll(starterPair) &&
          level <= 1 &&
          itemLevels.values.every((v) => v <= 1);

      final looksLikeShowcaseSeed =
          keys.isNotEmpty && keys.difference(oldShowcase).isEmpty;

      if (looksLikeStarterSeed || looksLikeShowcaseSeed) {
        ownedItems.clear();
        itemLevels.clear();
        itemDurabilityMap.clear();
        for (final slot in _equipmentSlots) {
          equipped[slot] = '';
        }
      }
    }

    if (saveVersion < 11) {
      for (final id in ownedItems.keys) {
        _ensureOwnedItemDurability(id);
      }
      _sanitizeInventoryState();
    }
  }

  Map<String, dynamic>? _normalizePendingEvent(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final tsRaw = raw['ts'];
    final ts = tsRaw is num
        ? tsRaw.toInt()
        : DateTime.now().millisecondsSinceEpoch;
    final type = raw['type']?.toString() ?? 'unknown';
    final payloadRaw = raw['payload'];
    final payload = payloadRaw is Map
        ? payloadRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};
    return <String, dynamic>{
      'id': id,
      'type': type,
      'payload': payload,
      'ts': ts,
    };
  }

  void _prunePendingQueue() {
    if (pendingQueue.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final latestById = <String, Map<String, dynamic>>{};
    final orderedIds = <String>[];

    for (final evt in pendingQueue) {
      final id = evt['id'] as String? ?? '';
      if (id.isEmpty) continue;
      final tsRaw = evt['ts'];
      final ts = tsRaw is num ? tsRaw.toInt() : nowMs;
      if (nowMs - ts > _pendingQueueTtlMs) continue;

      final normalized = <String, dynamic>{
        'id': id,
        'type': evt['type']?.toString() ?? 'unknown',
        'payload': evt['payload'] is Map
            ? (evt['payload'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
        'ts': ts,
      };
      if (!latestById.containsKey(id)) {
        orderedIds.add(id);
      }
      latestById[id] = normalized;
    }

    final compact = <Map<String, dynamic>>[];
    for (final id in orderedIds) {
      final evt = latestById[id];
      if (evt != null) compact.add(evt);
    }

    compact.sort(
      (a, b) => ((a['ts'] as num?)?.toInt() ?? 0).compareTo(
        (b['ts'] as num?)?.toInt() ?? 0,
      ),
    );
    if (compact.length > _pendingQueueMax) {
      compact.removeRange(0, compact.length - _pendingQueueMax);
    }

    pendingQueue
      ..clear()
      ..addAll(compact);
  }

  String _normalizeAvatarId(String rawId) {
    if (StaticData.avatarClasses.any((a) => a.id == rawId)) return rawId;
    const legacyMap = <String, String>{
      'gangster': 'silahsor',
      'hustler': 'firsatci',
      'enforcer': 'zorba',
      'shadow': 'suikastci',
      'og': 'baron',
      'kingpin': 'baba',
    };
    final mapped = legacyMap[rawId] ?? 'baba';
    if (StaticData.avatarClasses.any((a) => a.id == mapped)) return mapped;
    return StaticData.avatarClasses.first.id;
  }

  bool _isCustomPlayerName(String value) {
    final v = value.trim().toLowerCase();
    return v.isNotEmpty &&
        v != 'oyuncu' &&
        v != 'player' &&
        v != 'patron_local_' &&
        v != 'boss_local_';
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  @override
  void dispose() {
    _cloudSaveDebounce?.cancel();
    super.dispose();
  }
}
