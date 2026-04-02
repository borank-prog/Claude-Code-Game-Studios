// ignore_for_file: curly_braces_in_flow_control_structures

part of 'game_state.dart';

mixin _GameStateCombat on _GameStateBase {
  Future<void> applyAttackItemWear({String reason = 'pvp_attack'}) async {
    _applyItemWear(
      reason: reason,
      wearBySlot: _GameStateBase._attackWearBySlot,
    );
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  Future<bool> spendAttackEnergy({required int attackCost}) async {
    _applyOfflineRegeneration();
    if (isActionLocked) {
      return false;
    }
    final cost = max(0, attackCost);
    if (currentEnerji < cost) {
      return false;
    }
    currentEnerji = max(0, currentEnerji - cost);
    _syncLegacyEnergyFields();
    _queueEvent('attack_energy_spent', {'energy': cost});
    await _save();
    _syncOnlineSoon();
    notifyListeners();
    return true;
  }

  Future<void> syncAttackEnergyFromServer({
    required int remainingEnergy,
  }) async {
    _applyOfflineRegeneration();
    currentEnerji = remainingEnergy.clamp(0, maxEnerji);
    _syncLegacyEnergyFields();
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  Future<void> applySoloAttackWin({
    required int cashGained,
    int attackerDamage = 10,
    int attackCost = 20,
    List<String> defenderOfflineLogs = const [],
    int xpGained = 14,
    required String report,
  }) async {
    _applyOfflineRegeneration();
    currentEnerji = max(0, currentEnerji - max(0, attackCost));
    currentTP = max(0, currentTP - max(0, attackerDamage));
    if (currentTP <= 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      hospitalUntilEpoch = max(
        hospitalUntilEpoch,
        now + _GameStateBase._hospitalPenaltyDurationSec,
      );
    }
    if (defenderOfflineLogs.isNotEmpty) {
      offlineLogs.insertAll(0, defenderOfflineLogs.reversed);
      if (offlineLogs.length > 30) {
        offlineLogs.removeRange(30, offlineLogs.length);
      }
    }
    _syncLegacyEnergyFields();
    _applyItemWear(
      reason: 'solo_attack_win',
      wearBySlot: _GameStateBase._attackWearBySlot,
    );
    cash += max(0, cashGained);
    _trackDaily('raid_joined', 1);
    _trackDaily('cash_earned', max(0, cashGained));
    _grantXp(max(0, xpGained));
    wins += 1;
    trackAchievement('battles_won', 1);
    trackAchievement('total_cash_earned', max(0, cashGained));
    _queueEvent('solo_attack_win', {
      'cash': max(0, cashGained),
      'damage': max(0, attackerDamage),
      'energy': max(0, attackCost),
      'xp': max(0, xpGained),
    });
    _addNews(tt('Sokak Zaferi', 'Street Victory'), report);
    await _save();
    _syncOnlineSoon();
    checkAchievements();
    notifyListeners();
  }

  Future<void> applySoloAttackLoss({
    int attackerDamage = 45,
    int cashPenalty = 50,
    int attackCost = 20,
    List<String> defenderOfflineLogs = const [],
    required String report,
  }) async {
    _applyOfflineRegeneration();
    currentEnerji = max(0, currentEnerji - max(0, attackCost));
    currentTP = max(0, currentTP - max(0, attackerDamage));
    cash = max(0, cash - max(0, cashPenalty));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (currentTP <= 0) {
      hospitalUntilEpoch = max(
        hospitalUntilEpoch,
        now + _GameStateBase._hospitalPenaltyDurationSec,
      );
    }
    if (defenderOfflineLogs.isNotEmpty) {
      offlineLogs.insertAll(0, defenderOfflineLogs.reversed);
      if (offlineLogs.length > 30) {
        offlineLogs.removeRange(30, offlineLogs.length);
      }
    }
    _syncLegacyEnergyFields();
    _applyItemWear(
      reason: 'solo_attack_loss',
      wearBySlot: _GameStateBase._attackWearBySlot,
    );
    _trackDaily('raid_joined', 1);
    _queueEvent('solo_attack_loss', {
      'hospitalSec': _GameStateBase._hospitalPenaltyDurationSec,
      'damage': max(0, attackerDamage),
      'energy': max(0, attackCost),
      'cashPenalty': max(0, cashPenalty),
    });
    _addNews(tt('Sokak Bozgunu', 'Street Defeat'), report);
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }

  Future<void> applyGangAttackWin({
    int attackerDamage = 12,
    int attackCost = 20,
    List<String> defenderOfflineLogs = const [],
    int respectGained = 100,
    int xpGained = 24,
    required String report,
  }) async {
    _applyOfflineRegeneration();
    currentEnerji = max(0, currentEnerji - max(0, attackCost));
    currentTP = max(0, currentTP - max(0, attackerDamage));
    if (currentTP <= 0) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      hospitalUntilEpoch = max(
        hospitalUntilEpoch,
        now + _GameStateBase._hospitalPenaltyDurationSec,
      );
    }
    if (defenderOfflineLogs.isNotEmpty) {
      offlineLogs.insertAll(0, defenderOfflineLogs.reversed);
      if (offlineLogs.length > 30) {
        offlineLogs.removeRange(30, offlineLogs.length);
      }
    }
    _syncLegacyEnergyFields();
    _applyItemWear(
      reason: 'gang_attack_win',
      wearBySlot: _GameStateBase._attackWearBySlot,
    );
    _trackDaily('raid_joined', 1);
    _grantXp(max(0, xpGained));
    gangRespectPoints += max(0, respectGained);
    _recomputeGangRank();
    wins += 1;
    gangWins += 1;
    trackAchievement('battles_won', 1);
    trackAchievement('gang_raids_joined', 1);
    _queueEvent('gang_attack_win', {
      'respect': max(0, respectGained),
      'damage': max(0, attackerDamage),
      'energy': max(0, attackCost),
      'xp': max(0, xpGained),
    });
    _addNews(tt('Çete Zaferi', 'Gang Victory'), report);
    await _save();
    _syncOnlineSoon();
    checkAchievements();
    notifyListeners();
  }

  Future<void> applyGangAttackLoss({
    int attackerDamage = 45,
    int attackCost = 20,
    List<String> defenderOfflineLogs = const [],
    required String report,
  }) async {
    _applyOfflineRegeneration();
    currentEnerji = max(0, currentEnerji - max(0, attackCost));
    currentTP = max(0, currentTP - max(0, attackerDamage));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (currentTP <= 0) {
      hospitalUntilEpoch = max(
        hospitalUntilEpoch,
        now + _GameStateBase._hospitalPenaltyDurationSec,
      );
    }
    if (defenderOfflineLogs.isNotEmpty) {
      offlineLogs.insertAll(0, defenderOfflineLogs.reversed);
      if (offlineLogs.length > 30) {
        offlineLogs.removeRange(30, offlineLogs.length);
      }
    }
    _syncLegacyEnergyFields();
    _applyItemWear(
      reason: 'gang_attack_loss',
      wearBySlot: _GameStateBase._attackWearBySlot,
    );
    _trackDaily('raid_joined', 1);
    _queueEvent('gang_attack_loss', {
      'hospitalSec': _GameStateBase._hospitalPenaltyDurationSec,
      'damage': max(0, attackerDamage),
      'energy': max(0, attackCost),
    });
    _addNews(tt('Çete Bozgunu', 'Gang Defeat'), report);
    await _save();
    _syncOnlineSoon();
    notifyListeners();
  }
}
